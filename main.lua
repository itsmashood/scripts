local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer
local MAX_MESSAGES = 20

local Messages = {
    "Trading pets!",
    "Visit my house!",
    "Offers welcome!"
}

for i = 4, MAX_MESSAGES do
    Messages[i] = ""
end

local activeMessageCount = MAX_MESSAGES
local interval = 5
local sending = false

local configFolder = "HouseHelperConfigs"
local configName = "default"
local selectedConfig = "default"
local autoloadFile = configFolder .. "/autoload.txt"

local lastHouseState = nil
local busyHouseState = false

local serverPlaceId = tostring(game.PlaceId)
local serverJobId = tostring(game.JobId)

local function notify(title, content, duration)
    Rayfield:Notify({
        Title = title,
        Content = content,
        Duration = duration or 2
    })
end

local function safeName(name)
    name = tostring(name or "default"):gsub("[^%w_%-%s]", "")
    if name == "" then name = "default" end
    return name
end

local function ensureFolder()
    if makefolder and isfolder and not isfolder(configFolder) then
        pcall(function()
            makefolder(configFolder)
        end)
    elseif makefolder and not isfolder then
        pcall(function()
            makefolder(configFolder)
        end)
    end
end

local function getConfigPath(name)
    name = safeName(name or configName)
    return configFolder .. "/" .. name .. ".json"
end

local function applyConfigData(data)
    if type(data) ~= "table" then return false end

    local loadedMessages = data.messages or {}

    for i = 1, MAX_MESSAGES do
        Messages[i] = tostring(loadedMessages[i] or "")
    end

    interval = tonumber(data.interval) or 5
    if interval < 5 then interval = 5 end

    activeMessageCount = tonumber(data.activeMessageCount) or MAX_MESSAGES
    if activeMessageCount < 1 then activeMessageCount = 1 end
    if activeMessageCount > MAX_MESSAGES then activeMessageCount = MAX_MESSAGES end

    return true
end

local function loadAutoloadName()
    if isfile and readfile and isfile(autoloadFile) then
        local saved = safeName(readfile(autoloadFile))
        if saved ~= "" then
            configName = saved
            selectedConfig = saved
        end
    end
end

local function loadConfigSilent()
    if not isfile or not readfile then return end

    local path = getConfigPath(configName)
    if not isfile(path) then return end

    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)

    if ok then
        applyConfigData(data)
    end
end

loadAutoloadName()
loadConfigSilent()

local function getConfigList()
    local list = {}

    if listfiles and isfolder and isfolder(configFolder) then
        for _, file in ipairs(listfiles(configFolder)) do
            local name = tostring(file):match("([^/\\]+)%.json$")
            if name then
                table.insert(list, name)
            end
        end
    end

    if #list == 0 then
        table.insert(list, "default")
    end

    return list
end

local function saveConfig()
    if not writefile then
        notify("House Helper", "writefile not supported.", 3)
        return
    end

    ensureFolder()

    local data = {
        messages = Messages,
        interval = interval,
        activeMessageCount = activeMessageCount
    }

    local ok, err = pcall(function()
        writefile(getConfigPath(configName), HttpService:JSONEncode(data))
    end)

    if ok then
        selectedConfig = configName
        notify("House Helper", "Config saved: " .. safeName(configName), 2)
    else
        warn(err)
        notify("House Helper", "Config save failed.", 3)
    end
end

local function createNewConfig()
    configName = safeName(configName)
    selectedConfig = configName
    ensureFolder()

    if isfile and isfile(getConfigPath(configName)) then
        notify("House Helper", "Config already exists: " .. configName, 3)
        return
    end

    saveConfig()
    notify("House Helper", "Created config: " .. configName .. ". Re-execute to refresh dropdown.", 4)
end

local function loadConfig(name)
    if not isfile or not readfile then
        notify("House Helper", "readfile/isfile not supported.", 3)
        return
    end

    configName = safeName(name or selectedConfig or configName)
    selectedConfig = configName

    local path = getConfigPath(configName)

    if not isfile(path) then
        notify("House Helper", "Config not found: " .. configName, 3)
        return
    end

    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)

    if ok and applyConfigData(data) then
        notify("House Helper", "Loaded: " .. configName .. ". Re-execute to refresh boxes.", 4)
    else
        notify("House Helper", "Failed to load config.", 3)
    end
end

local function setAutoloadConfig()
    if not writefile then
        notify("House Helper", "writefile not supported.", 3)
        return
    end

    ensureFolder()
    local name = safeName(selectedConfig or configName)

    local ok, err = pcall(function()
        writefile(autoloadFile, name)
    end)

    if ok then
        notify("House Helper", "Autoload set to: " .. name, 3)
    else
        warn(err)
        notify("House Helper", "Failed to set autoload.", 3)
    end
end

local function clearAutoloadConfig()
    if delfile and isfile and isfile(autoloadFile) then
        delfile(autoloadFile)
        notify("House Helper", "Autoload cleared.", 2)
    else
        notify("House Helper", "No autoload found.", 2)
    end
end

local function sendChatMessage(msg)
    pcall(function()
        local channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")

        if channel then
            channel:SendAsync(msg)
        else
            ReplicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(msg, "All")
        end
    end)
end

local function callRemote(remoteName)
    local api = ReplicatedStorage:WaitForChild("API")
    local remote = api:FindFirstChild(remoteName)

    if not remote then
        warn("[House Helper]: " .. remoteName .. " not found")
        notify("House Helper", remoteName .. " not found.", 3)
        return false
    end

    local ok, result = pcall(function()
        if remote:IsA("RemoteFunction") then
            return remote:InvokeServer()
        elseif remote:IsA("RemoteEvent") then
            remote:FireServer()
            return "FireServer sent"
        else
            return "Not a remote"
        end
    end)

    print("[House Helper]:", remoteName, ok, result)
    return ok, result
end

local function setHouseListed(shouldList)
    if busyHouseState then return end
    if lastHouseState == shouldList then return end

    busyHouseState = true
    lastHouseState = shouldList

    local remoteName = shouldList and "HousingAPI/ListHouse" or "HousingAPI/UnlistHouse"
    local ok = callRemote(remoteName)

    if ok then
        notify("House Helper", shouldList and "House listed for trade!" or "House unlisted!", 2)
    else
        notify("House Helper", "Failed to change house status.", 2)
        lastHouseState = not shouldList
    end

    task.wait(0.5)
    busyHouseState = false
end

-- keep your current script exactly the same,
-- but replace ONLY your useMagicDoor() function with this:

local function useMagicDoor()
    local api = ReplicatedStorage:WaitForChild("API")
    local remote = api:FindFirstChild("PlaceableToolAPI/UseMagicHouseDoor")

    if not remote then
        notify("House Helper", "UseMagicHouseDoor not found.", 3)
        return
    end

    local ok, result = pcall(function()
        if remote:IsA("RemoteFunction") then
            return remote:InvokeServer()
        elseif remote:IsA("RemoteEvent") then
            remote:FireServer()
            return "FireServer sent"
        end
    end)

    print("[House Helper]: UseMagicHouseDoor:", ok, result)

    if ok then
        notify("House Helper", "Magic Door used!", 2)
    else
        notify("House Helper", "Magic Door failed.", 3)
    end
end

local function teleportToJobId()
    local placeId = tonumber(serverPlaceId)
    local jobId = tostring(serverJobId):gsub("%s+", "")

    if not placeId then
        notify("Server Hopper", "Invalid PlaceId.", 3)
        return
    end

    if jobId == "" then
        notify("Server Hopper", "Invalid JobId.", 3)
        return
    end

    notify("Server Hopper", "Teleporting to JobId...", 2)

    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(placeId, jobId, player)
    end)

    if not ok then
        warn(err)
        notify("Server Hopper", "Teleport failed.", 3)
    end
end

local function teleportRandomServer()
    local placeId = tonumber(serverPlaceId) or game.PlaceId

    notify("Server Hopper", "Finding random server...", 2)

    local ok, result = pcall(function()
        return game:HttpGet(
            "https://games.roblox.com/v1/games/" ..
            placeId ..
            "/servers/Public?sortOrder=Asc&limit=100"
        )
    end)

    if not ok then
        notify("Server Hopper", "Could not fetch servers.", 3)
        return
    end

    local data
    local decoded = pcall(function()
        data = HttpService:JSONDecode(result)
    end)

    if not decoded or not data or not data.data then
        notify("Server Hopper", "Invalid server data.", 3)
        return
    end

    local servers = {}

    for _, server in ipairs(data.data) do
        if server.id ~= game.JobId and server.playing < server.maxPlayers then
            table.insert(servers, server.id)
        end
    end

    if #servers == 0 then
        notify("Server Hopper", "No open servers found.", 3)
        return
    end

    local randomJobId = servers[math.random(1, #servers)]

    notify("Server Hopper", "Joining random server...", 2)

    local tpOk, tpErr = pcall(function()
        TeleportService:TeleportToPlaceInstance(placeId, randomJobId, player)
    end)

    if not tpOk then
        warn(tpErr)
        notify("Server Hopper", "Random teleport failed.", 3)
    end
end

local function copyCurrentServerInfo()
    local info =
        "PlaceId: " .. tostring(game.PlaceId) ..
        "\nServer ID: " .. tostring(game.JobId)

    if setclipboard then
        setclipboard(info)
        notify("Server Hopper", "Current server info copied.", 2)
    else
        print(info)
        notify("Server Hopper", "Clipboard unsupported. Printed info.", 3)
    end
end

local Window = Rayfield:CreateWindow({
    Name = "House Helper",
    LoadingTitle = "House Helper",
    LoadingSubtitle = "House Messenger",
    ConfigurationSaving = {
        Enabled = false
    }
})

local MainTab = Window:CreateTab("Main", 4483362458)
local MessengerTab = Window:CreateTab("Messenger", 4483362458)
local ConfigTab = Window:CreateTab("Config", 4483362458)
local ServerTab = Window:CreateTab("Server Hopper", 4483362458)

MainTab:CreateParagraph({
    Title = "House Helper",
    Content = "List/unlist your house, place Magic Door, and start messenger."
})

MainTab:CreateToggle({
    Name = "House Listed For Trade",
    CurrentValue = false,
    Callback = function(value)
        setHouseListed(value)
    end
})

MainTab:CreateButton({
    Name = "Place Magic Door",
    Callback = function()
        useMagicDoor()
    end
})

MainTab:CreateInput({
    Name = "Interval Seconds",
    PlaceholderText = "5",
    RemoveTextAfterFocusLost = false,
    CurrentValue = tostring(interval),
    Callback = function(text)
        interval = tonumber(text) or 5
        if interval < 5 then interval = 5 end
    end
})

MainTab:CreateInput({
    Name = "Active Message Count",
    PlaceholderText = "20",
    RemoveTextAfterFocusLost = false,
    CurrentValue = tostring(activeMessageCount),
    Callback = function(text)
        activeMessageCount = tonumber(text) or MAX_MESSAGES
        if activeMessageCount < 1 then activeMessageCount = 1 end
        if activeMessageCount > MAX_MESSAGES then activeMessageCount = MAX_MESSAGES end
    end
})

MainTab:CreateToggle({
    Name = "Start Messenger",
    CurrentValue = false,
    Callback = function(value)
        sending = value

        if sending then
            task.spawn(function()
                while sending do
                    for i = 1, activeMessageCount do
                        if not sending then break end

                        local msg = Messages[i]

                        if msg and msg ~= "" then
                            sendChatMessage(msg)
                        end

                        task.wait(interval)
                    end
                end
            end)
        end
    end
})

MessengerTab:CreateParagraph({
    Title = "Messages",
    Content = "20 message boxes. Empty boxes are skipped."
})

MessengerTab:CreateSection("Message Boxes")

for i = 1, MAX_MESSAGES do
    MessengerTab:CreateInput({
        Name = "Message " .. i,
        PlaceholderText = "Input message...",
        RemoveTextAfterFocusLost = false,
        CurrentValue = Messages[i] or "",
        Callback = function(text)
            Messages[i] = text
        end
    })
end

ConfigTab:CreateParagraph({
    Title = "Config",
    Content = "Create configs, switch between configs, and set one to autoload."
})

ConfigTab:CreateInput({
    Name = "Config Name",
    PlaceholderText = "default",
    RemoveTextAfterFocusLost = false,
    CurrentValue = configName,
    Callback = function(text)
        configName = safeName(text)
        selectedConfig = configName
    end
})

ConfigTab:CreateDropdown({
    Name = "Select Saved Config",
    Options = getConfigList(),
    CurrentOption = {selectedConfig},
    MultipleOptions = false,
    Callback = function(option)
        if type(option) == "table" then
            selectedConfig = safeName(option[1])
        else
            selectedConfig = safeName(option)
        end

        configName = selectedConfig
    end
})

ConfigTab:CreateButton({
    Name = "Create New Config",
    Callback = function()
        createNewConfig()
    end
})

ConfigTab:CreateButton({
    Name = "Save / Overwrite Config",
    Callback = function()
        saveConfig()
    end
})

ConfigTab:CreateButton({
    Name = "Load Selected Config",
    Callback = function()
        loadConfig(selectedConfig)
    end
})

ConfigTab:CreateButton({
    Name = "Set Selected as Autoload",
    Callback = function()
        setAutoloadConfig()
    end
})

ConfigTab:CreateButton({
    Name = "Clear Autoload",
    Callback = function()
        clearAutoloadConfig()
    end
})

ServerTab:CreateParagraph({
    Title = "Server Hopper",
    Content = "Teleport by PlaceId + JobId, hop to a random public server, or copy the current server info."
})

ServerTab:CreateInput({
    Name = "PlaceId",
    PlaceholderText = tostring(game.PlaceId),
    RemoveTextAfterFocusLost = false,
    CurrentValue = tostring(game.PlaceId),
    Callback = function(text)
        serverPlaceId = text
    end
})

ServerTab:CreateInput({
    Name = "Server ID / JobId",
    PlaceholderText = "Paste JobId here...",
    RemoveTextAfterFocusLost = false,
    CurrentValue = tostring(game.JobId),
    Callback = function(text)
        serverJobId = text
    end
})

ServerTab:CreateButton({
    Name = "Teleport to JobId",
    Callback = function()
        teleportToJobId()
    end
})

ServerTab:CreateButton({
    Name = "Teleport to Random Server",
    Callback = function()
        teleportRandomServer()
    end
})

ServerTab:CreateButton({
    Name = "Copy Current Server Info",
    Callback = function()
        copyCurrentServerInfo()
    end
})
