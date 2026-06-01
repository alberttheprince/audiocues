Config = {}

-- General settings
Config.CheckInterval = 150 -- ms between checks (lower = more responsive, higher = better performance)
Config.MaxNotifications = 6 -- Maximum notifications shown at once (single-line = more fit)
Config.NotificationDuration = 5000 -- How long notifications stay on screen (ms)
Config.CommandName = 'audiocues' -- Command to toggle the system
Config.ShowOwnGunfire = false -- Set to true to show notifications for your own gunfire (useful for testing)
Config.ShowTimestamp = false -- If true show timestamp on notifications

-- ACE Permissions
Config.UseAcePermissions = true -- Set to true to require ACE permission to use
Config.AcePermission = 'audiocues.use' -- ACE permission required
-- To grant permission: add_ace identifier.license:xxxx audiocues.use allow
-- Or for a principal: add_ace group.deaf audiocues.use allow

-- Weapon group hashes for specific gunfire messages
-- Hash values from https://docs.fivem.net/natives/?_0xC3287EE3050FB74C
Config.WeaponGroups = {
    [416676503] = 'pistol',      -- GROUP_PISTOL
    [3337201093] = 'smg',        -- GROUP_SMG
    [970310034] = 'rifle',       -- GROUP_RIFLE
    [1159398588] = 'machinegun', -- GROUP_MG
    [860033945] = 'shotgun',     -- GROUP_SHOTGUN
    [3082541095] = 'sniper',     -- GROUP_SNIPER
    [2725924767] = 'heavy',      -- GROUP_HEAVY
}

-- Distance thresholds for intensity descriptions
Config.DistanceThresholds = {
    close = 100,   -- 0-100m = "extremely loud / very close"
    medium = 200,  -- 100-200m = "normal"
    far = 300,     -- 200-300m = "faint / in the distance"
}

--[[
    Event Configuration
    
    Each event has:
    - maxDistance: Maximum distance this event can be "heard"
    - icon: Emoji/icon for the notification
    - messages: Table of messages for each distance range
        - close: 0 to Config.DistanceThresholds.close
        - medium: close to Config.DistanceThresholds.medium  
        - far: medium to maxDistance
    - cooldown: (optional) Minimum ms between notifications of this type per entity
    - priority: 1 = low (can be pushed out), 2 = medium, 3 = high (won't be pushed out by lower)
    - override: (optional) If true, clears all current notifications when triggered
    - severity: 'danger' (red), 'caution' (yellow), 'neutral' (black) - visual styling
]]

Config.Events = {
    -- ============================================
    -- VEHICLE EVENTS
    -- ============================================
    
    engineStart = {
        maxDistance = 30,
        icon = '🚗',
        cooldown = 2000,
        priority = 1,
        severity = 'neutral',
        messages = {
            close = 'Vehicle engine starts nearby',
            medium = 'Engine starting nearby',
            far = 'Engine starts in the distance',
        }
    },
    
    engineStop = {
        maxDistance = 20,
        icon = '🚗',
        cooldown = 2000,
        priority = 1,
        severity = 'neutral',
        messages = {
            close = 'Vehicle engine shuts off nearby',
            medium = 'Engine shuts off nearby',
            far = 'Engine shuts off in the distance',
        }
    },
    
    siren = {
        maxDistance = 300,
        icon = '🚨',
        cooldown = 3000,
        priority = 3,
        severity = 'danger',
        messages = {
            close = 'LOUD emergency sirens next to you',
            medium = 'Emergency sirens nearby',
            far = 'Faint sirens in the distance',
        }
    },
    
    horn = {
        maxDistance = 150,
        icon = '📯',
        cooldown = 5000,
        priority = 2,
        severity = 'neutral',
        messages = {
            close = 'Horn blares loudly next to you',
            medium = 'Vehicle horn nearby',
            far = 'Faint horn in the distance',
        }
    },
    
    vehicleImpact = {
        maxDistance = 100,
        icon = '💥',
        cooldown = 1000,
        priority = 3,
        severity = 'caution',
        messages = {
            close = 'LOUD vehicle impact next to you',
            medium = 'Vehicle impact nearby',
            far = 'Distant vehicle impact',
        }
    },
    
    fenderBender = {
        maxDistance = 40,
        icon = '🚗',
        cooldown = 2000,
        priority = 1,
        severity = 'caution',
        messages = {
            close = 'Vehicles bump into each other nearby',
            medium = 'Minor vehicle collision nearby',
            far = 'Faint sound of vehicles colliding',
        }
    },
    
    pedHit = {
        maxDistance = 75,
        icon = '🚶',
        cooldown = 1000,
        priority = 3,
        severity = 'danger',
        messages = {
            close = 'Someone gets hit by a vehicle nearby',
            medium = 'Vehicle hits someone nearby',
            far = 'Distant sound of impact',
        }
    },
    
    vehicleAlarm = {
        maxDistance = 100,
        icon = '🚨',
        cooldown = 5000,
        priority = 2,
        severity = 'caution',
        messages = {
            close = 'Car alarm blares next to you',
            medium = 'Car alarm going off',
            far = 'Faint car alarm in the distance',
        }
    },
    
    burnout = {
        maxDistance = 75,
        icon = '🛞',
        cooldown = 2000,
        priority = 1,
        severity = 'neutral',
        messages = {
            close = 'Tires screech next to you',
            medium = 'Tires screeching',
            far = 'Faint tire screeching',
        }
    },
    
    windowBreak = {
        maxDistance = 50,
        icon = '🪟',
        cooldown = 500,
        priority = 2,
        severity = 'caution',
        messages = {
            close = 'Glass shatters next to you',
            medium = 'Glass breaking nearby',
            far = 'Faint sound of glass breaking',
        }
    },
    
    tirePop = {
        maxDistance = 75,
        icon = '💨',
        cooldown = 500,
        priority = 2,
        severity = 'caution',
        messages = {
            close = 'Tire blows out next to you',
            medium = 'Tire pops nearby',
            far = 'Faint tire pop in the distance',
        }
    },
    
    helicopter = {
        maxDistance = 300,
        icon = '🚁',
        cooldown = 5000,
        priority = 2,
        severity = 'neutral',
        messages = {
            close = 'Helicopter roars overhead',
            medium = 'Helicopter nearby',
            far = 'Helicopter in the distance',
        }
    },
    
    plane = {
        maxDistance = 300,
        icon = '✈️',
        cooldown = 5000,
        priority = 2,
        severity = 'neutral',
        messages = {
            close = 'Plane roars overhead',
            medium = 'Plane nearby',
            far = 'Plane in the distance',
        }
    },
    
    boat = {
        maxDistance = 150,
        icon = '🚤',
        cooldown = 5000,
        priority = 1,
        severity = 'neutral',
        messages = {
            close = 'Boat engine roars nearby',
            medium = 'Boat engine nearby',
            far = 'Faint boat engine in the distance',
        }
    },
    
    doorOpen = {
        maxDistance = 15,
        icon = '🚪',
        cooldown = 1000,
        priority = 1,
        severity = 'neutral',
        messages = {
            close = 'Vehicle door opens nearby',
            medium = 'Vehicle door opens nearby',
            far = 'Vehicle door opens',
        }
    },
    
    doorClose = {
        maxDistance = 20,
        icon = '🚪',
        cooldown = 1000,
        priority = 1,
        severity = 'neutral',
        messages = {
            close = 'Vehicle door slams shut nearby',
            medium = 'Vehicle door closes nearby',
            far = 'Vehicle door closes',
        }
    },
    
    vehicleLock = {
        maxDistance = 30,
        icon = '🔒',
        cooldown = 1000,
        priority = 1,
        severity = 'neutral',
        messages = {
            close = 'Vehicle locks with a beep nearby',
            medium = 'Vehicle locks nearby',
            far = 'Vehicle locks in the distance',
        }
    },
    
    vehicleUnlock = {
        maxDistance = 30,
        icon = '🔓',
        cooldown = 1000,
        priority = 1,
        severity = 'neutral',
        messages = {
            close = 'Vehicle unlocks with a beep nearby',
            medium = 'Vehicle unlocks nearby',
            far = 'Vehicle unlocks in the distance',
        }
    },
    
    -- ============================================
    -- COMBAT EVENTS
    -- ============================================
    
    gunfire = {
        maxDistance = 300,
        icon = '🔫',
        cooldown = 150,
        priority = 3,
        severity = 'danger',
        messages = {
            close = 'GUNFIRE! Shots right next to you',
            medium = 'Gunfire nearby',
            far = 'Faint gunshots in the distance',
        }
    },
    
    gunfire_pistol = {
        maxDistance = 200,
        icon = '🔫',
        cooldown = 150,
        priority = 3,
        severity = 'danger',
        messages = {
            close = 'PISTOL SHOTS! Right next to you',
            medium = 'Pistol fire nearby',
            far = 'Faint pistol shots in the distance',
        }
    },
    
    gunfire_smg = {
        maxDistance = 250,
        icon = '🔫',
        cooldown = 150,
        priority = 3,
        severity = 'danger',
        messages = {
            close = 'SMG FIRE! Rapid shots next to you',
            medium = 'SMG fire nearby',
            far = 'Faint rapid gunfire in the distance',
        }
    },
    
    gunfire_rifle = {
        maxDistance = 350,
        icon = '🔫',
        cooldown = 150,
        priority = 3,
        severity = 'danger',
        messages = {
            close = 'RIFLE FIRE! Loud shots next to you',
            medium = 'Rifle fire nearby',
            far = 'Faint rifle shots in the distance',
        }
    },
    
    gunfire_shotgun = {
        maxDistance = 200,
        icon = '🔫',
        cooldown = 150,
        priority = 3,
        severity = 'danger',
        messages = {
            close = 'SHOTGUN BLAST! Right next to you',
            medium = 'Shotgun fire nearby',
            far = 'Faint shotgun blast in the distance',
        }
    },
    
    gunfire_sniper = {
        maxDistance = 400,
        icon = '🎯',
        cooldown = 150,
        priority = 3,
        severity = 'danger',
        messages = {
            close = 'SNIPER SHOT! Loud crack next to you',
            medium = 'Sniper fire nearby',
            far = 'Distant sniper shot',
        }
    },
    
    gunfire_machinegun = {
        maxDistance = 350,
        icon = '🔫',
        cooldown = 150,
        priority = 3,
        severity = 'danger',
        messages = {
            close = 'MACHINE GUN! Heavy fire next to you',
            medium = 'Machine gun fire nearby',
            far = 'Faint heavy gunfire in the distance',
        }
    },
    
    gunfire_heavy = {
        maxDistance = 400,
        icon = '💥',
        cooldown = 150,
        priority = 3,
        severity = 'danger',
        messages = {
            close = 'HEAVY WEAPON! Massive blast next to you',
            medium = 'Heavy weapon fire nearby',
            far = 'Distant heavy weapon fire',
        }
    },
    
    explosion = {
        maxDistance = 300,
        icon = '💣',
        cooldown = 1000,
        priority = 3,
        severity = 'danger',
        override = true, -- Clears other notifications
        messages = {
            close = 'EXPLOSION! Massive blast rocks you',
            medium = 'Explosion nearby',
            far = 'Distant explosion',
        }
    },
    
    melee = {
        maxDistance = 25,
        icon = '👊',
        cooldown = 1000,
        priority = 2,
        severity = 'danger',
        messages = {
            close = 'Fighting right next to you',
            medium = 'Fight nearby',
            far = 'Sounds of a scuffle',
        }
    },
    
    beingShot = {
        maxDistance = 0, -- Only for player
        icon = '🎯',
        cooldown = 500,
        priority = 3,
        severity = 'danger',
        override = false,
        messages = {
            close = 'YOU ARE BEING SHOT!',
            medium = 'YOU ARE BEING SHOT!',
            far = 'YOU ARE BEING SHOT!',
        }
    },
    
    bulletNearby = {
        maxDistance = 10, -- Bullet impacts within 10m
        icon = '💨',
        cooldown = 300,
        priority = 3,
        severity = 'danger',
        messages = {
            close = 'Bullets whizzing past you!',
            medium = 'Bullets impacting nearby',
            far = 'Gunfire impacts nearby',
        }
    },
    
    reloading = {
        maxDistance = 20,
        icon = '🔄',
        cooldown = 1000,
        priority = 2,
        severity = 'caution',
        messages = {
            close = 'Someone reloading right next to you',
            medium = 'Someone reloading nearby',
            far = 'Reloading sounds nearby',
        }
    },
    
    -- ============================================
    -- PED STATE EVENTS
    -- ============================================
    
    personWalking = {
        maxDistance = 10, -- Very short range - footsteps are quiet
        icon = '🚶',
        cooldown = 5000,
        priority = 1,
        severity = 'neutral',
        messages = {
            close = 'Footsteps walking nearby',
            medium = 'Someone walking nearby',
            far = 'Faint footsteps',
        }
    },
    
    personRunning = {
        maxDistance = 30,
        icon = '🏃',
        cooldown = 3000,
        priority = 1,
        severity = 'neutral',
        messages = {
            close = 'Someone running past you',
            medium = 'Footsteps running nearby',
            far = 'Distant running footsteps',
        }
    },
    
    personSprinting = {
        maxDistance = 40,
        icon = '🏃',
        cooldown = 2000,
        priority = 1,
        severity = 'neutral',
        messages = {
            close = 'Someone sprinting past you',
            medium = 'Heavy footsteps sprinting',
            far = 'Distant sprinting',
        }
    },
    
    personInjured = {
        maxDistance = 30,
        icon = '🤕',
        cooldown = 5000,
        priority = 2,
        severity = 'caution',
        messages = {
            close = 'Someone cries out in pain nearby',
            medium = 'Someone in pain nearby',
            far = 'Faint cries of pain',
        }
    },
    
    personDying = {
        maxDistance = 40,
        icon = '💀',
        cooldown = 5000,
        priority = 2,
        severity = 'caution',
        messages = {
            close = 'Someone collapses nearby',
            medium = 'Someone collapses nearby',
            far = 'Something falls in the distance',
        }
    },
    
    personOnFire = {
        maxDistance = 50,
        icon = '🔥',
        cooldown = 3000,
        priority = 3,
        severity = 'danger',
        messages = {
            close = 'Someone on fire, screaming nearby',
            medium = 'Screaming and crackling fire',
            far = 'Distant screaming',
        }
    },
    
    personFalling = {
        maxDistance = 50,
        icon = '⬇️',
        cooldown = 2000,
        priority = 2,
        severity = 'caution',
        messages = {
            close = 'Someone hits the ground hard nearby',
            medium = 'Someone falls nearby',
            far = 'Distant thud',
        }
    },
    
    personSwimming = {
        maxDistance = 30,
        icon = '🏊',
        cooldown = 5000,
        priority = 1,
        severity = 'neutral',
        messages = {
            close = 'Someone swimming nearby',
            medium = 'Splashing water',
            far = 'Faint splashing',
        }
    },
    
    personDrowning = {
        maxDistance = 40,
        icon = '🌊',
        cooldown = 3000,
        priority = 2,
        severity = 'caution',
        messages = {
            close = 'Someone struggling underwater nearby',
            medium = 'Splashing and gasping nearby',
            far = 'Distant splashing',
        }
    },
    
    npcAlert = {
        maxDistance = 30,
        icon = '⚠️',
        cooldown = 3000,
        priority = 2,
        severity = 'caution',
        messages = {
            close = 'Someone reacts in alarm nearby',
            medium = 'Alarmed reaction nearby',
            far = 'Distant commotion',
        }
    },
    
    npcTalking = {
        maxDistance = 15,
        icon = '💬',
        cooldown = 5000, -- Long cooldown to prevent spam
        priority = 1,
        severity = 'neutral',
        messages = {
            close = 'Someone talking nearby',
            medium = 'Conversation nearby',
            far = 'Faint voices',
        }
    },
    
    animalNearby = {
        maxDistance = 20,
        icon = '🐾',
        cooldown = 5000,
        priority = 1,
        severity = 'neutral',
        messages = {
            close = 'Animal sounds nearby',
            medium = 'Wildlife sounds nearby',
            far = 'Faint animal sounds',
        }
    },
    
    -- ============================================
    -- ENVIRONMENT EVENTS
    -- ============================================
    
    thunder = {
        maxDistance = 500,
        icon = '⛈️',
        cooldown = 10000,
        priority = 2,
        severity = 'caution',
        messages = {
            close = 'THUNDER! Deafening crack overhead',
            medium = 'Thunder rumbles across the sky',
            far = 'Distant thunder',
        }
    },
}

-- Weather types that trigger thunder notifications
Config.ThunderWeatherTypes = {
    ['THUNDER'] = true,
    ['RAIN'] = true, -- Sometimes has thunder
    ['CLEARING'] = true, -- Can have residual thunder
}
