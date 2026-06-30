local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

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

local configFolder = "HouseHelper"
local configName = "default"

local lastHouseState = nil
local busyHouseState = false

local function notify(title, content, duration)
    Rayfield:Notify({
        Title = title,
        Content = content,
        Duration = duration or 2
    })
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

local function safeName(name)
    name = tostring(name or "default"):gsub("[^%w_%-%s]", "")
    if name == "" then
        name = "default"
    end
    return name
end

local function getConfigPath()
    return configFolder .. "/" .. safeName(configName) .. ".json"
end

local function saveConfig()
    if not writefile then
        notify("House Helper", "writefile not supported.", 3)
        return
    end

    if makefolder and isfolder and not isfolder(configFolder) then
        makefolder(configFolder)
    elseif makefolder and not isfolder then
        pcall(function()
            makefolder(configFolder)
        end)
    end

    writefile(getConfigPath(), HttpService:JSONEncode({
        messages = Messages,
        interval = interval
    }))

    notify("House Helper", "Config saved / overwritten.", 2)
end

local function loadConfig()
    local path = getConfigPath()

    if not isfile or not readfile or not isfile(path) then
        notify("House Helper", "Config not found.", 3)
        return
    end

    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)

    if ok and type(data) == "table" then
        local loadedMessages = data.messages or {}

        for i = 1, MAX_MESSAGES do
            Messages[i] = loadedMessages[i] or ""
        end

        interval = tonumber(data.interval) or interval

        notify("House Helper", "Config loaded. Re-execute to refresh input text.", 4)
    else
        notify("House Helper", "Failed to load config.", 3)
    end
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

local function useMagicDoor()
    local char = player.Character or player.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart")

    local tool = char:FindFirstChild("PlaceableTool")

    if not tool then
        notify("House Helper", "Equip the Magic Door first.", 3)
        return
    end

    local unique = tool:FindFirstChild("unique")

    if not unique then
        notify("House Helper", "Magic Door unique not found.", 3)
        return
    end

    local api = ReplicatedStorage:WaitForChild("API")
    local remote = api:FindFirstChild("PlaceableToolAPI/CreatePlaceable")

    if not remote then
        notify("House Helper", "CreatePlaceable not found.", 3)
        return
    end

    local cf = root.CFrame * CFrame.new(0, -4, -6)

    local ok, result = pcall(function()
        return remote:InvokeServer(cf, {
            unique = unique.Value
        })
    end)

    print("[House Helper]: Magic Door:", ok, result)

    if ok then
        notify("House Helper", "Magic Door placed!", 2)
    else
        notify("House Helper", "Magic Door failed.", 2)
    end
end

local Window = Rayfield:CreateWindow({
    Name = "🏠 House Helper",
    LoadingTitle = "House Helper",
    LoadingSubtitle = "House Messenger",
    ConfigurationSaving = {
        Enabled = false
    }
})

local MainTab = Window:CreateTab("Main", 4483362458)
local MessengerTab = Window:CreateTab("Messenger", 4483362458)
local ConfigTab = Window:CreateTab("Config", 4483362458)

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
        if interval < 5 then
            interval = 5
        end
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
    Content = "Save, load, or overwrite message configs."
})

ConfigTab:CreateInput({
    Name = "Config Name",
    PlaceholderText = "default",
    RemoveTextAfterFocusLost = false,
    CurrentValue = configName,
    Callback = function(text)
        configName = safeName(text)
    end
})

ConfigTab:CreateButton({
    Name = "Save / Overwrite Config",
    Callback = function()
        saveConfig()
    end
})

ConfigTab:CreateButton({
    Name = "Load Config",
    Callback = function()
        loadConfig()
    end
})
