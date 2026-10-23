-- Debug logging helper
local function DebugLog(category, message, ...)
    if not Config.Debug or not Config.Debug.enabled then return end

    local categoryEnabled = {
        api_request = Config.Debug.logAPIRequests,
        api_response = Config.Debug.logAPIResponses,
        session = Config.Debug.logSessionCreation,
        discord = Config.Debug.logSessionCreation,
        staff = Config.Debug.logStaffPanel
    }

    if categoryEnabled[category] == false then return end

    local prefix = '^3[Guildbase:Server]^7'
    local categoryTag = '^5[' .. category:upper() .. ']^7'

    if select('#', ...) > 0 then
        print(string.format('%s %s %s', prefix, categoryTag, string.format(message, ...)))
    else
        print(string.format('%s %s %s', prefix, categoryTag, message))
    end
end

-- Redact sensitive data for logging
local function RedactString(str, showChars)
    if not Config.Debug or not Config.Debug.redactSensitiveData then return str end
    if not str or #str < 8 then return '***REDACTED***' end

    showChars = showChars or 4
    local prefix = string.sub(str, 1, showChars)
    local suffix = string.sub(str, -showChars)
    return prefix .. '...' .. string.rep('*', 8) .. '...' .. suffix
end

-- Get player Discord ID
local function GetPlayerDiscordId(source)
    DebugLog('discord', 'Retrieving Discord ID for player %s', GetPlayerName(source))

    if Config.DiscordSource == 'fivem' then
        for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
            if string.match(identifier, 'discord:') then
                local discordId = string.gsub(identifier, 'discord:', '')
                DebugLog('discord', 'Found Discord ID: %s', RedactString(discordId, 6))
                return discordId
            end
        end
        return nil
    end

    if Config.DiscordSource == 'esx' then
        if GetResourceState('es_extended') ~= 'started' then
            return nil
        end

        local ESX = exports['es_extended']:getSharedObject()
        local xPlayer = ESX.GetPlayerFromId(source)

        if xPlayer then
            local discordId = xPlayer.get('discord')
            if discordId then
                return discordId
            end
        end

        for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
            if string.match(identifier, 'discord:') then
                return string.gsub(identifier, 'discord:', '')
            end
        end

        return nil
    end

    if Config.DiscordSource == 'qbcore' then
        if GetResourceState('qb-core') ~= 'started' then
            return nil
        end

        local QBCore = exports['qb-core']:GetCoreObject()
        local Player = QBCore.Functions.GetPlayer(source)

        if Player then
            local metadata = Player.PlayerData.metadata
            if metadata and metadata.discord then
                return metadata.discord
            end
        end

        for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
            if string.match(identifier, 'discord:') then
                return string.gsub(identifier, 'discord:', '')
            end
        end

        return nil
    end

    if Config.DiscordSource == 'custom' then
        local resourceName = Config.CustomDiscordExport.resource
        local exportName = Config.CustomDiscordExport.export

        if GetResourceState(resourceName) ~= 'started' then
            return nil
        end

        local success, result = pcall(function()
            return exports[resourceName][exportName](source)
        end)

        if success and result then
            return result
        end

        return nil
    end

    return nil
end

-- Make HTTP request to Guildbase API
local function CreateGuildbaseSession(apiKey, templateSlug, discordId, callback)
    local url = Config.GuildbaseURL .. '/api/v1/sessions'

    local requestBody = {
        template_slug = templateSlug,
        discord_id = discordId
    }

    DebugLog('api_request', 'POST %s', url)
    DebugLog('api_request', 'Template: %s, Discord: %s', templateSlug, RedactString(discordId, 6))

    PerformHttpRequest(url, function(statusCode, response, headers)
        DebugLog('api_response', 'Status: %s', tostring(statusCode))

        if statusCode == 200 or statusCode == 201 then
            local data = json.decode(response)

            if data and data.success and data.embed_url then
                DebugLog('api_response', 'Session created successfully')
                callback(true, data.embed_url)
            else
                local errorMsg = data and data.message or 'Unknown error'
                DebugLog('api_response', 'API Error: %s', errorMsg)
                callback(false, errorMsg)
            end
        else
            DebugLog('api_response', 'HTTP Error: %s', tostring(statusCode))
            callback(false, 'HTTP Error: ' .. tostring(statusCode))
        end
    end, 'POST', json.encode(requestBody), {
        ['Content-Type'] = 'application/json',
        ['Authorization'] = 'Bearer ' .. apiKey,
        ['Accept'] = 'application/json'
    })
end

-- Handle session request from client
RegisterNetEvent('guildbase:requestSession', function(npcId, templateSlug)
    local source = source
    local playerName = GetPlayerName(source)

    DebugLog('session', 'Session request from %s for NPC: %s', playerName, npcId)

    local discordId = GetPlayerDiscordId(source)

    if not discordId then
        DebugLog('session', 'No Discord ID found for player')
        TriggerClientEvent('guildbase:sessionError', source, Config.Messages.no_discord)
        return
    end

    -- Validate NPC exists in config
    local validNPC = false
    for _, npc in ipairs(Config.NPCs) do
        if npc.id == npcId and npc.templateSlug == templateSlug then
            validNPC = true
            break
        end
    end

    if not validNPC then
        DebugLog('session', 'Invalid NPC request - possible exploit attempt')
        TriggerClientEvent('guildbase:sessionError', source, 'Invalid request')
        return
    end

    -- Get API key from server-only config
    local apiKey = ServerConfig.APIKeys[npcId]

    if not apiKey or apiKey == 'gb_live_YOUR_API_KEY' then
        DebugLog('session', 'No API key configured for NPC: %s', npcId)
        TriggerClientEvent('guildbase:sessionError', source, Config.Messages.session_error)
        return
    end

    CreateGuildbaseSession(apiKey, templateSlug, discordId, function(success, result)
        if success then
            DebugLog('session', 'Session created for %s', playerName)
            TriggerClientEvent('guildbase:sessionCreated', source, result)
        else
            DebugLog('session', 'Session failed for %s: %s', playerName, result)
            TriggerClientEvent('guildbase:sessionError', source, Config.Messages.session_error)
        end
    end)
end)

-- ==================================================================
-- Staff Panel (/apps)
--
-- The client never sees an API key and never says who it is. Each player's
-- Discord id is read from their server identifiers, their accessible guilds
-- are resolved once per /apps, and every later request is matched against
-- that stored session -- so a player cannot ask for a guild they were not
-- offered or act as somebody else by editing a message.
-- ==================================================================

-- [source] = { discordId = '...', guilds = { { key = '...', data = {...} } } }
local staffSessions = {}

-- [source] = GetGameTimer() value at the player's last request
local staffCooldowns = {}

-- Only these actions can be reached from the client, and only with the
-- fields listed. Anything else in the payload is dropped.
local StaffActions = {
    approve  = { path = '/approve',  method = 'POST',   permission = 'review' },
    reject   = { path = '/reject',   method = 'POST',   permission = 'review',   fields = { reason = 'string' } },
    move     = { path = '/move',     method = 'POST',   permission = 'manage',   fields = { stage_id = 'number', notes = 'string' } },
    advance  = { path = '/advance',  method = 'POST',   permission = 'manage' },
    pushback = { path = '/pushback', method = 'POST',   permission = 'review',   fields = { reason = 'string' } },
    overturn = { path = '/overturn', method = 'POST',   permission = 'overturn', fields = { stage_id = 'number', reason = 'string' } },
    claim    = { path = '/claim',    method = 'POST',   permission = 'claim' },
    unclaim  = { path = '/unclaim',  method = 'POST',   permission = 'claim' },
    aicheck  = { path = '/ai-check', method = 'POST',   permission = 'ai_check' },
    delete   = { path = '',          method = 'DELETE', permission = 'delete' }
}

local StaffStatuses = {
    ['pending'] = true, ['submitted'] = true, ['in_review'] = true,
    ['accepted'] = true, ['rejected'] = true, ['withdrawn'] = true
}

local StaffRiskLevels = {
    ['low'] = true, ['medium'] = true, ['high'] = true, ['flagged'] = true
}

local function UrlEncode(value)
    return (string.gsub(tostring(value), '[^%w%-%._~]', function(char)
        return string.format('%%%02X', string.byte(char))
    end))
end

-- Generic Guildbase call. Decoding is tolerant: an HTML error page from a
-- reverse proxy must surface as "something went wrong", not a Lua error.
local function GuildbaseRequest(apiKey, method, path, body, callback)
    local url = Config.GuildbaseURL .. path

    DebugLog('api_request', '%s %s', method, path)

    PerformHttpRequest(url, function(statusCode, response)
        local data = nil

        if response and response ~= '' then
            local ok, decoded = pcall(json.decode, response)
            if ok and type(decoded) == 'table' then
                data = decoded
            end
        end

        DebugLog('api_response', '%s %s -> %s', method, path, tostring(statusCode))

        callback(statusCode, data)
    end, method, body and json.encode(body) or '', {
        ['Content-Type'] = 'application/json',
        ['Authorization'] = 'Bearer ' .. apiKey,
        ['Accept'] = 'application/json'
    })
end

-- The keys to ask about a staff member, in a stable order.
local function GetStaffKeys()
    local keys, seen = {}, {}

    local function add(key)
        if type(key) ~= 'string' or key == '' or key == 'gb_live_YOUR_API_KEY' or seen[key] then
            return
        end

        seen[key] = true
        keys[#keys + 1] = key
    end

    if type(ServerConfig.StaffKeys) == 'table' then
        for _, key in ipairs(ServerConfig.StaffKeys) do
            add(key)
        end
    end

    -- Nothing configured for the panel: fall back to the NPC keys, which are
    -- for the same guilds. The 'staff:review' scope is still required, so a
    -- submission-only key just answers 403 and is skipped.
    if #keys == 0 and type(ServerConfig.APIKeys) == 'table' then
        for _, key in pairs(ServerConfig.APIKeys) do
            add(key)
        end
    end

    return keys
end

local function StaffError(source, message)
    TriggerClientEvent('guildbase:staff:error', source, message)
end

local function OnCooldown(source)
    local wait = ((Config.StaffPanel and Config.StaffPanel.cooldown) or 0) * 1000

    if wait <= 0 then
        return false
    end

    local now = GetGameTimer()
    local last = staffCooldowns[source]

    if last and (now - last) < wait then
        return true
    end

    staffCooldowns[source] = now

    return false
end

-- Resolve the guild the client asked for back to its key, from this player's
-- own session only.
local function StaffGuild(source, guildIndex)
    local session = staffSessions[source]

    if not session or type(guildIndex) ~= 'number' then
        return nil, nil
    end

    local entry = session.guilds[math.floor(guildIndex)]

    if not entry then
        return nil, nil
    end

    return entry, session
end

-- Application ids are UUIDs. Checking the shape here keeps a crafted value
-- out of the request path entirely.
local function ValidApplicationId(applicationId)
    return type(applicationId) == 'string'
        and #applicationId <= 64
        and string.match(applicationId, '^[%w%-]+$') ~= nil
end

local function StaffListQuery(discordId, filters)
    local perPage = (Config.StaffPanel and Config.StaffPanel.perPage) or 15
    local query = {
        'discord_id=' .. UrlEncode(discordId),
        'per_page=' .. UrlEncode(math.max(1, math.min(100, math.floor(perPage))))
    }

    filters = type(filters) == 'table' and filters or {}

    if type(filters.page) == 'number' and filters.page > 1 then
        query[#query + 1] = 'page=' .. UrlEncode(math.floor(filters.page))
    end

    if type(filters.status) == 'string' and StaffStatuses[filters.status] then
        query[#query + 1] = 'status=' .. UrlEncode(filters.status)
    end

    if type(filters.risk_level) == 'string' and StaffRiskLevels[filters.risk_level] then
        query[#query + 1] = 'risk_level=' .. UrlEncode(filters.risk_level)
    end

    if type(filters.template_id) == 'number' then
        query[#query + 1] = 'template_id=' .. UrlEncode(math.floor(filters.template_id))
    end

    if type(filters.claimed) == 'boolean' then
        query[#query + 1] = 'claimed=' .. (filters.claimed and 'true' or 'false')
    end

    if type(filters.search) == 'string' and filters.search ~= '' then
        query[#query + 1] = 'search=' .. UrlEncode(string.sub(filters.search, 1, 100))
    end

    return '?' .. table.concat(query, '&')
end

-- The message Guildbase sent, when it sent one. Its errors name the actual
-- problem ("your role does not grant..."), which is far more use in-game than
-- a generic failure.
local function StaffMessage(data, fallback)
    if type(data) == 'table' and type(data.message) == 'string' and data.message ~= '' then
        return data.message
    end

    if type(data) == 'table' and type(data.data) == 'table' and type(data.data.message) == 'string' then
        return data.data.message
    end

    return fallback
end

-- Open the panel: ask every configured guild who this player is.
RegisterNetEvent('guildbase:staff:open', function()
    local src = source

    if not Config.StaffPanel or not Config.StaffPanel.enabled then
        return StaffError(src, Config.Messages.staff_disabled)
    end

    if OnCooldown(src) then
        return StaffError(src, Config.Messages.staff_cooldown)
    end

    local discordId = GetPlayerDiscordId(src)

    if not discordId then
        DebugLog('staff', 'No Discord ID for %s', GetPlayerName(src))
        return StaffError(src, Config.Messages.no_discord)
    end

    local keys = GetStaffKeys()

    if #keys == 0 then
        DebugLog('staff', 'No staff keys configured')
        return StaffError(src, Config.Messages.staff_not_configured)
    end

    DebugLog('staff', '%s opened the staff panel, checking %d guild(s)', GetPlayerName(src), #keys)

    local pending = #keys
    local found = {}
    local reachable = false

    for _, key in ipairs(keys) do
        GuildbaseRequest(key, 'GET', '/api/v1/staff/resolve?discord_id=' .. UrlEncode(discordId), nil, function(status, data)
            if status == 200 and data and data.success and data.data then
                found[#found + 1] = { key = key, data = data.data }
                reachable = true
            elseif status == 403 or status == 401 then
                -- 'not_staff' is the expected answer for a guild this player
                -- has nothing to do with, so it is not an error.
                reachable = true
                DebugLog('staff', 'Key %s: %s', RedactString(key), StaffMessage(data, 'no access'))
            else
                DebugLog('staff', 'Key %s failed with status %s', RedactString(key), tostring(status))
            end

            pending = pending - 1

            if pending > 0 then
                return
            end

            if #found == 0 then
                staffSessions[src] = nil

                return StaffError(src, reachable and Config.Messages.staff_no_access or Config.Messages.staff_error)
            end

            -- Alphabetical, so the picker does not reshuffle between runs.
            table.sort(found, function(a, b)
                return (a.data.guild.name or '') < (b.data.guild.name or '')
            end)

            staffSessions[src] = { discordId = discordId, guilds = found }

            local payload = {}

            for index, entry in ipairs(found) do
                payload[index] = {
                    index = index,
                    guild = entry.data.guild,
                    staff = entry.data.staff,
                    permissions = entry.data.permissions,
                    counts = entry.data.counts,
                    templates = entry.data.templates
                }
            end

            DebugLog('staff', '%s has access to %d guild(s)', GetPlayerName(src), #payload)

            TriggerClientEvent('guildbase:staff:opened', src, payload)
        end)
    end
end)

-- A page of applications for one guild.
RegisterNetEvent('guildbase:staff:list', function(guildIndex, filters)
    local src = source

    if OnCooldown(src) then
        return StaffError(src, Config.Messages.staff_cooldown)
    end

    local entry, session = StaffGuild(src, guildIndex)

    if not entry then
        return StaffError(src, Config.Messages.staff_error)
    end

    local path = '/api/v1/staff/applications' .. StaffListQuery(session.discordId, filters)

    GuildbaseRequest(entry.key, 'GET', path, nil, function(status, data)
        if status == 200 and data and data.success then
            TriggerClientEvent('guildbase:staff:list', src, {
                guildIndex = guildIndex,
                applications = data.data or {},
                meta = data.meta or {}
            })
        else
            StaffError(src, StaffMessage(data, Config.Messages.staff_error))
        end
    end)
end)

-- One application in full.
RegisterNetEvent('guildbase:staff:view', function(guildIndex, applicationId)
    local src = source

    if OnCooldown(src) then
        return StaffError(src, Config.Messages.staff_cooldown)
    end

    local entry, session = StaffGuild(src, guildIndex)

    if not entry or not ValidApplicationId(applicationId) then
        return StaffError(src, Config.Messages.staff_error)
    end

    local path = '/api/v1/staff/applications/' .. applicationId
        .. '?discord_id=' .. UrlEncode(session.discordId)

    GuildbaseRequest(entry.key, 'GET', path, nil, function(status, data)
        if status == 200 and data and data.success and data.data then
            TriggerClientEvent('guildbase:staff:detail', src, {
                guildIndex = guildIndex,
                detail = data.data
            })
        else
            StaffError(src, StaffMessage(data, Config.Messages.staff_error))
        end
    end)
end)

-- Approve, reject, move, advance, push back, overturn, claim, unclaim,
-- AI check or delete.
RegisterNetEvent('guildbase:staff:action', function(guildIndex, applicationId, action, payload)
    local src = source

    if OnCooldown(src) then
        return StaffError(src, Config.Messages.staff_cooldown)
    end

    local definition = type(action) == 'string' and StaffActions[action] or nil
    local entry, session = StaffGuild(src, guildIndex)

    if not definition or not entry or not ValidApplicationId(applicationId) then
        DebugLog('staff', 'Rejected staff action from %s (%s)', GetPlayerName(src), tostring(action))
        return StaffError(src, Config.Messages.staff_error)
    end

    -- The client is told what it may do, so stop an edited UI here rather
    -- than spending an API call on a guaranteed 403.
    if entry.data.permissions and entry.data.permissions[definition.permission] == false then
        return StaffError(src, 'Your Guildbase role does not allow that.')
    end

    -- Discord id comes from the session, never from the client.
    local body = { discord_id = session.discordId }

    if definition.fields and type(payload) == 'table' then
        for field, expected in pairs(definition.fields) do
            local value = payload[field]

            if expected == 'number' and type(value) == 'number' then
                body[field] = math.floor(value)
            elseif expected == 'string' and type(value) == 'string' and value ~= '' then
                body[field] = string.sub(value, 1, 1000)
            end
        end
    end

    local path = '/api/v1/staff/applications/' .. applicationId .. definition.path

    DebugLog('staff', '%s ran %s on application %s', GetPlayerName(src), action, applicationId)

    GuildbaseRequest(entry.key, definition.method, path, body, function(status, data)
        if status == 200 and data and data.success then
            TriggerClientEvent('guildbase:staff:actionResult', src, {
                guildIndex = guildIndex,
                applicationId = applicationId,
                action = action,
                success = true,
                message = StaffMessage(data.data, 'Done.'),
                warning = type(data.data) == 'table' and data.data.stage_action_warning or nil,
                results = type(data.data) == 'table' and data.data.results or nil,
                interpretation = type(data.data) == 'table' and data.data.interpretation or nil
            })
        else
            TriggerClientEvent('guildbase:staff:actionResult', src, {
                guildIndex = guildIndex,
                applicationId = applicationId,
                action = action,
                success = false,
                message = StaffMessage(data, Config.Messages.staff_error)
            })
        end
    end)
end)

RegisterNetEvent('guildbase:staff:close', function()
    staffSessions[source] = nil
end)

AddEventHandler('playerDropped', function()
    staffSessions[source] = nil
    staffCooldowns[source] = nil
end)

-- Resource start message
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    print('^2[Guildbase]^7 Resource started')
    print('^2[Guildbase]^7 NPCs configured: ' .. #Config.NPCs)

    if Config.StaffPanel and Config.StaffPanel.enabled then
        local keys = GetStaffKeys()

        if #keys > 0 then
            print('^2[Guildbase]^7 Staff panel enabled: /' .. (Config.StaffPanel.command or 'apps')
                .. ' (' .. #keys .. ' key(s))')
        else
            print('^3[Guildbase]^7 Staff panel enabled but no API keys are configured for it')
        end
    end
end)
