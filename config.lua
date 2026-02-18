Config = {}

--[[
    Debug / Logging Configuration
    Set enabled = true to see detailed logs in the server console
]]
Config.Debug = {
    enabled = false,
    logInteractions = true,
    logAPIRequests = true,
    logAPIResponses = true,
    logSessionCreation = true,
    logNPCSpawning = true,
    logTargetSetup = true,
    redactSensitiveData = true
}

--[[
    Guildbase API Configuration
    Set this to your Guildbase instance URL
]]
Config.GuildbaseURL = 'https://guildbase.gg'

--[[
    Discord ID Source
    Options:
      'fivem'  - Uses FiveM's built-in Discord (requires Discord linked to FiveM account)
      'esx'    - Uses ESX identity system
      'qbcore' - Uses QBCore metadata
      'custom' - Uses a custom export (configure below)
]]
Config.DiscordSource = 'fivem'

-- Custom Discord Export (only used if DiscordSource is 'custom')
Config.CustomDiscordExport = {
    resource = 'your_resource',
    export = 'GetPlayerDiscordId'
}

--[[
    Target System
    Options: 'auto', 'ox_target', 'qb-target', 'none'
    'auto' will detect ox_target or qb-target automatically
    'none' uses E key interaction only
]]
Config.TargetSystem = 'auto'

--[[
    Interaction Settings
]]
Config.InteractionKey = 38 -- E key
Config.InteractionDistance = 2.0 -- meters

--[[
    Tablet Animation
]]
Config.UseTablet = true
Config.TabletModel = 'prop_cs_tablet'
Config.TabletDict = 'amb@world_human_seat_wall_tablet@female@base'
Config.TabletAnim = 'base'

--[[
    NPC Configuration

    Each NPC requires:
      id           - Unique identifier (must match key in server/config.lua)
      coords       - { x = ..., y = ..., z = ..., w = ... } (w = heading)
      model        - Ped model name
      templateSlug - Template slug from Guildbase
      label        - Display label for interaction
      icon         - FontAwesome icon (optional)
      blip         - { sprite, color, scale, label, shortRange, display } (optional)

    Note: API keys are configured separately in server/config.lua
]]
Config.NPCs = {
    {
        id = 'applications',  -- Must match key in server/config.lua
        coords = { x = -1037.82, y = -2734.19, z = 12.77, w = 329.85 },
        model = 'a_f_y_business_02',
        templateSlug = 'staff-app',
        label = 'Submit Application',
        icon = 'fas fa-clipboard-list',
        blip = {
            sprite = 280,
            color = 3,
            scale = 0.8,
            label = 'Applications',
            shortRange = true
        }
    }
}


--[[
    Notification System
    Options: 'native', 'ox_lib', 'esx', 'qbcore'
]]
Config.NotifySystem = 'native'

--[[
    Messages
]]
Config.Messages = {
    no_discord = 'You must have Discord linked to your FiveM account.',
    loading = 'Loading application...',
    error = 'An error occurred. Please try again.',
    session_error = 'Failed to load application. Please try again.'
}
