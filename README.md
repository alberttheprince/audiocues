<img width="799" height="279" alt="image" src="https://github.com/user-attachments/assets/60e691f3-449c-489c-9cc8-ee4291d7b6f5" />

Visual notifications for in-game audio events. Designed for accessibility, allowing players to receive visual cues for sounds they may not be able to hear.

Want to support our work? [Come join our RP server](https://discord.gg/popcornroleplay), we're working and releasing resources like this every week to make FiveM a more accessible place!

Video Preview: https://youtu.be/dVPxiUpQQ0I

### Features:

- Event distance and direction and cooldowns
- Notification duration
- Timestamp visibility
- Custom messages for each event type


## How-to-Use:

Players can toggle audio cues with the command:
```
/audiocues [position]
```

### Screen Positions:

Audio cue notifications can be displayed in four different positions on screen:

| Command | Description |
|---------|-------------|
| `/audiocues` | Toggle on/off (uses last saved position, defaults to top) |
| `/audiocues top` | If active: moves to top. If inactive: enables at top |
| `/audiocues left` | If active: moves to left. If inactive: enables at left |
| `/audiocues right` | If active: moves to right. If inactive: enables at right |
| `/audiocues bottom` | If active: moves to bottom. If inactive: enables at bottom |

**Note:** When audio cues are already active, providing a position argument will only change the position without toggling off. Use `/audiocues` without arguments to toggle off.

### Persistence:

Both the **position** and **enabled state** are saved via KVP and persist across sessions:
- If you enable audio cues and disconnect, they will automatically re-enable when you reconnect
- Your preferred position (top/left/right/bottom) is remembered

**Security Note:** If a server uses ACE permissions to restrict audio cues to verified users, the auto-enable feature will check permissions before activating. Players cannot bypass ACE restrictions by enabling audio cues on another server.

## ACE Permissions (Optional)

To restrict the feature to specific players (e.g., verified deaf/hard-of-hearing users):

1. In `config.lua`, set:
```lua
Config.UseAcePermissions = true
```

2. Grant permission to specific players in your `server.cfg`:

**By player identifier:**
```cfg
add_ace identifier.license:xxxxxxxxxxxxxxxxxxxx audiocues.use allow
add_ace identifier.discord:123456789012345678 audiocues.use allow
add_ace identifier.steam:110000xxxxxxxxx audiocues.use allow
```

**By group (recommended):**
```cfg
# Create a group for users who need audio cues
add_principal identifier.license:xxxxxxxxxxxxxxxxxxxx group.audiocues
add_principal identifier.discord:123456789012345678 group.audiocues

# Grant permission to the group
add_ace group.audiocues audiocues.use allow
```

## Exports

Other resources can integrate with AudioCues:

```lua
-- Send a custom notification
exports['audiocues']:SendAudioCue('🔔', 'Custom message', 'neutral') -- severity: 'danger', 'caution', 'neutral'

-- Check if audio cues are currently enabled for the player
local enabled = exports['audiocues']:IsAudioCueEnabled()

-- Check if player has permission to use audio cues
local hasPermission = exports['audiocues']:HasAudioCuePermission()

-- Get current position
local position = exports['audiocues']:GetAudioCuePosition() -- Returns: 'top', 'left', 'right', or 'bottom'

-- Set position programmatically (also saves to KVP)
local success = exports['audiocues']:SetAudioCuePosition('right') -- Returns true if valid position
```
