local isEnabled = false
local isInitializing = false -- Skip notifications during first scan
local entityStates = {}
local cooldowns = {}
local lastThunderCheck = 0
local calculatedWidth = 340 -- Default, will be calculated on enable
local currentPosition = 'top' -- Current position (top, left, right, bottom)

-- Valid positions
local ValidPositions = {
    ['top'] = true,
    ['left'] = true,
    ['right'] = true,
    ['bottom'] = true,
}

-- KVP keys for storing preferences
local KVP_POSITION_KEY = 'audiocues:position'
local KVP_ENABLED_KEY = 'audiocues:enabled'

-- Load saved position from KVP
local function LoadSavedPosition()
    local saved = GetResourceKvpString(KVP_POSITION_KEY)
    if saved and ValidPositions[saved] then
        currentPosition = saved
    end
end

-- Save position to KVP
local function SavePosition(position)
    SetResourceKvp(KVP_POSITION_KEY, position)
end

-- Load saved enabled state from KVP
local function LoadSavedEnabledState()
    local saved = GetResourceKvpString(KVP_ENABLED_KEY)
    return saved == 'true'
end

-- Save enabled state to KVP
local function SaveEnabledState(enabled)
    SetResourceKvp(KVP_ENABLED_KEY, enabled and 'true' or 'false')
end

-- Permission state (updated by server callback)
local hasPermission = nil -- nil = unknown, true/false = checked
local permissionCallbackId = nil

-- Check if player has permission to use audio cues (local cache)
local function HasPermission()
    if not Config.UseAcePermissions then
        return true
    end
    return hasPermission == true
end

-- Request permission check from server
local function RequestPermissionCheck(callback)
    permissionCallbackId = callback
    TriggerServerEvent('audiocues:checkPermission')
end

-- Handle permission result from server
RegisterNetEvent('audiocues:permissionResult', function(allowed)
    hasPermission = allowed
    print('[audiocues] Permission result from server: ' .. tostring(allowed))

    if permissionCallbackId then
        permissionCallbackId(allowed)
        permissionCallbackId = nil
    end
end)

-- Calculate the width needed for the longest message
local function CalculateNotificationWidth()
    local maxLen = 0
    for eventName, eventConfig in pairs(Config.Events) do
        if eventConfig.messages then
            for _, message in pairs(eventConfig.messages) do
                if #message > maxLen then
                    maxLen = #message
                end
            end
        end
    end

    -- Calculate pixel width:
    -- ~6px per character at 12px font (average for this font)
    -- +22px icon, +8px gap, +24px direction indicator, +24px padding (12px each side)
    local baseWidth = (maxLen * 6) + 22 + 8 + 24 + 24
    if Config.ShowTimestamp then
        baseWidth = baseWidth + 8 + 55 -- gap + timestamp
    end

    -- Round up to nearest 10
    baseWidth = math.ceil(baseWidth / 10) * 10

    return math.max(baseWidth, 200) -- Minimum 200px
end

-- ============================================
-- UTILITY FUNCTIONS (must be defined first)
-- ============================================

local function GetDistanceCategory(distance, maxDistance)
    if distance <= Config.DistanceThresholds.close then
        return 'close'
    elseif distance <= Config.DistanceThresholds.medium then
        return 'medium'
    else
        return 'far'
    end
end

local function GetDirectionInfo(playerCoords, entityCoords)
    local heading = GetEntityHeading(PlayerPedId())
    local dx = entityCoords.x - playerCoords.x
    local dy = entityCoords.y - playerCoords.y

    -- Calculate angle relative to player's heading (0 = in front, 90 = right, 180 = behind, 270 = left)
    local angle = math.deg(math.atan2(dx, dy)) - heading
    angle = (angle + 360) % 360

    -- Get text description
    local text = ''
    if angle >= 337.5 or angle < 22.5 then
        text = 'ahead'
    elseif angle >= 22.5 and angle < 67.5 then
        text = 'ahead-right'
    elseif angle >= 67.5 and angle < 112.5 then
        text = 'to the right'
    elseif angle >= 112.5 and angle < 157.5 then
        text = 'behind-right'
    elseif angle >= 157.5 and angle < 202.5 then
        text = 'behind'
    elseif angle >= 202.5 and angle < 247.5 then
        text = 'behind-left'
    elseif angle >= 247.5 and angle < 292.5 then
        text = 'to the left'
    else
        text = 'ahead-left'
    end

    return {
        angle = angle,
        text = text
    }
end

local function CanTriggerEvent(eventType, entityId)
    local key = eventType .. '_' .. tostring(entityId or 'global')
    local eventConfig = Config.Events[eventType]
    local cooldown = eventConfig and eventConfig.cooldown or 1000

    if cooldowns[key] and (GetGameTimer() - cooldowns[key]) < cooldown then
        return false
    end

    cooldowns[key] = GetGameTimer()
    return true
end

local function HasStateChanged(entityId, stateKey, currentValue)
    local key = tostring(entityId) .. '_' .. stateKey
    local previous = entityStates[key]
    entityStates[key] = currentValue

    -- Return nil if this is the first check (don't trigger on initial state)
    if previous == nil then
        return nil
    end

    return previous ~= currentValue
end

local function SendNotification(eventType, distance, directionInfo)
    -- Skip notifications during initialization (first scan after enabling)
    if isInitializing then return end

    local eventConfig = Config.Events[eventType]
    if not eventConfig then return end

    local distanceCategory = GetDistanceCategory(distance, eventConfig.maxDistance)
    local message = eventConfig.messages[distanceCategory] or eventConfig.messages.medium

    SendNUIMessage({
        type = 'notification',
        icon = eventConfig.icon,
        message = message,
        severity = eventConfig.severity or 'neutral', -- For color styling
        distanceCategory = distanceCategory, -- For arc size
        duration = Config.NotificationDuration,
        priority = eventConfig.priority or 2,
        override = eventConfig.override or false,
        directionAngle = directionInfo and directionInfo.angle or nil,
    })
end

-- Helper to get a unique ID for an entity (uses network ID if available, otherwise entity handle)
local function GetEntityId(entity)
    if NetworkGetEntityIsNetworked(entity) then
        return 'net_' .. NetworkGetNetworkIdFromEntity(entity)
    else
        return 'local_' .. entity
    end
end

-- Helper to get gunfire event type based on weapon group
local function GetGunfireEventType(ped)
    local _, weaponHash = GetCurrentPedWeapon(ped, true)
    if weaponHash == 0 then return 'gunfire' end

    local weaponGroup = GetWeapontypeGroup(weaponHash)
    local groupName = Config.WeaponGroups[weaponGroup]

    if groupName then
        local eventName = 'gunfire_' .. groupName
        if Config.Events[eventName] then
            return eventName
        end
    end

    return 'gunfire'
end

-- ============================================
-- GAME EVENT HANDLERS (for instantaneous events)
-- ============================================

-- Ped run over by vehicle detection
AddEventHandler('CEventShockingPedRunOver', function(entities, eventEntity, args)
    if not isEnabled then return end
    if not DoesEntityExist(eventEntity) then return end

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local eventCoords = GetEntityCoords(eventEntity)
    local distance = #(playerCoords - eventCoords)

    if distance <= Config.Events.pedHit.maxDistance then
        local entityId = GetEntityId(eventEntity)
        if CanTriggerEvent('pedHit_event', entityId) then
            local direction = GetDirectionInfo(playerCoords, eventCoords)
            SendNotification('pedHit', distance, direction)
        end
    end
end)

-- Vehicle crash/collision detection - instant
AddEventHandler('CEventShockingCarCrash', function(entities, eventEntity, args)
    if not isEnabled then return end
    if not DoesEntityExist(eventEntity) then return end

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local eventCoords = GetEntityCoords(eventEntity)
    local distance = #(playerCoords - eventCoords)

    if distance <= Config.Events.vehicleImpact.maxDistance then
        local entityId = GetEntityId(eventEntity)
        if CanTriggerEvent('vehicleImpact_event', entityId) then
            local direction = GetDirectionInfo(playerCoords, eventCoords)
            SendNotification('vehicleImpact', distance, direction)
        end
    end
end)

-- Shocking event when someone witnesses a major car crash
AddEventHandler('CEventShockingMadDriverExtreme', function(entities, eventEntity, args)
    if not isEnabled then return end
    if not DoesEntityExist(eventEntity) then return end

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local eventCoords = GetEntityCoords(eventEntity)
    local distance = #(playerCoords - eventCoords)

    if distance <= Config.Events.vehicleImpact.maxDistance then
        local entityId = GetEntityId(eventEntity)
        if CanTriggerEvent('vehicleImpact_mad', entityId) then
            local direction = GetDirectionInfo(playerCoords, eventCoords)
            SendNotification('vehicleImpact', distance, direction)
        end
    end
end)

-- Vehicle damage event
AddEventHandler('CEventVehicleDamageWeapon', function(entities, eventEntity, args)
    if not isEnabled then return end
    if not DoesEntityExist(eventEntity) then return end

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local eventCoords = GetEntityCoords(eventEntity)
    local distance = #(playerCoords - eventCoords)

    if distance <= Config.Events.vehicleImpact.maxDistance then
        local entityId = GetEntityId(eventEntity)
        if CanTriggerEvent('vehicleImpact_weapon', entityId) then
            local direction = GetDirectionInfo(playerCoords, eventCoords)
            SendNotification('vehicleImpact', distance, direction)
        end
    end
end)

-- Explosion events
AddEventHandler('CEventExplosion', function(entities, eventEntity, args)
    if not isEnabled then return end

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local eventCoords

    if DoesEntityExist(eventEntity) then
        eventCoords = GetEntityCoords(eventEntity)
    else
        return
    end

    local distance = #(playerCoords - eventCoords)

    if distance <= Config.Events.explosion.maxDistance then
        if CanTriggerEvent('explosion', GetEntityId(eventEntity)) then
            local direction = GetDirectionInfo(playerCoords, eventCoords)
            SendNotification('explosion', distance, direction)
        end
    end
end)

-- Explosion heard event (catches explosions without entity)
AddEventHandler('CEventExplosionHeard', function(entities, eventEntity, args)
    if not isEnabled then return end

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local eventCoords

    if DoesEntityExist(eventEntity) then
        eventCoords = GetEntityCoords(eventEntity)
    else
        return
    end

    local distance = #(playerCoords - eventCoords)

    if distance <= Config.Events.explosion.maxDistance then
        if CanTriggerEvent('explosion_heard', GetEntityId(eventEntity)) then
            local direction = GetDirectionInfo(playerCoords, eventCoords)
            SendNotification('explosion', distance, direction)
        end
    end
end)

-- Gunfire detection via game event
AddEventHandler('CEventGunShot', function(entities, eventEntity, args)
    if not isEnabled then return end
    if not DoesEntityExist(eventEntity) then return end

    local playerPed = PlayerPedId()

    -- Skip own gunfire unless enabled
    if eventEntity == playerPed and not Config.ShowOwnGunfire then
        return
    end

    local playerCoords = GetEntityCoords(playerPed)
    local eventCoords = GetEntityCoords(eventEntity)
    local distance = #(playerCoords - eventCoords)

    local eventType = GetGunfireEventType(eventEntity)
    local eventConfig = Config.Events[eventType] or Config.Events.gunfire

    if distance <= eventConfig.maxDistance then
        local entityId = GetEntityId(eventEntity)
        if CanTriggerEvent(eventType .. '_gunshot', entityId) then
            local direction = GetDirectionInfo(playerCoords, eventCoords)
            SendNotification(eventType, distance, direction)
        end
    end
end)

-- Melee/fight detection
AddEventHandler('CEventShockingSeenMeleeAction', function(entities, eventEntity, args)
    if not isEnabled then return end
    if not DoesEntityExist(eventEntity) then return end

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local eventCoords = GetEntityCoords(eventEntity)
    local distance = #(playerCoords - eventCoords)

    if distance <= Config.Events.melee.maxDistance then
        local entityId = GetEntityId(eventEntity)
        if CanTriggerEvent('melee', entityId) then
            local direction = GetDirectionInfo(playerCoords, eventCoords)
            SendNotification('melee', distance, direction)
        end
    end
end)

-- ============================================
-- VEHICLE CHECKS (for ongoing state detection)
-- ============================================

local function CheckVehicleEvents(vehicle, distance, direction)
    local vehId = GetEntityId(vehicle)

    -- Engine state
    local isEngineOn = GetIsVehicleEngineRunning(vehicle)
    local engineChanged = HasStateChanged(vehId, 'engine', isEngineOn)

    if engineChanged == true then
        if isEngineOn and distance <= Config.Events.engineStart.maxDistance then
            if CanTriggerEvent('engineStart', vehId) then
                SendNotification('engineStart', distance, direction)
            end
        elseif not isEngineOn and distance <= Config.Events.engineStop.maxDistance then
            if CanTriggerEvent('engineStop', vehId) then
                SendNotification('engineStop', distance, direction)
            end
        end
    end

    -- Siren state (emergency vehicles)
    local isSirenOn = IsVehicleSirenOn(vehicle)
    local sirenChanged = HasStateChanged(vehId, 'siren', isSirenOn)
    if sirenChanged == true and isSirenOn then
        if distance <= Config.Events.siren.maxDistance and CanTriggerEvent('siren', vehId) then
            SendNotification('siren', distance, direction)
        end
    end

    -- Also check if siren is currently active (periodic reminder for ongoing sirens)
    if isSirenOn and distance <= Config.Events.siren.maxDistance then
        if CanTriggerEvent('siren_ongoing', vehId) then
            SendNotification('siren', distance, direction)
        end
    end

    -- Horn (only if pressed)
    if IsHornActive(vehicle) and distance <= Config.Events.horn.maxDistance then
        if CanTriggerEvent('horn', vehId) then
            SendNotification('horn', distance, direction)
        end
    end

    -- Vehicle alarm
    local isAlarmOn = IsVehicleAlarmActivated(vehicle)
    local alarmChanged = HasStateChanged(vehId, 'alarm', isAlarmOn)
    if alarmChanged == true and isAlarmOn then
        if distance <= Config.Events.vehicleAlarm.maxDistance and CanTriggerEvent('vehicleAlarm', vehId) then
            SendNotification('vehicleAlarm', distance, direction)
        end
    end

    -- Burnout detection
    if IsVehicleInBurnout(vehicle) and distance <= Config.Events.burnout.maxDistance then
        if CanTriggerEvent('burnout', vehId) then
            SendNotification('burnout', distance, direction)
        end
    end

    -- Window break detection (check all windows)
    for windowIndex = 0, 7 do
        local windowKey = vehId .. '_window_' .. windowIndex
        local isBroken = not IsVehicleWindowIntact(vehicle, windowIndex)
        local wasBroken = entityStates[windowKey]
        entityStates[windowKey] = isBroken

        if wasBroken ~= nil and isBroken and not wasBroken then
            if distance <= Config.Events.windowBreak.maxDistance and CanTriggerEvent('windowBreak', windowKey) then
                SendNotification('windowBreak', distance, direction)
                break -- Only one notification per check cycle
            end
        end
    end

    -- Tire burst detection
    for wheelIndex = 0, 5 do
        local tireKey = vehId .. '_tire_' .. wheelIndex
        local isBurst = IsVehicleTyreBurst(vehicle, wheelIndex, false)
        local wasBurst = entityStates[tireKey]
        entityStates[tireKey] = isBurst

        if wasBurst ~= nil and isBurst and not wasBurst then
            if distance <= Config.Events.tirePop.maxDistance and CanTriggerEvent('tirePop', tireKey) then
                SendNotification('tirePop', distance, direction)
                break -- Only one notification per check cycle
            end
        end
    end

    -- Aircraft detection (helicopter/plane)
    local vehicleClass = GetVehicleClass(vehicle)
    if vehicleClass == 15 then -- Helicopter
        if distance <= Config.Events.helicopter.maxDistance and CanTriggerEvent('helicopter', vehId) then
            SendNotification('helicopter', distance, direction)
        end
    elseif vehicleClass == 16 then -- Plane
        if distance <= Config.Events.plane.maxDistance and CanTriggerEvent('plane', vehId) then
            SendNotification('plane', distance, direction)
        end
    elseif vehicleClass == 14 then -- Boat
        if isEngineOn and distance <= Config.Events.boat.maxDistance and CanTriggerEvent('boat', vehId) then
            SendNotification('boat', distance, direction)
        end
    end

    -- Door state changes
    for doorIndex = 0, 5 do
        local doorKey = vehId .. '_door_' .. doorIndex
        local doorAngle = GetVehicleDoorAngleRatio(vehicle, doorIndex)
        local isOpen = doorAngle > 0.1
        local wasOpen = entityStates[doorKey]
        entityStates[doorKey] = isOpen

        if wasOpen ~= nil then
            if isOpen and not wasOpen then -- Door opened
                if distance <= Config.Events.doorOpen.maxDistance and CanTriggerEvent('doorOpen', doorKey) then
                    SendNotification('doorOpen', distance, direction)
                    break
                end
            elseif not isOpen and wasOpen then -- Door closed
                if distance <= Config.Events.doorClose.maxDistance and CanTriggerEvent('doorClose', doorKey) then
                    SendNotification('doorClose', distance, direction)
                    break
                end
            end
        end
    end

    -- Lock state changes (vehicles with drivers or recently accessed)
    local lockStatus = GetVehicleDoorLockStatus(vehicle)
    local lockChanged = HasStateChanged(vehId, 'lockstatus', lockStatus)
    if lockChanged == true then
        if lockStatus == 2 then -- Vehicle locked
            if distance <= Config.Events.vehicleLock.maxDistance and CanTriggerEvent('vehicleLock', vehId) then
                SendNotification('vehicleLock', distance, direction)
            end
        elseif lockStatus == 1 then -- Vehicle unlocked
            if distance <= Config.Events.vehicleUnlock.maxDistance and CanTriggerEvent('vehicleUnlock', vehId) then
                SendNotification('vehicleUnlock', distance, direction)
            end
        end
    end
end

-- ============================================
-- PED CHECKS
-- ============================================

local function CheckPedEvents(ped, distance, direction)
    local pedId = GetEntityId(ped)

    -- Check if ped is a player or NPC
    local isPedPlayer = IsPedAPlayer(ped)

    -- Shooting detection (backup - main detection via CEventGunShot)
    if IsPedShooting(ped) then
        local eventType = GetGunfireEventType(ped)
        local eventConfig = Config.Events[eventType] or Config.Events.gunfire
        if distance <= eventConfig.maxDistance and CanTriggerEvent(eventType, pedId) then
            SendNotification(eventType, distance, direction)
        end
    end

    -- Reloading detection
    if IsPedReloading(ped) and distance <= Config.Events.reloading.maxDistance then
        if CanTriggerEvent('reloading', pedId) then
            SendNotification('reloading', distance, direction)
        end
    end

    -- Movement state detection
    local isWalking = IsPedWalking(ped)
    local isRunning = IsPedRunning(ped)
    local isSprinting = IsPedSprinting(ped)

    if isSprinting then
        if distance <= Config.Events.personSprinting.maxDistance and CanTriggerEvent('personSprinting', pedId) then
            SendNotification('personSprinting', distance, direction)
        end
    elseif isRunning then
        if distance <= Config.Events.personRunning.maxDistance and CanTriggerEvent('personRunning', pedId) then
            SendNotification('personRunning', distance, direction)
        end
    elseif isWalking then
        if distance <= Config.Events.personWalking.maxDistance and CanTriggerEvent('personWalking', pedId) then
            SendNotification('personWalking', distance, direction)
        end
    end

    -- Injury/death state
    local isDead = IsPedDeadOrDying(ped, true)
    local health = GetEntityHealth(ped)
    local maxHealth = GetEntityMaxHealth(ped)
    local healthPercent = (health - 100) / (maxHealth - 100) * 100 -- 100 is the base health offset

    local wasInjured = entityStates[pedId .. '_injured'] or false
    local wasDead = entityStates[pedId .. '_dead'] or false

    local isInjured = healthPercent < 50 and not isDead
    entityStates[pedId .. '_injured'] = isInjured
    entityStates[pedId .. '_dead'] = isDead

    if not wasInjured and isInjured then
        if distance <= Config.Events.personInjured.maxDistance and CanTriggerEvent('personInjured', pedId) then
            SendNotification('personInjured', distance, direction)
        end
    end

    if not wasDead and isDead then
        if distance <= Config.Events.personDying.maxDistance and CanTriggerEvent('personDying', pedId) then
            SendNotification('personDying', distance, direction)
        end
    end

    -- On fire
    local isOnFire = IsEntityOnFire(ped)
    local fireChanged = HasStateChanged(pedId, 'onfire', isOnFire)
    if fireChanged == true and isOnFire then
        if distance <= Config.Events.personOnFire.maxDistance and CanTriggerEvent('personOnFire', pedId) then
            SendNotification('personOnFire', distance, direction)
        end
    end

    -- Falling detection (ragdoll or falling)
    local isFalling = IsPedFalling(ped)
    local isRagdoll = IsPedRagdoll(ped)
    local wasFalling = entityStates[pedId .. '_falling'] or false
    entityStates[pedId .. '_falling'] = isFalling or isRagdoll

    if not wasFalling and (isFalling or isRagdoll) then
        if distance <= Config.Events.personFalling.maxDistance and CanTriggerEvent('personFalling', pedId) then
            SendNotification('personFalling', distance, direction)
        end
    end

    -- Swimming detection
    local isSwimming = IsPedSwimming(ped)
    local swimChanged = HasStateChanged(pedId, 'swimming', isSwimming)
    if swimChanged == true and isSwimming then
        if distance <= Config.Events.personSwimming.maxDistance and CanTriggerEvent('personSwimming', pedId) then
            SendNotification('personSwimming', distance, direction)
        end
    end

    -- Drowning detection (underwater)
    local isUnderwater = IsPedSwimmingUnderWater(ped)
    local underwaterChanged = HasStateChanged(pedId, 'underwater', isUnderwater)
    if underwaterChanged == true and isUnderwater then
        if distance <= Config.Events.personDrowning.maxDistance and CanTriggerEvent('personDrowning', pedId) then
            SendNotification('personDrowning', distance, direction)
        end
    end

    -- NPC alertness (reacting to threats)
    local alertness = GetPedAlertness(ped)
    local wasAlert = entityStates[pedId .. '_alertness'] or 0
    entityStates[pedId .. '_alertness'] = alertness

    -- Only trigger when going from calm (0-1) to highly alert (3)
    if alertness == 3 and wasAlert < 2 then
        if distance <= Config.Events.npcAlert.maxDistance and CanTriggerEvent('npcAlert', pedId) then
            SendNotification('npcAlert', distance, direction)
        end
    end

    -- NPC talking/speech detection
    local isSpeaking = IsAmbientSpeechPlaying(ped) or IsAnySpeechPlaying(ped)
    local wasSpeaking = entityStates[pedId .. '_speaking'] or false
    entityStates[pedId .. '_speaking'] = isSpeaking

    -- Only trigger when speech starts, not continuously
    if isSpeaking and not wasSpeaking then
        if distance <= Config.Events.npcTalking.maxDistance and CanTriggerEvent('npcTalking', pedId) then
            SendNotification('npcTalking', distance, direction)
        end
    end
end

-- ============================================
-- ENVIRONMENT CHECKS
-- ============================================

local function CheckEnvironmentEvents()
    -- NOTE: Explosions are handled via CEventExplosion/CEventExplosionHeard for instant detection

    -- Thunder check (less frequent)
    local now = GetGameTimer()
    if now - lastThunderCheck > 5000 then
        lastThunderCheck = now

        local weatherType = GetPrevWeatherTypeHashName()
        local weatherName = nil

        -- Convert hash to name for comparison
        for name, _ in pairs(Config.ThunderWeatherTypes) do
            if GetHashKey(name) == weatherType then
                weatherName = name
                break
            end
        end

        if weatherName and Config.ThunderWeatherTypes[weatherName] then
            -- Random chance for thunder sound during storm
            if math.random(1, 100) <= 10 then -- 10% chance every 5 seconds during storm
                if CanTriggerEvent('thunder', 'weather') then
                    SendNotification('thunder', 0, nil)
                end
            end
        end
    end
end

-- ============================================
-- MAIN LOOP
-- ============================================

local function MainLoop()
    while isEnabled do
        Wait(Config.CheckInterval)

        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)

        -- Check own gunfire if enabled (backup detection)
        if Config.ShowOwnGunfire and IsPedShooting(playerPed) then
            local eventType = GetGunfireEventType(playerPed)
            if CanTriggerEvent(eventType .. '_self', 'player') then
                SendNotification(eventType, 0, nil)
            end
        end

        -- Check if player is being shot/damaged
        if HasEntityBeenDamagedByAnyPed(playerPed) then
            if CanTriggerEvent('playerDamaged', 'player') then
                -- Check if it was weapon damage specifically
                if HasEntityBeenDamagedByWeapon(playerPed, 0, 1) then -- 0 = any weapon, 1 = check all weapon types
                    SendNotification('beingShot', 0, nil)
                end
            end
            ClearEntityLastDamageEntity(playerPed)
        end

        -- Check for bullet impacts near player (shots whizzing by)
        local impactExists, impactCoords = GetPedLastWeaponImpactCoord(playerPed)
        if not impactExists then
            -- Check nearby peds for their weapon impacts near player
            local nearbyPeds = GetGamePool('CPed')
            for _, ped in ipairs(nearbyPeds) do
                if ped ~= playerPed and DoesEntityExist(ped) and IsPedShooting(ped) then
                    local pedImpactExists, pedImpactCoords = GetPedLastWeaponImpactCoord(ped)
                    if pedImpactExists then
                        local impactDist = #(playerCoords - pedImpactCoords)
                        if impactDist < 10 and impactDist > 1 then -- Close but not hit
                            if CanTriggerEvent('bulletNearby', 'impact') then
                                SendNotification('bulletNearby', impactDist, nil)
                            end
                            break
                        end
                    end
                end
            end
        end

        -- Check vehicles
        local vehicles = GetGamePool('CVehicle')
        for _, vehicle in ipairs(vehicles) do
            if DoesEntityExist(vehicle) then
                local vehCoords = GetEntityCoords(vehicle)
                local distance = #(playerCoords - vehCoords)

                -- Only check vehicles within max possible distance
                if distance <= 300 then
                    local direction = GetDirectionInfo(playerCoords, vehCoords)
                    CheckVehicleEvents(vehicle, distance, direction)
                end
            end
        end

        -- Check peds
        local peds = GetGamePool('CPed')
        for _, ped in ipairs(peds) do
            if DoesEntityExist(ped) and ped ~= playerPed then
                local pedCoords = GetEntityCoords(ped)
                local distance = #(playerCoords - pedCoords)

                -- Only check peds within max possible distance
                if distance <= 300 then
                    local direction = GetDirectionInfo(playerCoords, pedCoords)
                    CheckPedEvents(ped, distance, direction)
                end
            end
        end

        -- Check environment
        CheckEnvironmentEvents()

        -- After first scan, disable initialization mode
        if isInitializing then
            isInitializing = false
        end
    end
end

-- ============================================
-- TOGGLE FUNCTION
-- ============================================

local function ToggleAudioCues(position, silent)
    -- Validate position if provided
    local validPosition = nil
    if position and position ~= '' then
        local lowerPos = string.lower(position)
        if ValidPositions[lowerPos] then
            validPosition = lowerPos
        else
            -- Invalid position provided, show help
            if not silent then
                TriggerEvent('chat:addMessage', {
                    color = {255, 100, 100},
                    args = {'AudioCues', 'Invalid position. Use: top, left, right, or bottom'}
                })
            end
            return
        end
    end

    -- If already enabled and a position was provided, just update position (don't toggle)
    if isEnabled and validPosition then
        currentPosition = validPosition
        SavePosition(currentPosition)

        -- Update NUI position
        SendNUIMessage({
            type = 'updatePosition',
            position = currentPosition,
        })
        return
    end

    -- Update position if provided
    if validPosition then
        currentPosition = validPosition
        SavePosition(currentPosition)
    end

    isEnabled = not isEnabled

    -- Save enabled state to KVP
    SaveEnabledState(isEnabled)

    if isEnabled then
        -- Set initializing flag to skip notifications on first scan
        isInitializing = true

        -- Calculate width for longest message
        calculatedWidth = CalculateNotificationWidth()

        -- Show NUI
        SendNUIMessage({
            type = 'toggle',
            enabled = true,
            showTimestamp = Config.ShowTimestamp,
            notificationWidth = calculatedWidth,
            position = currentPosition,
        })

        -- Start main loop
        CreateThread(MainLoop)
    else
        -- Hide NUI
        SendNUIMessage({
            type = 'toggle',
            enabled = false,
        })

        -- Clear states
        entityStates = {}
        cooldowns = {}
        isInitializing = false
    end
end

-- Enable audio cues directly (for auto-restore on reconnect)
local function EnableAudioCues()
    if isEnabled then return end -- Already enabled

    isEnabled = true
    isInitializing = true

    -- Calculate width for longest message
    calculatedWidth = CalculateNotificationWidth()

    -- Show NUI
    SendNUIMessage({
        type = 'toggle',
        enabled = true,
        showTimestamp = Config.ShowTimestamp,
        notificationWidth = calculatedWidth,
        position = currentPosition,
    })

    -- Start main loop
    CreateThread(MainLoop)
end

-- ============================================
-- COMMANDS & EXPORTS
-- ============================================

-- Load saved position on resource start and auto-restore enabled state
CreateThread(function()
    -- Load saved position preference
    LoadSavedPosition()

    -- Check if audio cues were previously enabled
    local wasEnabled = LoadSavedEnabledState()

    if wasEnabled then
        -- Wait for player to be fully spawned and active
        while not NetworkIsPlayerActive(PlayerId()) do
            Wait(500)
        end

        -- Additional wait for network to stabilize
        Wait(3000)

        -- If ACE permissions disabled, just enable directly
        if not Config.UseAcePermissions then
            EnableAudioCues()
            return
        end

        -- Request permission check from server
        RequestPermissionCheck(function(allowed)
            if allowed then
                EnableAudioCues()
            else
                -- Player doesn't have permission on this server, clear the saved state
                SaveEnabledState(false)
            end
        end)
    end
end)

-- Register command with chat suggestions
RegisterCommand(Config.CommandName, function(source, args, rawCommand)
    local position = args[1] or nil

    -- If ACE permissions disabled, just toggle directly
    if not Config.UseAcePermissions then
        ToggleAudioCues(position, false)
        return
    end

    -- If we already know permission status, use cached value
    if hasPermission ~= nil then
        if hasPermission then
            ToggleAudioCues(position, false)
        else
            TriggerEvent('chat:addMessage', {
                color = {255, 100, 100},
                args = {'AudioCues', 'You do not have permission to use this feature.'}
            })
        end
        return
    end

    -- Request permission check from server
    RequestPermissionCheck(function(allowed)
        if allowed then
            ToggleAudioCues(position, false)
        else
            TriggerEvent('chat:addMessage', {
                color = {255, 100, 100},
                args = {'AudioCues', 'You do not have permission to use this feature.'}
            })
        end
    end)
end, false)

-- Add chat suggestions
TriggerEvent('chat:addSuggestion', '/' .. Config.CommandName, 'Toggle audio cues on/off, or change position if already active', {
    { name = 'position', help = 'top, left, right, bottom (changes position if active, otherwise sets starting position)' }
})

-- Export for other resources to send custom notifications
exports('SendAudioCue', function(icon, message, severity)
    if not isEnabled then return end

    SendNUIMessage({
        type = 'notification',
        icon = icon or '🔔',
        message = message,
        severity = severity or 'neutral',
        duration = Config.NotificationDuration,
    })
end)

-- Export to check if audio cue mode is active
exports('IsAudioCueEnabled', function()
    return isEnabled
end)

-- Export to check if player has permission to use audio cues
exports('HasAudioCuePermission', function()
    return HasPermission()
end)

-- Export to get current position
exports('GetAudioCuePosition', function()
    return currentPosition
end)

-- Export to set position (and save to KVP)
exports('SetAudioCuePosition', function(position)
    local lowerPos = string.lower(position or 'top')
    if ValidPositions[lowerPos] then
        currentPosition = lowerPos
        SavePosition(currentPosition)

        -- If enabled, update NUI
        if isEnabled then
            SendNUIMessage({
                type = 'updatePosition',
                position = currentPosition,
            })
        end
        return true
    end
    return false
end)
