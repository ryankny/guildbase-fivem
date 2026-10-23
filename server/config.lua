--[[
    Server-Only API Key Configuration

    This file contains sensitive API keys and should NEVER be shared or committed to version control.
    Map NPC IDs to their corresponding Guildbase API keys.
]]

ServerConfig = {}

ServerConfig.APIKeys = {
    -- ['npc_id'] = 'gb_live_YOUR_API_KEY',
    ['applications'] = 'gb_live_YOUR_API_KEY'
}

--[[
    Staff Panel Keys (/apps)

    One key per Guildbase guild your staff can review applications for. Each
    key needs the 'staff:review' scope. Leave empty to reuse the keys above.
]]
ServerConfig.StaffKeys = {
    -- 'gb_live_YOUR_API_KEY',
}
