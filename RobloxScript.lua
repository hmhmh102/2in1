local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

if getgenv().AutoKillLoaded then return end
getgenv().AutoKillLoaded = true

local AUTO_SERVER_HOP = true
local SERVER_HOP_INTERVAL = 60
local LastServerHop = os.clock()

local function ServerHop()
    local PlaceId = game.PlaceId
    local JobId = game.JobId

    local success, servers = pcall(function()
        return HttpService:JSONDecode(
            game:HttpGet(
                "https://games.roblox.com/v1/games/"
                .. PlaceId
                .. "/servers/Public?sortOrder=Desc&limit=100"
            )
        )
    end)

    if not success or not servers or not servers.data then return end

    for _, server in ipairs(servers.data) do
        local filledPercent = server.playing / server.maxPlayers

        if server.id ~= JobId
        and server.playing >= 10          -- skip dead servers
        and filledPercent >= 0.6          -- high population only
        then
            TeleportService:TeleportToPlaceInstance(
                PlaceId,
                server.id,
                LocalPlayer
            )
            return
        end
    end
end

local Character, Humanoid, Hand, Punch
local LastAttack = 0
local Running = true

local WhitelistFriends = true
local KillOnlyWeaker = true

getgenv().WhitelistedPlayers = getgenv().WhitelistedPlayers or {}
getgenv().TempWhitelistStronger = getgenv().TempWhitelistStronger or {}

local BlockedAnimations = {
    ["rbxassetid://3638729053"] = true,
    ["rbxassetid://3638749874"] = true,
    ["rbxassetid://3638767427"] = true,
    ["rbxassetid://102357151005774"] = true
}

local function GetPlayerStatValue(Player, StatNames)
    if not Player then return nil end
    if type(StatNames) == "string" then StatNames = {StatNames} end

    for _, Name in ipairs(StatNames) do
        local Attr = Player:GetAttribute(Name)
        if Attr ~= nil then return tonumber(Attr) end
    end

    local stats = Player:FindFirstChild("leaderstats")
    if stats then
        for _, Name in ipairs(StatNames) do
            local v = stats:FindFirstChild(Name)
            if v then return tonumber(v.Value) end
        end
    end
    return nil
end

local function GetLocalPlayerDamage()
    return GetPlayerStatValue(LocalPlayer, {"Damage","DMG","Attack","Strength","Str"}) or 1
end

local function GetTargetHealth(Player)
    local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
    return hum and hum.MaxHealth or 100
end

local function UpdateAll()
    Character = LocalPlayer.Character
    Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
    Hand = Character and (Character:FindFirstChild("LeftHand") or Character:FindFirstChild("Left Arm"))
    Punch = Character and Character:FindFirstChild("Punch")
end

local function ShouldKillPlayer(player)
    if not KillOnlyWeaker then return true end
    local hits = math.ceil(GetTargetHealth(player) / GetLocalPlayerDamage())
    return hits <= 5
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    UpdateAll()
end)

UpdateAll()

LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

RunService.RenderStepped:Connect(function()
    -- SERVER HOP
    if AUTO_SERVER_HOP and os.clock() - LastServerHop >= SERVER_HOP_INTERVAL then
        LastServerHop = os.clock()
        ServerHop()
        return
    end

    if not Running or not Character or not Humanoid then return end
    if os.clock() - LastAttack < 0.05 then return end
    LastAttack = os.clock()

    if not Punch then
        local tool = LocalPlayer.Backpack:FindFirstChild("Punch")
        if tool then
            Humanoid:EquipTool(tool)
        end
        Punch = Character:FindFirstChild("Punch")
        return
    end

    Punch.attackTime.Value = 0
    Punch:Activate()

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and ShouldKillPlayer(player) then
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local head = char and char:FindFirstChild("Head")
            local root = char and char:FindFirstChild("HumanoidRootPart")

            if hum and head and root and hum.Health > 0 then
                local wasAnchored = root.Anchored
                root.Anchored = true
                firetouchinterest(head, Hand, 0)
                firetouchinterest(head, Hand, 1)
                root.Anchored = wasAnchored
            end
        end
    end
end)

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local startKills = 0
local startTime = os.time()

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "KillTrackerGUI"
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 300, 0, 180)
mainFrame.Position = UDim2.new(0, 10, 0, 10)
mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
mainFrame.BorderSizePixel = 2
mainFrame.BorderColor3 = Color3.fromRGB(150, 0, 0)
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 25)
title.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
title.Text = "☠️ KILL TRACKER"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextScaled = true
title.Parent = mainFrame

local container = Instance.new("Frame")
container.Size = UDim2.new(1, -10, 1, -60)
container.Position = UDim2.new(0, 5, 0, 30)
container.BackgroundTransparency = 1
container.Parent = mainFrame

local killLabel = Instance.new("TextLabel")
killLabel.Size = UDim2.new(1, 0, 0, 20)
killLabel.BackgroundTransparency = 1
killLabel.TextXAlignment = Enum.TextXAlignment.Left
killLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
killLabel.Font = Enum.Font.GothamBold
killLabel.TextSize = 14
killLabel.Text = "☠️ Kills"
killLabel.Parent = container

local currentLabel = Instance.new("TextLabel")
currentLabel.Size = UDim2.new(0.5, -5, 0, 20)
currentLabel.Position = UDim2.new(0, 0, 0, 25)
currentLabel.BackgroundTransparency = 1
currentLabel.TextXAlignment = Enum.TextXAlignment.Left
currentLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
currentLabel.Font = Enum.Font.Gotham
currentLabel.TextSize = 12
currentLabel.Text = "Current: 0"
currentLabel.Parent = container

local gainedLabel = Instance.new("TextLabel")
gainedLabel.Size = UDim2.new(0.5, -5, 0, 20)
gainedLabel.Position = UDim2.new(0.5, 5, 0, 25)
gainedLabel.BackgroundTransparency = 1
gainedLabel.TextXAlignment = Enum.TextXAlignment.Left
gainedLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
gainedLabel.Font = Enum.Font.Gotham
gainedLabel.TextSize = 12
gainedLabel.Text = "Gained: +0"
gainedLabel.Parent = container

local timerLabel = Instance.new("TextLabel")
timerLabel.Size = UDim2.new(1, 0, 0, 18)
timerLabel.Position = UDim2.new(0, 0, 0, 50)
timerLabel.BackgroundTransparency = 1
timerLabel.TextXAlignment = Enum.TextXAlignment.Left
timerLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
timerLabel.Font = Enum.Font.Gotham
timerLabel.TextSize = 11
timerLabel.Text = "⏰ Time: 00:00:00"
timerLabel.Parent = container

local kpmLabel = Instance.new("TextLabel")
kpmLabel.Size = UDim2.new(1, 0, 0, 18)
kpmLabel.Position = UDim2.new(0, 0, 0, 70)
kpmLabel.BackgroundTransparency = 1
kpmLabel.TextXAlignment = Enum.TextXAlignment.Left
kpmLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
kpmLabel.Font = Enum.Font.GothamBold
kpmLabel.TextSize = 12
kpmLabel.Text = "⚔️ KPM: 0.00"
kpmLabel.Parent = container

local resetButton = Instance.new("TextButton")
resetButton.Size = UDim2.new(1, -10, 0, 22)
resetButton.Position = UDim2.new(0, 5, 1, -27)
resetButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
resetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
resetButton.Font = Enum.Font.Gotham
resetButton.TextSize = 11
resetButton.Text = "🔄 RESET SESSION"
resetButton.Parent = mainFrame

local function getKills()
    if player:FindFirstChild("leaderstats") then
        local k = player.leaderstats:FindFirstChild("Kills")
        if k then return k.Value end
    end
    return 0
end

local function abbreviate(num)
    if num < 1000 then return tostring(num) end
    local suffix = {"K","M","B","T"}
    local tier = math.floor(math.log10(num) / 3)
    return string.format("%.2f%s", num / (10^(tier*3)), suffix[tier])
end

local function resetSession()
    startKills = getKills()
    startTime = os.time()
end

resetSession()

local function update()
    local currentKills = getKills()

    if currentKills < startKills then
        resetSession()
    end

    local gained = math.max(0, currentKills - startKills)
    local elapsed = os.time() - startTime
    local minutes = math.max(elapsed / 60, 1/60)
    local kpm = gained / minutes

    currentLabel.Text = "Current: " .. abbreviate(currentKills)
    gainedLabel.Text = "Gained: +" .. abbreviate(gained)

    local h = math.floor(elapsed / 3600)
    local m = math.floor((elapsed % 3600) / 60)
    local s = elapsed % 60

    timerLabel.Text = string.format("⏰ Time: %02d:%02d:%02d", h, m, s)
    kpmLabel.Text = string.format("⚔️ KPM: %.2f", kpm)
end

resetButton.MouseButton1Click:Connect(resetSession)

task.spawn(function()
    while true do
        update()
        task.wait(1)
    end
end)

print("🙏 Thank you HALIS for letting me use this.")