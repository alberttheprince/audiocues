-- Server-side permission checking for audiocues

-- Callback for client to check if they have permission
RegisterNetEvent('audiocues:checkPermission', function()
    local src = source
    
    if not Config.UseAcePermissions then
        -- ACE permissions disabled, everyone has access
        TriggerClientEvent('audiocues:permissionResult', src, true)
        return
    end
    
    local allowed = IsPlayerAceAllowed(src, Config.AcePermission)
    TriggerClientEvent('audiocues:permissionResult', src, allowed)
end)

-- Export for other resources to check permission
exports('HasPlayerPermission', function(playerId)
    if not Config.UseAcePermissions then
        return true
    end
    return IsPlayerAceAllowed(playerId, Config.AcePermission)
end)
