local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

pcall(function()
	local old = pg:FindFirstChild("PremiumServerTeleporter")
	if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "PremiumServerTeleporter"
gui.ResetOnSpawn = false
gui.Parent = pg

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 430, 0, 350)
main.Position = UDim2.new(0.5, -215, 0.5, -175)
main.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
main.Active = true
main.Draggable = true
main.Parent = gui

Instance.new("UICorner", main).CornerRadius = UDim.new(0, 18)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(145, 90, 255)
stroke.Thickness = 2
stroke.Transparency = 0.15
stroke.Parent = main

local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 20, 45)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 12, 18))
}
grad.Rotation = 45
grad.Parent = main

local topGlow = Instance.new("Frame")
topGlow.Size = UDim2.new(1, 0, 0, 70)
topGlow.BackgroundColor3 = Color3.fromRGB(120, 70, 255)
topGlow.BackgroundTransparency = 0.78
topGlow.Parent = main
Instance.new("UICorner", topGlow).CornerRadius = UDim.new(0, 18)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -70, 0, 32)
title.Position = UDim2.new(0, 22, 0, 18)
title.BackgroundTransparency = 1
title.Text = "Server Hopper"
title.TextColor3 = Color3.fromRGB(255,255,255)
title.Font = Enum.Font.GothamBold
title.TextSize = 24
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main

local sub = Instance.new("TextLabel")
sub.Size = UDim2.new(1, -44, 0, 22)
sub.Position = UDim2.new(0, 22, 0, 50)
sub.BackgroundTransparency = 1
sub.Text = "Teleport directly using PlaceId + JobId"
sub.TextColor3 = Color3.fromRGB(180, 175, 205)
sub.Font = Enum.Font.Gotham
sub.TextSize = 13
sub.TextXAlignment = Enum.TextXAlignment.Left
sub.Parent = main

local close = Instance.new("TextButton")
close.Size = UDim2.new(0, 34, 0, 34)
close.Position = UDim2.new(1, -48, 0, 16)
close.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
close.Text = "×"
close.TextColor3 = Color3.fromRGB(255,255,255)
close.TextSize = 24
close.Font = Enum.Font.GothamBold
close.Parent = main
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 10)

local function label(txt, y)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, -44, 0, 18)
	l.Position = UDim2.new(0, 22, 0, y)
	l.BackgroundTransparency = 1
	l.Text = txt
	l.TextColor3 = Color3.fromRGB(220,220,235)
	l.Font = Enum.Font.GothamSemibold
	l.TextSize = 13
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = main
end

local function box(y, placeholder, default)
	local b = Instance.new("TextBox")
	b.Size = UDim2.new(1, -44, 0, 42)
	b.Position = UDim2.new(0, 22, 0, y)
	b.BackgroundColor3 = Color3.fromRGB(24, 24, 35)
	b.TextColor3 = Color3.fromRGB(255,255,255)
	b.PlaceholderColor3 = Color3.fromRGB(115,115,135)
	b.PlaceholderText = placeholder
	b.Text = default
	b.ClearTextOnFocus = false
	b.Font = Enum.Font.Gotham
	b.TextSize = 14
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.Parent = main

	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 12)

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = b

	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(70, 65, 95)
	s.Thickness = 1
	s.Transparency = 0.25
	s.Parent = b

	b.Focused:Connect(function()
		TweenService:Create(s, TweenInfo.new(.15), {
			Color = Color3.fromRGB(155, 100, 255),
			Transparency = 0
		}):Play()
	end)

	b.FocusLost:Connect(function()
		TweenService:Create(s, TweenInfo.new(.15), {
			Color = Color3.fromRGB(70, 65, 95),
			Transparency = 0.25
		}):Play()
	end)

	return b
end

local function makeButton(text, y, color1, color2)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -44, 0, 42)
	b.Position = UDim2.new(0, 22, 0, y)
	b.BackgroundColor3 = color1
	b.Text = text
	b.TextColor3 = Color3.fromRGB(255,255,255)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	b.Parent = main

	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 14)

	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, color1),
		ColorSequenceKeypoint.new(1, color2)
	}
	g.Parent = b

	return b
end

label("PlaceId", 88)
local placeBox = box(108, "920587237", "920587237")

label("Server ID / JobId", 158)
local jobBox = box(178, "70c47d38-ec59-40e6-a976-def4ffdf5813", "70c47d38-ec59-40e6-a976-def4ffdf5813")

local btn = makeButton(
	"Teleport to JobId",
	232,
	Color3.fromRGB(170, 100, 255),
	Color3.fromRGB(95, 70, 255)
)

local randomBtn = makeButton(
	"Teleport to Random Server",
	282,
	Color3.fromRGB(60, 60, 85),
	Color3.fromRGB(35, 35, 55)
)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -44, 0, 18)
status.Position = UDim2.new(0, 22, 1, -24)
status.BackgroundTransparency = 1
status.Text = ""
status.TextColor3 = Color3.fromRGB(180,180,200)
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.TextXAlignment = Enum.TextXAlignment.Center
status.Parent = main

close.MouseButton1Click:Connect(function()
	gui:Destroy()
end)

btn.MouseButton1Click:Connect(function()
	local placeId = tonumber(placeBox.Text)
	local jobId = jobBox.Text:gsub("%s+", "")

	if not placeId then
		status.Text = "Invalid PlaceId"
		return
	end

	if jobId == "" then
		status.Text = "Invalid JobId"
		return
	end

	btn.Text = "Teleporting..."
	status.Text = "Attempting to join server..."

	local ok, err = pcall(function()
		TeleportService:TeleportToPlaceInstance(placeId, jobId, player)
	end)

	if not ok then
		warn(err)
		btn.Text = "Teleport to JobId"
		status.Text = "Teleport failed"
	end
end)

randomBtn.MouseButton1Click:Connect(function()
	local placeId = tonumber(placeBox.Text) or game.PlaceId

	randomBtn.Text = "Finding server..."
	status.Text = "Searching for public servers..."

	local ok, result = pcall(function()
		return game:HttpGet(
			"https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
		)
	end)

	if not ok then
		randomBtn.Text = "Teleport to Random Server"
		status.Text = "Could not fetch servers"
		return
	end

	local data
	local decoded = pcall(function()
		data = HttpService:JSONDecode(result)
	end)

	if not decoded or not data or not data.data then
		randomBtn.Text = "Teleport to Random Server"
		status.Text = "Invalid server data"
		return
	end

	local servers = {}

	for _, server in ipairs(data.data) do
		if server.id ~= game.JobId and server.playing < server.maxPlayers then
			table.insert(servers, server.id)
		end
	end

	if #servers == 0 then
		randomBtn.Text = "Teleport to Random Server"
		status.Text = "No open servers found"
		return
	end

	local randomJobId = servers[math.random(1, #servers)]

	randomBtn.Text = "Teleporting..."
	status.Text = "Joining random server..."

	local tpOk, tpErr = pcall(function()
		TeleportService:TeleportToPlaceInstance(placeId, randomJobId, player)
	end)

	if not tpOk then
		warn(tpErr)
		randomBtn.Text = "Teleport to Random Server"
		status.Text = "Random teleport failed"
	end
end)
