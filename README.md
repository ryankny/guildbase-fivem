# Guildbase FiveM Integration

A standalone FiveM resource for integrating Guildbase applications directly into your server. Players can interact with NPCs to submit applications through an in-game tablet interface.

## Features

- **NPC Interaction** - Configure NPCs at any location to handle applications
- **Target System Support** - Works with ox_target, qb-target, or classic E-key interaction
- **Tablet Animation** - Players hold a tablet while viewing applications
- **Discord Integration** - Automatically links applications to player Discord accounts
- **Framework Agnostic** - Works standalone or with ESX/QBCore

## Requirements

- FiveM server build 5181+
- Players must have Discord linked to their FiveM account
- Guildbase Pro subscription (required for API key generation)

## Installation

1. Download and extract to your `resources` folder
2. Rename the folder to `guildbase-fivem`
3. Copy `server/config.lua.example` to `server/config.lua`
4. Add your API keys to `server/config.lua`
5. Configure `config.lua` with your NPC settings
6. Add `ensure guildbase-fivem` to your `server.cfg`
7. Restart your server

## Configuration

### API Setup

1. Log into your Guildbase dashboard
2. Navigate to Guild Settings > API Keys
3. Generate a new API key for your application template
4. Add the key to `server/config.lua` (this file is server-only)

```lua
-- server/config.lua
ServerConfig.APIKeys = {
    ['police_applications'] = 'gb_live_YOUR_API_KEY',
    ['ems_applications'] = 'gb_live_YOUR_API_KEY',
}
```

> API keys are available to Pro subscribers from the Guild Settings panel.

### NPC Configuration

The `id` field must match the key in `server/config.lua` where the API key is stored.

```lua
Config.NPCs = {
    {
        id = 'police_applications',  -- Must match key in server/config.lua
        coords = { x = 441.16, y = -982.0, z = 30.69, w = 177.62 },
        model = 's_m_y_cop_01',
        templateSlug = 'police-application',
        label = 'Police Application',
        icon = 'fas fa-shield-alt',
        scenario = 'WORLD_HUMAN_CLIPBOARD'
    }
}
```

### Blip Configuration

Add an optional `blip` table to any NPC to display a map marker:

```lua
{
    id = 'ems_applications',
    coords = { x = 307.23, y = -592.47, z = 43.28, w = 72.5 },
    model = 's_m_m_paramedic_01',
    templateSlug = 'ems-application',
    label = 'EMS Application',
    icon = 'fas fa-ambulance',
    blip = {
        sprite = 61,        -- Blip icon (see FiveM blip sprites)
        color = 1,          -- Blip color (1 = red, 2 = green, 3 = blue, etc.)
        scale = 0.8,        -- Blip size on map
        label = 'EMS Applications',  -- Text shown on map
        shortRange = true   -- Only visible when nearby
    }
}
```

| Property | Type | Description |
|----------|------|-------------|
| `sprite` | number | Blip icon ID ([reference](https://docs.fivem.net/docs/game-references/blips/)) |
| `color` | number | Blip color ID ([reference](https://docs.fivem.net/docs/game-references/blips/#blip-colors)) |
| `scale` | number | Size multiplier (default: 1.0) |
| `label` | string | Map marker text |
| `shortRange` | boolean | If true, only visible when player is nearby |

### Target System

```lua
-- Options: 'auto', 'ox_target', 'qb-target', 'none'
Config.TargetSystem = 'auto'
```

### Discord Source

```lua
-- Options: 'fivem', 'esx', 'qbcore', 'custom'
Config.DiscordSource = 'fivem'
```

## Debug Mode

Enable debug logging in `config.lua`:

```lua
Config.Debug = {
    enabled = true,
    -- ... other options
}
```

## API Flow

1. Player interacts with NPC
2. Server retrieves player's Discord ID
3. Server creates session via Guildbase API
4. Client displays application in tablet UI
5. Player submits application through Guildbase
6. Press ESC or click Close to exit

## Troubleshooting

**"Discord not linked" error**
- Player needs to link Discord at https://fivem.net/

**NPC not spawning**
- Check coordinates in config
- Verify model name is correct
- Enable debug mode for detailed logs

**Application not loading**
- Verify API key is set in `server/config.lua`
- Ensure NPC `id` matches the key in `server/config.lua`
- Check template slug matches Guildbase
- Ensure Guildbase URL is accessible

## License

Proprietary - Free to use, no modification or redistribution. See LICENSE file.

## Support

- [Guildbase](https://guildbase.gg)
- [Support Discord](https://discord.gg/ftecbfMrzt)
- [GitHub Issues](https://github.com/guildbase/guildbase-fivem/issues)
