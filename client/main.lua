local spawnedNPCs = {}
local targetSystem = nil
local isNUIOpen = false
local tabletObject = nil
local currentNPC = nil

-- Debug logging helper
local function DebugLog(category, message, ...)
    if not Config.Debug or not Config.Debug.enabled then return end

    local categoryEnabled = {
        interaction = Config.Debug.logInteractions,
        npc = Config.Debug.logNPCSpawning,
        target = Config.Debug.logTargetSetup,
        session = Config.Debug.logSessionCreation
    }

    if categoryEnabled[category] == false then return end

    local prefix = '^3[Guildbase:Client]^7'
    local categoryTag = '^5[' .. category:upper() .. ']^7'

    if select('#', ...) > 0 then
        print(string.format('%s %s %s', prefix, categoryTag, string.format(message, ...)))
    else
        print(string.format('%s %s %s', prefix, categoryTag, message))
    end
end

-- Detect target system
local function DetectTargetSystem()
    if Config.TargetSystem ~= 'auto' then
        DebugLog('target', 'Using configured target system: %s', Config.TargetSystem)
        return Config.TargetSystem
    end

    if GetResourceState('ox_target') == 'started' then
        DebugLog('target', 'Auto-detected target system: ox_target')
        return 'ox_target'
    elseif GetResourceState('qb-target') == 'started' then
        DebugLog('target', 'Auto-detected target system: qb-target')
        return 'qb-target'
    end

    DebugLog('target', 'No target system detected, using E-key interaction')
    return 'none'
end

-- Notification helper
local function Notify(message, type)
    type = type or 'info'

    if Config.NotifySystem == 'ox_lib' and GetResourceState('ox_lib') == 'started' then
        exports['ox_lib']:notify({
            title = 'Guildbase',
            description = message,
            type = type
        })
    elseif Config.NotifySystem == 'esx' and GetResourceState('es_extended') == 'started' then
        TriggerEvent('esx:showNotification', message)
    elseif Config.NotifySystem == 'qbcore' and GetResourceState('qb-core') == 'started' then
        TriggerEvent('QBCore:Notify', message, type)
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(message)
        EndTextCommandThefeedPostTicker(false, true)
    end
end

-- Create tablet prop and play animation
local function CreateTablet()
    if not Config.UseTablet then return end

    local playerPed = PlayerPedId()

    RequestAnimDict(Config.TabletDict)
    while not HasAnimDictLoaded(Config.TabletDict) do
        Wait(10)
    end

    local modelHash = GetHashKey(Config.TabletModel)
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Wait(10)
    end

    TaskPlayAnim(playerPed, Config.TabletDict, Config.TabletAnim, 8.0, -8.0, -1, 49, 0, false, false, false)

    local boneIndex = GetPedBoneIndex(playerPed, 28422)
    tabletObject = CreateObject(modelHash, 0.0, 0.0, 0.0, true, true, true)
    AttachEntityToEntity(tabletObject, playerPed, boneIndex, 0.0, 0.0, 0.03, 0.0, 0.0, 0.0, true, true, false, true, 1, true)

    SetModelAsNoLongerNeeded(modelHash)
end

-- Remove tablet and stop animation
local function RemoveTablet()
    local playerPed = PlayerPedId()

    if tabletObject and DoesEntityExist(tabletObject) then
        DeleteEntity(tabletObject)
        tabletObject = nil
    end

    StopAnimTask(playerPed, Config.TabletDict, Config.TabletAnim, 1.0)
    ClearPedTasks(playerPed)
    ClearPedTasksImmediately(playerPed)
end

-- Open NUI
local function OpenNUI(embedUrl)
    if isNUIOpen then return end

    isNUIOpen = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)

    CreateTablet()

    SendNUIMessage({
        action = 'open',
        url = embedUrl
    })
end

-- Close NUI
local function CloseNUI()
    isNUIOpen = false

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    RemoveTablet()

    SendNUIMessage({
        action = 'close'
    })

    currentNPC = nil

    CreateThread(function()
        Wait(100)
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        ClearPedTasksImmediately(PlayerPedId())
    end)
end

-- NUI Callbacks
RegisterNUICallback('close', function(_, cb)
    CloseNUI()
    cb('ok')
end)

RegisterNUICallback('closeEsc', function(_, cb)
    CloseNUI()
    cb('ok')
end)

RegisterNUICallback('loaded', function(_, cb)
    cb('ok')
end)

RegisterNUICallback('error', function(_, cb)
    Notify(Config.Messages.error, 'error')
    cb('ok')
end)

-- Interact with NPC
local function InteractWithNPC(npcData)
    if isNUIOpen then return end

    currentNPC = npcData

    DebugLog('interaction', 'NPC Interaction: %s (%s)', npcData.id, npcData.templateSlug)

    Notify(Config.Messages.loading, 'info')

    TriggerServerEvent('guildbase:requestSession', npcData.id, npcData.templateSlug)
end

-- Receive session from server
RegisterNetEvent('guildbase:sessionCreated', function(embedUrl)
    if not currentNPC then return end

    DebugLog('session', 'Session created, opening NUI')
    OpenNUI(embedUrl)
end)

-- Session error
RegisterNetEvent('guildbase:sessionError', function(message)
    DebugLog('session', 'Session error: %s', message or 'Unknown')
    Notify(message or Config.Messages.session_error, 'error')
    currentNPC = nil
end)

-- Spawn NPC
local function SpawnNPC(npcData)
    DebugLog('npc', 'Spawning NPC: %s at %.2f, %.2f, %.2f', npcData.id, npcData.coords.x, npcData.coords.y, npcData.coords.z)

    local modelHash = GetHashKey(npcData.model)

    RequestModel(modelHash)
    local loadStart = GetGameTimer()
    while not HasModelLoaded(modelHash) do
        Wait(10)
        if GetGameTimer() - loadStart > 5000 then
            DebugLog('npc', 'Failed to load model for NPC: %s', npcData.id)
            return nil
        end
    end

    local ped = CreatePed(0, modelHash, npcData.coords.x, npcData.coords.y, npcData.coords.z, npcData.coords.w, false, false)

    SetEntityInvincible(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedDiesWhenInjured(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)
    SetPedAlertness(ped, 0)

    SetModelAsNoLongerNeeded(modelHash)

    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedKeepTask(ped, true)

    return ped
end

-- Setup ox_target
local function SetupOxTarget(npcData, ped)
    exports['ox_target']:addLocalEntity(ped, {
        {
            name = 'guildbase_' .. npcData.id,
            icon = npcData.icon or 'fas fa-clipboard-list',
            label = npcData.label,
            onSelect = function()
                InteractWithNPC(npcData)
            end
        }
    })
end

-- Setup qb-target
local function SetupQBTarget(npcData, ped)
    exports['qb-target']:AddTargetEntity(ped, {
        options = {
            {
                type = 'client',
                icon = npcData.icon or 'fas fa-clipboard-list',
                label = npcData.label,
                action = function()
                    InteractWithNPC(npcData)
                end
            }
        },
        distance = Config.InteractionDistance
    })
end

-- Create blip for NPC
local function CreateNPCBlip(npcData)
    if not npcData.blip then return end

    local blip = AddBlipForCoord(npcData.coords.x, npcData.coords.y, npcData.coords.z)
    SetBlipSprite(blip, npcData.blip.sprite or 1)
    SetBlipColour(blip, npcData.blip.color or 1)
    SetBlipScale(blip, npcData.blip.scale or 1.0)
    SetBlipDisplay(blip, npcData.blip.display or 4)
    SetBlipAsShortRange(blip, npcData.blip.shortRange ~= false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(npcData.blip.label or npcData.label)
    EndTextCommandSetBlipName(blip)

    return blip
end

-- Initialize NPCs
local function InitializeNPCs()
    DebugLog('npc', 'Initializing %d NPCs...', #Config.NPCs)

    targetSystem = DetectTargetSystem()

    for _, npcData in ipairs(Config.NPCs) do
        local ped = SpawnNPC(npcData)

        if ped then
            spawnedNPCs[npcData.id] = {
                ped = ped,
                data = npcData,
                blip = CreateNPCBlip(npcData)
            }

            if targetSystem == 'ox_target' then
                SetupOxTarget(npcData, ped)
            elseif targetSystem == 'qb-target' then
                SetupQBTarget(npcData, ped)
            end
        end
    end

    if targetSystem == 'none' then
        CreateThread(function()
            while true do
                local sleep = 1000
                local playerPed = PlayerPedId()
                local playerCoords = GetEntityCoords(playerPed)

                for _, npc in pairs(spawnedNPCs) do
                    local distance = #(playerCoords - vec3(npc.data.coords.x, npc.data.coords.y, npc.data.coords.z))

                    if distance < Config.InteractionDistance then
                        sleep = 0

                        BeginTextCommandDisplayHelp('STRING')
                        AddTextComponentSubstringPlayerName('Press ~INPUT_CONTEXT~ to ' .. npc.data.label)
                        EndTextCommandDisplayHelp(0, false, true, -1)

                        if IsControlJustReleased(0, Config.InteractionKey) then
                            InteractWithNPC(npc.data)
                        end

                        break
                    end
                end

                Wait(sleep)
            end
        end)
    end
end

-- Cleanup NPCs
local function CleanupNPCs()
    for id, npc in pairs(spawnedNPCs) do
        if DoesEntityExist(npc.ped) then
            if targetSystem == 'ox_target' then
                exports['ox_target']:removeLocalEntity(npc.ped)
            elseif targetSystem == 'qb-target' then
                exports['qb-target']:RemoveTargetEntity(npc.ped)
            end

            DeleteEntity(npc.ped)
        end

        if npc.blip then
            RemoveBlip(npc.blip)
        end
    end

    spawnedNPCs = {}
end

-- Resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    CleanupNPCs()
    CloseNUI()
end)

-- Wait for player to be fully loaded then spawn NPCs
CreateThread(function()
    -- Wait for player ped to exist
    while not PlayerPedId() or PlayerPedId() == 0 do
        Wait(100)
    end

    -- Additional wait for game to fully load
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(100)
    end

    Wait(1000)

    if next(spawnedNPCs) == nil then
        InitializeNPCs()
    end
end)

-- Backup: playerSpawned event
AddEventHandler('playerSpawned', function()
    Wait(500)
    if next(spawnedNPCs) == nil then
        InitializeNPCs()
    end
end)

-- ESX compatibility
RegisterNetEvent('esx:playerLoaded', function()
    Wait(500)
    if next(spawnedNPCs) == nil then
        InitializeNPCs()
    end
end)

-- QBCore compatibility
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(500)
    if next(spawnedNPCs) == nil then
        InitializeNPCs()
    end
end)
