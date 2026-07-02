local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer
local MAX_MESSAGES = 20
local VALUES_URL = "https://raw.githubusercontent.com/itsmashood/scripts/main/amvgg_values.lua"


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

local autoMagicDoor = false
local magicDoorDelay = 55
local magicDoorLoopRunning = false

local configFolder = "HouseHelperConfigs"
local configName = "default"
local selectedConfig = "default"
local autoloadFile = configFolder .. "/autoload.txt"

local lastHouseState = nil
local busyHouseState = false

local serverPlaceId = tostring(game.PlaceId)
local serverJobId = tostring(game.JobId)

local valueDb = nil
local valuesLoaded = false
local valuesLoading = false
local lookupName = "Shadow Dragon"
local lookupVariant = "regular"
local offerDefaultVariant = "regular"
local yourOfferText = ""
local theirOfferText = ""
local lookupParagraph = nil
local tradeParagraph = nil

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

    autoMagicDoor = data.autoMagicDoor == true

    magicDoorDelay = tonumber(data.magicDoorDelay) or 55
    if magicDoorDelay < 10 then magicDoorDelay = 10 end
    if magicDoorDelay > 60 then magicDoorDelay = 60 end

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
        activeMessageCount = activeMessageCount,
        autoMagicDoor = autoMagicDoor,
        magicDoorDelay = magicDoorDelay
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
    local magicDoorUnique = "2_6678f337ff7742638cbd7f6deb5581a0"

    local char = player.Character or player.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart")

    local equipRemote = api:FindFirstChild("ToolAPI/Equip")
    local placeRemote = api:FindFirstChild("PlaceableToolAPI/CreatePlaceable")

    if not equipRemote or not placeRemote then
        notify("House Helper", "Magic Door remotes missing.", 3)
        return
    end

    local equipOk, equipResult = pcall(function()
        return equipRemote:InvokeServer(magicDoorUnique)
    end)

    if not equipOk or equipResult == false then
        notify("House Helper", "Magic Door equip failed.", 3)
        return
    end

    task.wait(0.0001)

    local tool = char:FindFirstChild("PlaceableTool")
    if not tool then
        notify("House Helper", "Magic Door tool not found.", 3)
        return
    end

    local unique = tool:FindFirstChild("unique")
    if not unique then
        notify("House Helper", "Magic Door unique missing.", 3)
        return
    end

    local cf = root.CFrame * CFrame.new(0, -3, -3)

    local placeOk = pcall(function()
        return placeRemote:InvokeServer(cf, {
            unique = unique.Value
        })
    end)

    if placeOk then
        notify("House Helper", "Door placed", 2)
    else
        notify("House Helper", "Magic Door failed.", 3)
    end
end


local function startAutoMagicDoor()
    if magicDoorLoopRunning then return end

    magicDoorLoopRunning = true

    task.spawn(function()
        while autoMagicDoor do
            useMagicDoor()

            local waited = 0
            while autoMagicDoor and waited < magicDoorDelay do
                task.wait(1)
                waited += 1
            end
        end

        magicDoorLoopRunning = false
    end)
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

local function cleanText(text)
    return tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function norm(text)
    return cleanText(text):lower()
end

local function fmtNumber(value)
    value = tonumber(value)
    if not value then return "N/A" end
    local text = string.format("%.4f", value)
    return text:gsub("0+$", ""):gsub("%.$", "")
end

local function firstOption(option)
    if type(option) == "table" then
        return tostring(option[1] or "")
    end
    return tostring(option or "")
end

local function setParagraphSafe(paragraph, title, content)
    if paragraph and paragraph.Set then
        pcall(function()
            paragraph:Set({
                Title = title,
                Content = content
            })
        end)
    end
end

local function countValueItems()
    if not valueDb or type(valueDb.categories) ~= "table" then return 0 end
    local total = 0
    for _, items in pairs(valueDb.categories) do
        if type(items) == "table" then
            total = total + #items
        end
    end
    return total
end

local function loadValueDatabase()
    if valuesLoaded and valueDb then
        setParagraphSafe(lookupParagraph, "Values Ready", "Loaded items: " .. tostring(countValueItems()))
        return true
    end

    if valuesLoading then
        setParagraphSafe(lookupParagraph, "Values Loading", "Already loading. Wait a second.")
        return false
    end

    valuesLoading = true
    setParagraphSafe(lookupParagraph, "Values Loading", "Loading AMVGG values from GitHub...")

    local ok, result = pcall(function()
        return loadstring(game:HttpGet(VALUES_URL))()
    end)

    valuesLoading = false

    if ok and type(result) == "table" then
        valueDb = result
        valuesLoaded = true
        setParagraphSafe(lookupParagraph, "Values Ready", "Loaded items: " .. tostring(countValueItems()))
        return true
    end

    warn("[Trade Helper] Value load failed:", result)
    setParagraphSafe(lookupParagraph, "Values Failed", "Could not load amvgg_values.lua from GitHub.")
    notify("Trade Helper", "Failed to load values.", 3)
    return false
end

local function findValueItem(name, category)
    if not valueDb then return nil end

    local wanted = norm(name)
    if wanted == "" then return nil end

    local cat = category
    if cat == "all" or cat == "" then cat = nil end

    if valueDb.Get then
        local ok, item = pcall(function()
            return valueDb:Get(name, cat)
        end)
        if ok and item then return item end
    end

    if type(valueDb.categories) ~= "table" then return nil end

    if cat and type(valueDb.categories[cat]) == "table" then
        for _, item in ipairs(valueDb.categories[cat]) do
            if norm(item.name) == wanted then return item end
        end
        return nil
    end

    for _, items in pairs(valueDb.categories) do
        if type(items) == "table" then
            for _, item in ipairs(items) do
                if norm(item.name) == wanted then return item end
            end
        end
    end

    return nil
end

local variantKeys = {
    [""] = "regular",
    normal = "regular",
    regular = "regular",
    np = "no_potion_regular",
    ["no pot"] = "no_potion_regular",
    ["no potion"] = "no_potion_regular",
    fr = "regular",
    rf = "regular",
    ["fly ride"] = "regular",
    ["ride fly"] = "regular",
    r = "ride",
    ride = "ride",
    f = "fly",
    fly = "fly",
    n = "neon",
    neon = "neon",
    ["no potion neon"] = "no_potion_neon",
    ["np neon"] = "no_potion_neon",
    ["np n"] = "no_potion_neon",
    nfr = "neon",
    nrf = "neon",
    ["neon fly ride"] = "neon",
    nr = "neon_ride",
    ["neon ride"] = "neon_ride",
    nf = "neon_fly",
    ["neon fly"] = "neon_fly",
    m = "mega",
    mega = "mega",
    ["no potion mega"] = "no_potion_mega",
    ["np mega"] = "no_potion_mega",
    ["np m"] = "no_potion_mega",
    mfr = "mega",
    mrf = "mega",
    ["mega fly ride"] = "mega",
    mr = "mega_ride",
    ["mega ride"] = "mega_ride",
    mf = "mega_fly",
    ["mega fly"] = "mega_fly"
}

local fallbackKeys = {
    regular = {"regular"},
    ride = {"ride", "regular"},
    fly = {"fly", "regular"},
    no_potion_regular = {"no_potion_regular", "regular"},
    neon = {"neon", "regular"},
    neon_ride = {"neon_ride", "neon", "regular"},
    neon_fly = {"neon_fly", "neon", "regular"},
    no_potion_neon = {"no_potion_neon", "neon", "regular"},
    mega = {"mega", "regular"},
    mega_ride = {"mega_ride", "mega", "regular"},
    mega_fly = {"mega_fly", "mega", "regular"},
    no_potion_mega = {"no_potion_mega", "mega", "regular"}
}

local function getVariantKey(variant)
    variant = norm(variant)
    return variantKeys[variant] or variant:gsub("%s+", "_")
end

local function getItemValueFromItem(item, variant)
    if not item then return nil end

    local key = getVariantKey(variant)
    local fallbacks = fallbackKeys[key] or {key, "regular"}

    for _, fallbackKey in ipairs(fallbacks) do
        if item[fallbackKey] ~= nil then
            return item[fallbackKey], fallbackKey
        end
    end

    return item.regular, "regular"
end

local function getItemDemandFromItem(item, variant)
    if not item then return "N/A" end

    local key = getVariantKey(variant)
    local fallbacks = fallbackKeys[key] or {key, "regular"}

    for _, fallbackKey in ipairs(fallbacks) do
        local demand = item["demand_" .. fallbackKey]
        if demand ~= nil then return demand end
    end

    return item.demand_regular or "N/A"
end

local function lookupOneValue()
    if not valueDb and not loadValueDatabase() then return end

    local item = findValueItem(lookupName, "all")
    if not item then
        setParagraphSafe(lookupParagraph, "Not Found", "Could not find: " .. cleanText(lookupName))
        return
    end

    local selected, usedKey = getItemValueFromItem(item, lookupVariant)
    local demand = getItemDemandFromItem(item, lookupVariant)

    local content = tostring(item.name) .. " | " .. tostring(item.category or "")
    content = content .. "\nSelected: " .. lookupVariant .. " (" .. tostring(usedKey) .. ") = " .. fmtNumber(selected)
    content = content .. "\nR " .. fmtNumber(item.regular) .. " | NP " .. fmtNumber(item.no_potion_regular)
    content = content .. " | N " .. fmtNumber(item.neon) .. " | NNP " .. fmtNumber(item.no_potion_neon)
    content = content .. "\nM " .. fmtNumber(item.mega) .. " | MNP " .. fmtNumber(item.no_potion_mega)
    content = content .. "\nDemand: " .. tostring(demand)

    setParagraphSafe(lookupParagraph, "Item Value", content)
end

local function splitOffer(text)
    local list = {}
    text = tostring(text or ""):gsub("\r", "\n")

    for part in text:gmatch("[^,;\n]+") do
        part = cleanText(part)
        if part ~= "" then
            table.insert(list, part)
        end
    end

    return list
end

local prefixRules = {
    {"nfr ", "neon fly ride"}, {"nrf ", "neon fly ride"}, {"neon fly ride ", "neon fly ride"},
    {"nr ", "neon ride"}, {"neon ride ", "neon ride"}, {"nf ", "neon fly"}, {"neon fly ", "neon fly"},
    {"n ", "neon"}, {"neon ", "neon"},
    {"mfr ", "mega fly ride"}, {"mrf ", "mega fly ride"}, {"mega fly ride ", "mega fly ride"},
    {"mr ", "mega ride"}, {"mega ride ", "mega ride"}, {"mf ", "mega fly"}, {"mega fly ", "mega fly"},
    {"m ", "mega"}, {"mega ", "mega"},
    {"fr ", "fly ride"}, {"rf ", "fly ride"}, {"fly ride ", "fly ride"},
    {"r ", "ride"}, {"ride ", "ride"}, {"f ", "fly"}, {"fly ", "fly"}
}

local suffixRules = {
    {" nfr", "neon fly ride"}, {" nrf", "neon fly ride"}, {" neon fly ride", "neon fly ride"},
    {" nr", "neon ride"}, {" neon ride", "neon ride"}, {" nf", "neon fly"}, {" neon fly", "neon fly"},
    {" n", "neon"}, {" neon", "neon"},
    {" mfr", "mega fly ride"}, {" mrf", "mega fly ride"}, {" mega fly ride", "mega fly ride"},
    {" mr", "mega ride"}, {" mega ride", "mega ride"}, {" mf", "mega fly"}, {" mega fly", "mega fly"},
    {" m", "mega"}, {" mega", "mega"},
    {" fr", "fly ride"}, {" rf", "fly ride"}, {" fly ride", "fly ride"},
    {" r", "ride"}, {" ride", "ride"}, {" f", "fly"}, {" fly", "fly"}
}

local function parseOfferEntry(raw)
    local text = cleanText(raw)
    local amount = 1

    local amountText, rest = text:match("^(%d+)%s*[xX]%s+(.+)$")
    if amountText and rest then
        amount = tonumber(amountText) or 1
        text = rest
    end

    local lower = norm(text)
    local variant = offerDefaultVariant
    local noPotion = false

    local function stripPrefix(prefix, newVariant)
        text = cleanText(text:sub(#prefix + 1))
        lower = norm(text)
        variant = newVariant
    end

    local function stripSuffix(suffix, newVariant)
        text = cleanText(text:sub(1, #text - #suffix))
        lower = norm(text)
        variant = newVariant
    end

    for _, prefix in ipairs({"np ", "no pot ", "no potion "}) do
        if lower:sub(1, #prefix) == prefix then
            noPotion = true
            stripPrefix(prefix, variant)
            break
        end
    end

    for _, rule in ipairs(prefixRules) do
        if lower:sub(1, #rule[1]) == rule[1] then
            stripPrefix(rule[1], rule[2])
            break
        end
    end

    for _, suffix in ipairs({" np", " no pot", " no potion"}) do
        if lower:sub(-#suffix) == suffix then
            noPotion = true
            stripSuffix(suffix, variant)
            break
        end
    end

    for _, rule in ipairs(suffixRules) do
        if lower:sub(-#rule[1]) == rule[1] then
            stripSuffix(rule[1], rule[2])
            break
        end
    end

    if noPotion then
        local key = getVariantKey(variant)
        if key:find("mega") then
            variant = "no potion mega"
        elseif key:find("neon") then
            variant = "no potion neon"
        else
            variant = "no potion"
        end
    end

    return text, variant, amount
end

local function calculateOffer(text)
    if not valueDb and not loadValueDatabase() then
        return 0, {}, {"values not loaded"}
    end

    local total = 0
    local lines = {}
    local missing = {}

    for _, raw in ipairs(splitOffer(text)) do
        local name, variant, amount = parseOfferEntry(raw)
        local item = findValueItem(name, "all")

        if item then
            local rawValue, usedKey = getItemValueFromItem(item, variant)
            local value = (tonumber(rawValue) or 0) * amount
            total = total + value
            table.insert(lines, tostring(amount) .. "x " .. tostring(item.name) .. " [" .. variant .. " -> " .. tostring(usedKey) .. "] " .. fmtNumber(value))
        else
            table.insert(missing, raw)
        end
    end

    return total, lines, missing
end

local function calculateManualTrade()
    local yourTotal, yourLines, yourMissing = calculateOffer(yourOfferText)
    local theirTotal, theirLines, theirMissing = calculateOffer(theirOfferText)
    local diff = yourTotal - theirTotal

    local result = "FAIR"
    if diff > 0 then
        result = "LOSE for you by " .. fmtNumber(diff)
    elseif diff < 0 then
        result = "WIN for you by " .. fmtNumber(math.abs(diff))
    end

    local content = "YOU: " .. fmtNumber(yourTotal) .. " | THEM: " .. fmtNumber(theirTotal)
    content = content .. "\nResult: " .. result
    content = content .. "\n\nYour items:\n" .. (#yourLines > 0 and table.concat(yourLines, "\n") or "None")
    content = content .. "\n\nTheir items:\n" .. (#theirLines > 0 and table.concat(theirLines, "\n") or "None")

    if #yourMissing > 0 or #theirMissing > 0 then
        local missing = {}
        for _, item in ipairs(yourMissing) do table.insert(missing, item) end
        for _, item in ipairs(theirMissing) do table.insert(missing, item) end
        content = content .. "\n\nNot found: " .. table.concat(missing, ", ")
    end

    setParagraphSafe(tradeParagraph, "Trade Result", content)
end


local Window = Rayfield:CreateWindow({
    Name = "Xyneria hub",
    LoadingTitle = "Xyneria hub",
    LoadingSubtitle = "House Messenger",
    ConfigurationSaving = {
        Enabled = false
    }
})

local MainTab = Window:CreateTab("Main", 4483362458)
local TradeTab = Window:CreateTab("Trade Helper", 4483362458)
local MessengerTab = Window:CreateTab("Messenger", 4483362458)
local ConfigTab = Window:CreateTab("Config", 4483362458)
local ServerTab = Window:CreateTab("Server Hopper", 4483362458)

MainTab:CreateParagraph({
    Title = "Hub info",
    Content = "List/unlist your house, autoplace Magic Door, and auto message."
})

MainTab:CreateToggle({
    Name = "House Listed For Trade",
    CurrentValue = false,
    Callback = function(value)
        setHouseListed(value)
    end
})

MainTab:CreateToggle({
    Name = "Auto Place Magic Door",
    CurrentValue = autoMagicDoor,
    Callback = function(value)
        autoMagicDoor = value

        if autoMagicDoor then
            startAutoMagicDoor()
        end
    end
})

MainTab:CreateSlider({
    Name = "Magic Door Delay Seconds",
    Range = {10, 60},
    Increment = 1,
    Suffix = "s",
    CurrentValue = magicDoorDelay,
    Callback = function(value)
        magicDoorDelay = tonumber(value) or 55
        if magicDoorDelay < 10 then magicDoorDelay = 10 end
        if magicDoorDelay > 60 then magicDoorDelay = 60 end
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
    Name = "Which messages to count? 1-20 eg. only does 1-3 if 3 ignores rest",
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
    Name = "Start Auto Message",
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


TradeTab:CreateParagraph({
    Title = "Trade Helper",
    Content = "Values auto-load from GitHub. Plain pets use regular values. Use np/no potion for no-potion values."
})

TradeTab:CreateButton({
    Name = "Load / Reload Values",
    Callback = function()
        valuesLoaded = false
        valueDb = nil
        loadValueDatabase()
    end
})

TradeTab:CreateSection("Single Item Lookup")

TradeTab:CreateInput({
    Name = "Item Name",
    PlaceholderText = "Shadow Dragon",
    RemoveTextAfterFocusLost = false,
    CurrentValue = lookupName,
    Callback = function(text)
        lookupName = tostring(text or "")
    end
})

TradeTab:CreateDropdown({
    Name = "Variant",
    Options = {
        "no potion",
        "regular",
        "ride",
        "fly",
        "fly ride",
        "neon",
        "neon ride",
        "neon fly",
        "neon fly ride",
        "mega",
        "mega ride",
        "mega fly",
        "mega fly ride"
    },
    CurrentOption = {lookupVariant},
    MultipleOptions = false,
    Callback = function(option)
        lookupVariant = firstOption(option)
    end
})

TradeTab:CreateButton({
    Name = "Lookup Item Value",
    Callback = function()
        lookupOneValue()
    end
})

lookupParagraph = TradeTab:CreateParagraph({
    Title = "Lookup Result",
    Content = "Values loading..."
})

TradeTab:CreateSection("Manual Trade Calculator")

TradeTab:CreateDropdown({
    Name = "Default Variant For Plain Items",
    Options = {"regular", "no potion", "fly ride"},
    CurrentOption = {offerDefaultVariant},
    MultipleOptions = false,
    Callback = function(option)
        offerDefaultVariant = firstOption(option)
    end
})

TradeTab:CreateInput({
    Name = "Your Offer",
    PlaceholderText = "m kangaroo, fr cow, 2x n dog",
    RemoveTextAfterFocusLost = false,
    CurrentValue = yourOfferText,
    Callback = function(text)
        yourOfferText = tostring(text or "")
    end
})

TradeTab:CreateInput({
    Name = "Their Offer",
    PlaceholderText = "shadow dragon, nfr turtle",
    RemoveTextAfterFocusLost = false,
    CurrentValue = theirOfferText,
    Callback = function(text)
        theirOfferText = tostring(text or "")
    end
})

TradeTab:CreateButton({
    Name = "Calculate Trade",
    Callback = function()
        calculateManualTrade()
    end
})

TradeTab:CreateButton({
    Name = "Clear Trade Result",
    Callback = function()
        yourOfferText = ""
        theirOfferText = ""
        setParagraphSafe(tradeParagraph, "Trade Result", "Cleared. Re-execute to clear input boxes visually.")
    end
})

tradeParagraph = TradeTab:CreateParagraph({
    Title = "Trade Result",
    Content = "Examples: kangaroo, fr kangaroo, n kangaroo, nfr kangaroo, m kangaroo, mfr kangaroo."
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

if autoMagicDoor then
    startAutoMagicDoor()
end

task.spawn(function()
    task.wait(0.5)
    loadValueDatabase()
end)
