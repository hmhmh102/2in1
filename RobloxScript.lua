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

