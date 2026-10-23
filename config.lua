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
    logStaffPanel = true,
    logPhoneMail = true,
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
    The prop the player holds while the UI is open. Independent of
    Config.ViewType below -- set this to false if you want empty hands.
]]
Config.UseTablet = true
Config.TabletModel = 'prop_cs_tablet'
Config.TabletDict = 'amb@world_human_seat_wall_tablet@female@base'
Config.TabletAnim = 'base'

--[[
    View Type

    Options:
      'tablet'     - Full tablet UI: device frame, bezels, buttons and shadow
      'simplified' - Condensed panel: the application form and the close notice
                     only, with no tablet frame and none of its spacing

    Applies to both the application NPCs and the /apps staff panel.
]]
Config.ViewType = 'tablet'

--[[
    Simplified View Size

    Only used when Config.ViewType is 'simplified'. Values are in pixels and
    are capped to the player's screen, so a large number here just means
    'as big as it fits'.
]]
Config.SimplifiedSize = {
    width = 620,
    height = 720
}

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
    Staff Panel (/apps)

    An in-game review panel for your Guildbase staff: list applications,
    read the answers, claim, approve, reject, move stages, advance, push back
    for revisions, overturn a decision, run AI detection and delete.

    Every action is carried out as the staff member who ran the command and is
    limited to what their Guildbase guild role allows -- someone who cannot
    reject on the website cannot reject here either. Staff who have access to
    more than one guild are asked which one they want first.

    API keys for this live in server/config.lua (ServerConfig.StaffKeys) and
    each one needs the 'staff:review' scope ticked in Guild Settings.
]]
Config.StaffPanel = {
    enabled = true,
    command = 'apps',
    suggestion = 'Review Guildbase applications',
    perPage = 15,

    -- Seconds a player must wait between requests. Stops a held-down key
    -- turning into a burst of API calls.
    cooldown = 1
}

--[[
    In-Game Phone

    Delivers application notifications to the player's in-game phone: a
    confirmation when they submit, and the workflow stage's email -- the
    wording the guild wrote in Guildbase -- when a staff member makes a
    decision on it.

    system:
      'auto'     - use LB Phone if the resource is running, otherwise nothing
      'lb-phone' - always use LB Phone
      'none'     - never deliver phone mail

    The player needs a phone with a mail account set up; anyone without one is
    skipped and their mail waits (Guildbase holds it for 24 hours).

    pollInterval is how often, in seconds, the server asks Guildbase whether
    there is anything for the players currently online. Nothing is requested
    at all while nobody online has a phone.
]]
Config.Phone = {
    enabled = true,
    system = 'auto',
    pollInterval = 30,

    -- Who the mail appears to be from. Leave nil to use the guild's name.
    sender = nil
}

--[[
    My Applications (/myapps)

    Lets a player check the applications they have submitted to your guild and
    withdraw one that has not been decided yet -- the same rule as the website:
    only while it is still submitted or in review.
]]
Config.MyApplications = {
    enabled = true,
    command = 'myapps',
    suggestion = 'View or withdraw your applications'
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
    session_error = 'Failed to load application. Please try again.',

    staff_loading = 'Opening staff panel...',
    staff_disabled = 'The staff panel is disabled on this server.',
    staff_not_configured = 'No Guildbase API keys are configured for the staff panel.',
    staff_no_access = 'You do not have access to any Guildbase guild.',
    staff_error = 'Could not reach Guildbase. Please try again.',
    staff_cooldown = 'Slow down a moment.',

    mine_loading = 'Loading your applications...',
    mine_none = 'You have not submitted any applications.',
    mine_disabled = 'This is disabled on this server.',
    mine_error = 'Could not reach Guildbase. Please try again.'
}
