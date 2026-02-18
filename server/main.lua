-- Debug logging helper
local function DebugLog(category, message, ...)
    if not Config.Debug or not Config.Debug.enabled then return end

    local categoryEnabled = {
        api_request = Config.Debug.logAPIRequests,
        api_response = Config.Debug.logAPIResponses,
        session = Config.Debug.logSessionCreation,
        discord = Config.Debug.logSessionCreation
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

-- Resource start message
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    print('^2[Guildbase]^7 Resource started')
    print('^2[Guildbase]^7 NPCs configured: ' .. #Config.NPCs)
end)
