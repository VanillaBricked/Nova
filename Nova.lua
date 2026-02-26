--[[
    ╔══════════════════════════════════════════════════╗
    ║                 NOVA v2.2                        ║
    ║         Built with Rayfield UI Library           ║
    ║        For use in YOUR OWN game only             ║
    ╚══════════════════════════════════════════════════╝
    
    TIERS:
    Free    → ESP (box/name/dist), Aim Lock, Speed, Jump, Fullbright, Server
    Premium → + Health ESP, Tracers, ESP Color, Fly, Noclip, Player Tools
    Elite   → + Wall Check, Inf Jump, Limb Targeting, Config Save, FOV Color
    
    HOLD RMB = Lock aim (FREE)
    RightCtrl = Toggle UI
]]

-- ═══════════════════════════════════════════
-- SERVICES
-- ═══════════════════════════════════════════
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- ═══════════════════════════════════════════
-- LOAD RAYFIELD
-- ═══════════════════════════════════════════
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

-- ═══════════════════════════════════════════
-- TIER SYSTEM
--
-- We save our own file (NovaTierData.txt) to
-- track which tier the user activated. This is
-- 100% reliable across all executors. Rayfield's
-- key system is just the entry gate - any valid
-- key gets you in. Then in Settings, users paste
-- their Premium/Elite key ONCE and it saves forever.
-- ═══════════════════════════════════════════
local TIER_FILE = "NovaTierData.txt"
local UserTier = "Free"

local KEYS = {
    ["HQHDRTAMNDSOSUI9HSL78BAJRKLIUASLOP"] = "Free",
    ["NOVA-PREMIUM-VIP"] = "Premium",
    ["NOVA-LIFETIME-ELITE"] = "Elite",
}

-- Build list of all valid keys for Rayfield gate
local ALL_KEYS = {}
for k in pairs(KEYS) do
    table.insert(ALL_KEYS, k)
end

-- Load saved tier from our own file
pcall(function()
    if isfile and isfile(TIER_FILE) then
        local data = readfile(TIER_FILE):gsub("%s+", "")
        if data == "Elite" or data == "Premium" then
            UserTier = data
        end
    end
end)

-- Save tier to file
local function SaveTier()
    pcall(function()
        if writefile then
            writefile(TIER_FILE, UserTier)
        end
    end)
end

-- Activate a key (only upgrades, never downgrades)
local function ActivateKey(key)
    key = key:gsub("%s+", "")
    local tier = KEYS[key]
    if tier then
        if tier == "Elite" then
            UserTier = "Elite"
            SaveTier()
            return true
        elseif tier == "Premium" and UserTier ~= "Elite" then
            UserTier = "Premium"
            SaveTier()
            return true
        elseif tier == "Free" then
            return true
        end
    end
    return false
end

-- Tier check helpers
local function IsPremium()
    return UserTier == "Premium" or UserTier == "Elite"
end

local function IsElite()
    return UserTier == "Elite"
end

-- ═══════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════
local ESP = {
    Enabled = false,
    ShowNames = true,
    ShowDistance = true,
    ShowHealth = true,
    ShowBox = true,
    ShowTracers = false,
    TeamCheck = false,
    MaxDistance = 1000,
    Color = Color3.fromRGB(0, 255, 170),
    Objects = {}
}

local Aim = {
    Enabled = false,
    Holding = false,
    TeamCheck = false,
    FOV = 150,
    Smoothness = 0.5,
    TargetPart = "Head",
    ShowFOV = true,
    LockedTarget = nil,
    WallCheck = false,
    MaxYDiff = 50
}

local Char = {
    SpeedEnabled = false,
    SpeedValue = 16,
    FlyEnabled = false,
    FlySpeed = 50,
    NoclipEnabled = false,
    InfJumpEnabled = false
}

local SelectedPlayer = nil
local Connections = {}

-- ═══════════════════════════════════════════
-- FOV CIRCLE
-- ═══════════════════════════════════════════
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1.5
FOVCircle.NumSides = 80
FOVCircle.Filled = false
FOVCircle.Visible = false
FOVCircle.Transparency = 0.8
FOVCircle.Color = Color3.fromRGB(255, 255, 255)
FOVCircle.Radius = Aim.FOV

-- ═══════════════════════════════════════════
-- KEY LINK COPY BUTTON (shows on key screen)
-- ═══════════════════════════════════════════
local KeyLinkGui = Instance.new("ScreenGui")
KeyLinkGui.Name = "NovaKeyLink"
KeyLinkGui.ResetOnSpawn = false
KeyLinkGui.DisplayOrder = 999
KeyLinkGui.Parent = game:GetService("CoreGui")

local CopyBtn = Instance.new("TextButton")
CopyBtn.Size = UDim2.new(0, 220, 0, 45)
CopyBtn.Position = UDim2.new(0.5, -110, 0.55, 0)
CopyBtn.BackgroundColor3 = Color3.fromRGB(30, 120, 255)
CopyBtn.TextColor3 = Color3.new(1, 1, 1)
CopyBtn.Text = "📋  Copy Key Link"
CopyBtn.TextSize = 16
CopyBtn.Font = Enum.Font.GothamBold
CopyBtn.AutoButtonColor = true
CopyBtn.Parent = KeyLinkGui

local CopyCorner = Instance.new("UICorner")
CopyCorner.CornerRadius = UDim.new(0, 8)
CopyCorner.Parent = CopyBtn

local CopyStroke = Instance.new("UIStroke")
CopyStroke.Color = Color3.fromRGB(60, 150, 255)
CopyStroke.Thickness = 1.5
CopyStroke.Parent = CopyBtn

CopyBtn.MouseButton1Click:Connect(function()
    if setclipboard then
        setclipboard("https://direct-link.net/2303175/rUZPiU7veMCB")
        CopyBtn.Text = "✅  Copied!"
        CopyBtn.BackgroundColor3 = Color3.fromRGB(30, 180, 60)
        task.wait(1.5)
        CopyBtn.Text = "📋  Copy Key Link"
        CopyBtn.BackgroundColor3 = Color3.fromRGB(30, 120, 255)
    end
end)

-- Auto-destroy after 2 minutes if key screen is still open
task.spawn(function()
    task.wait(120)
    pcall(function() KeyLinkGui:Destroy() end)
end)

-- ═══════════════════════════════════════════
-- RAYFIELD WINDOW
-- ═══════════════════════════════════════════
local Window = Rayfield:CreateWindow({
    Name = "⚡ Nova",
    LoadingTitle = "Nova",
    LoadingSubtitle = "Loading...",
    Theme = "Ocean",
    DisableRayFieldPrompts = false,
    DisableBuildWarnings = false,

    KeySystem = true,
    KeySettings = {
        Title = "Nova - Authorization Required",
        Subtitle = "Enter your license key to unlock Nova",
        Note = "Get your key:\nhttps://direct-link.net/2303175/rUZPiU7veMCB",
        FileName = "NovaKey",
        SaveKey = true,
        GrabKeyFromSite = false,
        Key = ALL_KEYS
    },

    ConfigurationSaving = {
        Enabled = true,
        FolderName = "NovaConfigs",
        FileName = "NovaSettings"
    }
})

-- Key accepted - remove copy button
pcall(function() KeyLinkGui:Destroy() end)

-- ═══════════════════════════════════════════
-- UTILITIES
-- ═══════════════════════════════════════════
local function Notify(title, content, duration)
    Rayfield:Notify({
        Title = title,
        Content = content,
        Duration = duration or 3,
        Image = 4483362458
    })
end

local function TierLock(required)
    if required == "Premium" and not IsPremium() then
        Notify("Nova", "💎 Premium feature! Go to Settings → Activate Key to unlock.", 4)
        return true
    end
    if required == "Elite" and not IsElite() then
        Notify("Nova", "👑 Elite feature! Go to Settings → Activate Key to unlock.", 4)
        return true
    end
    return false
end

local function IsAlive(player)
    if not player then return false end
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return false end
    return hum.Health > 0
end

local function GetPlayerByName(name)
    for _, player in pairs(Players:GetPlayers()) do
        if string.lower(player.Name):find(string.lower(name)) or
           string.lower(player.DisplayName):find(string.lower(name)) then
            return player
        end
    end
    return nil
end

local function GetPlayerNames()
    local names = {}
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(names, player.DisplayName .. " (" .. player.Name .. ")")
        end
    end
    if #names == 0 then
        table.insert(names, "No players")
    end
    return names
end

-- Resolve target part with R6/R15 support
local function ResolveTargetPart(character, partName)
    if not character then return nil end

    -- Direct match first
    local direct = character:FindFirstChild(partName)
    if direct then return direct end

    -- R6 / R15 fallback mapping
    local mapping = {
        ["Head"] = {"Head"},
        ["Torso"] = {"UpperTorso", "Torso"},
        ["HumanoidRootPart"] = {"HumanoidRootPart"},
        ["Left Arm"] = {"LeftUpperArm", "Left Arm"},
        ["Right Arm"] = {"RightUpperArm", "Right Arm"},
        ["Left Leg"] = {"LeftUpperLeg", "Left Leg"},
        ["Right Leg"] = {"RightUpperLeg", "Right Leg"},
        ["Left Foot"] = {"LeftFoot", "Left Leg"},
        ["Right Foot"] = {"RightFoot", "Right Leg"},
    }

    local alts = mapping[partName]
    if alts then
        for _, alt in ipairs(alts) do
            local part = character:FindFirstChild(alt)
            if part then return part end
        end
    end

    -- Last resort: head
    return character:FindFirstChild("Head")
end

-- Wall visibility check using Raycast
local function IsVisible(targetPart)
    if not Aim.WallCheck then return true end

    local origin = Camera.CFrame.Position
    local direction = (targetPart.Position - origin)

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character, targetPart.Parent}

    local result = Workspace:Raycast(origin, direction, rayParams)
    return result == nil
end

-- ═══════════════════════════════════════════
-- ESP SYSTEM
-- ═══════════════════════════════════════════
local function NewDraw(kind, props)
    local d = Drawing.new(kind)
    for k, v in pairs(props) do
        d[k] = v
    end
    return d
end

local function CreateESP(player)
    if player == LocalPlayer then return end

    -- Clean up old ESP if it exists
    if ESP.Objects[player] then
        for _, d in pairs(ESP.Objects[player]) do
            pcall(function() d:Remove() end)
        end
    end

    ESP.Objects[player] = {
        BoxOutline = NewDraw("Square", {
            Thickness = 3, Filled = false,
            Color = Color3.new(0, 0, 0),
            Transparency = 0.5, Visible = false
        }),
        Box = NewDraw("Square", {
            Thickness = 1.5, Filled = false,
            Color = ESP.Color,
            Transparency = 1, Visible = false
        }),
        Name = NewDraw("Text", {
            Size = 14, Center = true, Outline = true,
            Color = Color3.new(1, 1, 1),
            Font = 2, Visible = false
        }),
        Distance = NewDraw("Text", {
            Size = 13, Center = true, Outline = true,
            Color = Color3.fromRGB(200, 200, 200),
            Font = 2, Visible = false
        }),
        HealthBG = NewDraw("Line", {
            Thickness = 3,
            Color = Color3.fromRGB(40, 40, 40),
            Transparency = 0.7, Visible = false
        }),
        HealthBar = NewDraw("Line", {
            Thickness = 1.5,
            Transparency = 1, Visible = false
        }),
        HealthText = NewDraw("Text", {
            Size = 12, Center = false, Outline = true,
            Color = Color3.new(1, 1, 1),
            Font = 2, Visible = false
        }),
        Tracer = NewDraw("Line", {
            Thickness = 1.5,
            Color = ESP.Color,
            Transparency = 0.7, Visible = false
        }),
    }
end

local function RemoveESP(player)
    if ESP.Objects[player] then
        for _, d in pairs(ESP.Objects[player]) do
            pcall(function() d:Remove() end)
        end
        ESP.Objects[player] = nil
    end
end

local function HideESP(data)
    for _, d in pairs(data) do
        d.Visible = false
    end
end

local function RenderESP()
    for player, data in pairs(ESP.Objects) do
        -- Basic visibility checks
        if not ESP.Enabled or not player or not player.Parent then
            HideESP(data)
            continue
        end

        if not IsAlive(player) then
            HideESP(data)
            continue
        end

        -- Team check
        if ESP.TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
            HideESP(data)
            continue
        end

        -- Get character parts
        local char = player.Character
        local root = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")
        local hum = char:FindFirstChildOfClass("Humanoid")

        if not root or not head or not hum then
            HideESP(data)
            continue
        end

        -- Screen position and distance
        local rootPos, onScreen = Camera:WorldToViewportPoint(root.Position)
        local dist = (root.Position - Camera.CFrame.Position).Magnitude

        if not onScreen or dist > ESP.MaxDistance then
            HideESP(data)
            continue
        end

        -- Calculate bounding box
        local topPos = Camera:WorldToViewportPoint((head.CFrame * CFrame.new(0, 0.5, 0)).Position)
        local bottomPos = Camera:WorldToViewportPoint((root.CFrame * CFrame.new(0, -3, 0)).Position)

        local boxH = math.abs(bottomPos.Y - topPos.Y)
        local boxW = boxH * 0.6
        local boxX = rootPos.X - boxW / 2
        local boxY = topPos.Y

        -- Box ESP (Free)
        if ESP.ShowBox then
            data.BoxOutline.Size = Vector2.new(boxW, boxH)
            data.BoxOutline.Position = Vector2.new(boxX, boxY)
            data.BoxOutline.Visible = true

            data.Box.Size = Vector2.new(boxW, boxH)
            data.Box.Position = Vector2.new(boxX, boxY)
            data.Box.Color = ESP.Color
            data.Box.Visible = true
        else
            data.Box.Visible = false
            data.BoxOutline.Visible = false
        end

        -- Name ESP (Free)
        if ESP.ShowNames then
            data.Name.Text = player.DisplayName
            data.Name.Position = Vector2.new(rootPos.X, boxY - 16)
            data.Name.Visible = true
        else
            data.Name.Visible = false
        end

        -- Distance ESP (Free)
        if ESP.ShowDistance then
            data.Distance.Text = "[" .. math.floor(dist) .. "m]"
            data.Distance.Position = Vector2.new(rootPos.X, boxY + boxH + 2)
            data.Distance.Visible = true
        else
            data.Distance.Visible = false
        end

        -- Health Bar ESP (Premium+)
        if ESP.ShowHealth and IsPremium() then
            local hp = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            local barX = boxX - 5

            data.HealthBG.From = Vector2.new(barX, boxY)
            data.HealthBG.To = Vector2.new(barX, boxY + boxH)
            data.HealthBG.Visible = true

            local barTop = boxY + boxH * (1 - hp)
            data.HealthBar.From = Vector2.new(barX, barTop)
            data.HealthBar.To = Vector2.new(barX, boxY + boxH)
            data.HealthBar.Color = Color3.fromRGB(255 * (1 - hp), 255 * hp, 0)
            data.HealthBar.Visible = true

            data.HealthText.Text = math.floor(hum.Health)
            data.HealthText.Position = Vector2.new(barX - 8, barTop - 7)
            data.HealthText.Visible = hp < 1
        else
            data.HealthBG.Visible = false
            data.HealthBar.Visible = false
            data.HealthText.Visible = false
        end

        -- Tracers (Premium+)
        if ESP.ShowTracers and IsPremium() then
            data.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
            data.Tracer.To = Vector2.new(rootPos.X, boxY + boxH)
            data.Tracer.Color = ESP.Color
            data.Tracer.Visible = true
        else
            data.Tracer.Visible = false
        end
    end
end

-- ═══════════════════════════════════════════
-- AIM LOCK SYSTEM (FREE - BindToRenderStep)
--
-- Uses BindToRenderStep at priority 301 which
-- runs AFTER Roblox's camera controller (200).
-- Roblox updates camera first, then we override
-- the rotation to point at the target. Weapons
-- stay visible, camera stays normal.
-- ═══════════════════════════════════════════
local AIM_BIND = "NovaAimLock"
local aimBound = false

local function GetClosestInFOV()
    local closest = nil
    local closestDist = Aim.FOV
    local center = UserInputService:GetMouseLocation()

    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if not IsAlive(player) then continue end

        -- Team check
        if Aim.TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
            continue
        end

        local char = player.Character
        local part = ResolveTargetPart(char, Aim.TargetPart)
        if not part then continue end

        -- Screen position check
        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end

        -- Wall check (Elite)
        if Aim.WallCheck and not IsVisible(part) then continue end

        -- Height check (ignore players way below/above)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local yDiff = math.abs(part.Position.Y - LocalPlayer.Character.HumanoidRootPart.Position.Y)
            if yDiff > Aim.MaxYDiff then continue end
        end

        -- Distance from mouse
        local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
        if dist < closestDist then
            closestDist = dist
            closest = player
        end
    end

    return closest
end

local function AimStep()
    if not Aim.Enabled or not Aim.Holding then return end

    -- Find target if we don't have one locked
    if not Aim.LockedTarget or not IsAlive(Aim.LockedTarget) then
        Aim.LockedTarget = GetClosestInFOV()
    end

    if not Aim.LockedTarget then return end

    -- Validate target still exists
    local char = Aim.LockedTarget.Character
    if not char then
        Aim.LockedTarget = nil
        return
    end

    local part = ResolveTargetPart(char, Aim.TargetPart)
    if not part then
        Aim.LockedTarget = nil
        return
    end

    -- Wall check on locked target
    if Aim.WallCheck and not IsVisible(part) then
        Aim.LockedTarget = nil
        return
    end

    -- Height check on locked target
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local yDiff = math.abs(part.Position.Y - LocalPlayer.Character.HumanoidRootPart.Position.Y)
        if yDiff > Aim.MaxYDiff then
            Aim.LockedTarget = nil
            return
        end
    end

    -- Lock camera to target with smoothness
    local camPos = Camera.CFrame.Position
    local targetCF = CFrame.lookAt(camPos, part.Position)
    Camera.CFrame = Camera.CFrame:Lerp(targetCF, Aim.Smoothness)
end

local function StartAim()
    if aimBound then return end
    -- Priority 301 = runs AFTER Roblox camera controller (200)
    RunService:BindToRenderStep(AIM_BIND, 301, AimStep)
    aimBound = true
end

local function StopAim()
    if not aimBound then return end
    RunService:UnbindFromRenderStep(AIM_BIND)
    aimBound = false
end

-- ═══════════════════════════════════════════
-- TAB 1: ESP
-- ═══════════════════════════════════════════
local ESPTab = Window:CreateTab("ESP", 4483362458)

ESPTab:CreateSection("ESP Controls (Free)")

ESPTab:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = false,
    Flag = "ESPToggle",
    Callback = function(v)
        ESP.Enabled = v
        if v then
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and not ESP.Objects[p] then
                    CreateESP(p)
                end
            end
            Notify("Nova", "ESP Enabled", 2)
        else
            for _, data in pairs(ESP.Objects) do
                HideESP(data)
            end
            Notify("Nova", "ESP Disabled", 2)
        end
    end
})

ESPTab:CreateToggle({
    Name = "Boxes",
    CurrentValue = true,
    Flag = "ESPBox",
    Callback = function(v) ESP.ShowBox = v end
})

ESPTab:CreateToggle({
    Name = "Names",
    CurrentValue = true,
    Flag = "ESPNames",
    Callback = function(v) ESP.ShowNames = v end
})

ESPTab:CreateToggle({
    Name = "Distance",
    CurrentValue = true,
    Flag = "ESPDist",
    Callback = function(v) ESP.ShowDistance = v end
})

ESPTab:CreateToggle({
    Name = "Team Check",
    CurrentValue = false,
    Flag = "ESPTeam",
    Callback = function(v) ESP.TeamCheck = v end
})

ESPTab:CreateSlider({
    Name = "Max Distance",
    Range = {100, 5000},
    Increment = 50,
    Suffix = " studs",
    CurrentValue = 1000,
    Flag = "ESPMaxDist",
    Callback = function(v) ESP.MaxDistance = v end
})

ESPTab:CreateSection("Premium ESP 💎")

ESPTab:CreateToggle({
    Name = "Health Bars 💎",
    CurrentValue = true,
    Flag = "ESPHealth",
    Callback = function(v)
        if TierLock("Premium") then return end
        ESP.ShowHealth = v
    end
})

ESPTab:CreateToggle({
    Name = "Tracers 💎",
    CurrentValue = false,
    Flag = "ESPTracers",
    Callback = function(v)
        if TierLock("Premium") then return end
        ESP.ShowTracers = v
    end
})

ESPTab:CreateColorPicker({
    Name = "ESP Color 💎",
    Color = Color3.fromRGB(0, 255, 170),
    Flag = "ESPColor",
    Callback = function(v)
        if TierLock("Premium") then return end
        ESP.Color = v
    end
})

-- ═══════════════════════════════════════════
-- TAB 2: AIM LOCK (FREE)
-- ═══════════════════════════════════════════
local AimTab = Window:CreateTab("Aim Lock", 4483362458)

AimTab:CreateSection("Aim Lock (Free)")

AimTab:CreateToggle({
    Name = "Enable Aim Lock",
    CurrentValue = false,
    Flag = "AimToggle",
    Callback = function(v)
        Aim.Enabled = v
        FOVCircle.Visible = v and Aim.ShowFOV
        if v then
            StartAim()
            Notify("Nova", "Aim Lock ON (Hold RMB)", 2)
        else
            Aim.Holding = false
            Aim.LockedTarget = nil
            StopAim()
            Notify("Nova", "Aim Lock OFF", 2)
        end
    end
})

AimTab:CreateToggle({
    Name = "Team Check",
    CurrentValue = false,
    Flag = "AimTeam",
    Callback = function(v) Aim.TeamCheck = v end
})

AimTab:CreateToggle({
    Name = "Show FOV Circle",
    CurrentValue = true,
    Flag = "ShowFOV",
    Callback = function(v)
        Aim.ShowFOV = v
        FOVCircle.Visible = v and Aim.Enabled
    end
})

AimTab:CreateSection("Tuning")

AimTab:CreateSlider({
    Name = "FOV Radius",
    Range = {50, 500},
    Increment = 10,
    Suffix = " px",
    CurrentValue = 150,
    Flag = "AimFOV",
    Callback = function(v)
        Aim.FOV = v
        FOVCircle.Radius = v
    end
})

AimTab:CreateSlider({
    Name = "Lock Speed",
    Range = {1, 100},
    Increment = 1,
    Suffix = "%",
    CurrentValue = 50,
    Flag = "AimSmooth",
    Callback = function(v) Aim.Smoothness = v / 100 end
})

AimTab:CreateSlider({
    Name = "Max Height Diff",
    Range = {10, 200},
    Increment = 5,
    Suffix = " studs",
    CurrentValue = 50,
    Flag = "AimMaxY",
    Callback = function(v) Aim.MaxYDiff = v end
})

AimTab:CreateSection("Target Part")

AimTab:CreateDropdown({
    Name = "Lock To",
    Options = {
        "Head", "Torso", "HumanoidRootPart",
        "Left Arm", "Right Arm",
        "Left Leg", "Right Leg",
        "Left Foot", "Right Foot"
    },
    CurrentOption = {"Head"},
    MultiOption = false,
    Flag = "AimPart",
    Callback = function(v)
        local part = type(v) == "table" and v[1] or v

        -- Limb targeting is Elite only
        local eliteParts = {
            ["Left Arm"] = true, ["Right Arm"] = true,
            ["Left Leg"] = true, ["Right Leg"] = true,
            ["Left Foot"] = true, ["Right Foot"] = true
        }

        if eliteParts[part] and not IsElite() then
            Notify("Nova", "👑 Limb targeting requires Elite tier!", 3)
            return
        end

        Aim.TargetPart = part
        Notify("Nova", "Locking to: " .. part, 2)
    end
})

AimTab:CreateSection("Elite Features 👑")

AimTab:CreateToggle({
    Name = "Wall Check 👑",
    CurrentValue = false,
    Flag = "WallCheck",
    Callback = function(v)
        if TierLock("Elite") then return end
        Aim.WallCheck = v
        Notify("Nova", v and "Won't lock through walls" or "Locks through walls", 2)
    end
})

AimTab:CreateColorPicker({
    Name = "FOV Circle Color 👑",
    Color = Color3.fromRGB(255, 255, 255),
    Flag = "FOVColor",
    Callback = function(v)
        if TierLock("Elite") then return end
        FOVCircle.Color = v
    end
})

-- ═══════════════════════════════════════════
-- TAB 3: PLAYERS (Premium)
-- ═══════════════════════════════════════════
local PlayerTab = Window:CreateTab("Players 💎", 4483362458)

PlayerTab:CreateSection("Player Management (Premium)")

local PlayerDropdown = PlayerTab:CreateDropdown({
    Name = "Select Player",
    Options = GetPlayerNames(),
    CurrentOption = {},
    MultiOption = false,
    Flag = "SelPlayer",
    Callback = function(v)
        local name = type(v) == "table" and v[1] or v
        local username = string.match(name, "%((.+)%)")
        if username then
            SelectedPlayer = GetPlayerByName(username)
        end
    end
})

PlayerTab:CreateButton({
    Name = "🔄 Refresh Player List",
    Callback = function()
        PlayerDropdown:Set(GetPlayerNames())
        Notify("Nova", "Refreshed", 2)
    end
})

PlayerTab:CreateButton({
    Name = "📍 Teleport to Player 💎",
    Callback = function()
        if TierLock("Premium") then return end
        if SelectedPlayer and IsAlive(SelectedPlayer) and IsAlive(LocalPlayer) then
            LocalPlayer.Character.HumanoidRootPart.CFrame =
                SelectedPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 5)
            Notify("Nova", "Teleported to " .. SelectedPlayer.DisplayName, 2)
        else
            Notify("Nova", "No valid player selected", 2)
        end
    end
})

PlayerTab:CreateButton({
    Name = "👀 Spectate Player 💎",
    Callback = function()
        if TierLock("Premium") then return end
        if SelectedPlayer and SelectedPlayer.Character then
            local hum = SelectedPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                Camera.CameraSubject = hum
                Notify("Nova", "Spectating " .. SelectedPlayer.DisplayName, 2)
            end
        else
            Notify("Nova", "No valid player selected", 2)
        end
    end
})

PlayerTab:CreateButton({
    Name = "🔙 Stop Spectating",
    Callback = function()
        if LocalPlayer.Character then
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                Camera.CameraSubject = hum
                Notify("Nova", "Back to self", 2)
            end
        end
    end
})

PlayerTab:CreateButton({
    Name = "📋 Copy Player Info 💎",
    Callback = function()
        if TierLock("Premium") then return end
        if SelectedPlayer and setclipboard then
            setclipboard(string.format(
                "Name: %s | Display: %s | ID: %d | Age: %d days",
                SelectedPlayer.Name,
                SelectedPlayer.DisplayName,
                SelectedPlayer.UserId,
                SelectedPlayer.AccountAge
            ))
            Notify("Nova", "Copied to clipboard", 2)
        end
    end
})

-- ═══════════════════════════════════════════
-- TAB 4: CHARACTER
-- ═══════════════════════════════════════════
local CharTab = Window:CreateTab("Character", 4483362458)

CharTab:CreateSection("Movement (Free)")

CharTab:CreateToggle({
    Name = "Speed Hack",
    CurrentValue = false,
    Flag = "SpeedToggle",
    Callback = function(v)
        Char.SpeedEnabled = v
        if not v and LocalPlayer.Character then
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = 16 end
        end
        Notify("Nova", v and ("Speed: " .. Char.SpeedValue) or "Speed reset", 2)
    end
})

CharTab:CreateSlider({
    Name = "Walk Speed",
    Range = {16, 200},
    Increment = 1,
    Suffix = "",
    CurrentValue = 16,
    Flag = "WalkSpeed",
    Callback = function(v) Char.SpeedValue = v end
})

CharTab:CreateSlider({
    Name = "Jump Power",
    Range = {50, 300},
    Increment = 5,
    Suffix = "",
    CurrentValue = 50,
    Flag = "JumpPower",
    Callback = function(v)
        if LocalPlayer.Character then
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.UseJumpPower = true
                hum.JumpPower = v
            end
        end
    end
})

CharTab:CreateSection("Premium Movement 💎")

CharTab:CreateToggle({
    Name = "Fly 💎",
    CurrentValue = false,
    Flag = "FlyToggle",
    Callback = function(v)
        if TierLock("Premium") then return end
        Char.FlyEnabled = v
        if not v and LocalPlayer.Character then
            local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local bv = root:FindFirstChild("NovaFlyBV")
                local bg = root:FindFirstChild("NovaFlyBG")
                if bv then bv:Destroy() end
                if bg then bg:Destroy() end
            end
        end
        Notify("Nova", v and "Fly ON (WASD + Space/Shift)" or "Fly OFF", 2)
    end
})

CharTab:CreateSlider({
    Name = "Fly Speed",
    Range = {10, 200},
    Increment = 5,
    Suffix = "",
    CurrentValue = 50,
    Flag = "FlySpeed",
    Callback = function(v) Char.FlySpeed = v end
})

CharTab:CreateToggle({
    Name = "Noclip 💎",
    CurrentValue = false,
    Flag = "Noclip",
    Callback = function(v)
        if TierLock("Premium") then return end
        Char.NoclipEnabled = v
        Notify("Nova", v and "Noclip ON" or "Noclip OFF", 2)
    end
})

CharTab:CreateSection("Elite Movement 👑")

CharTab:CreateToggle({
    Name = "Infinite Jump 👑",
    CurrentValue = false,
    Flag = "InfJump",
    Callback = function(v)
        if TierLock("Elite") then return end
        Char.InfJumpEnabled = v
        Notify("Nova", v and "Infinite Jump ON" or "Infinite Jump OFF", 2)
    end
})

CharTab:CreateSection("Other")

CharTab:CreateButton({
    Name = "💀 Reset Character",
    Callback = function()
        if LocalPlayer.Character then
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.Health = 0 end
        end
    end
})

-- ═══════════════════════════════════════════
-- TAB 5: VISUALS
-- ═══════════════════════════════════════════
local VisualsTab = Window:CreateTab("Visuals", 4483362458)

VisualsTab:CreateSection("Lighting (Free)")

VisualsTab:CreateToggle({
    Name = "Fullbright",
    CurrentValue = false,
    Flag = "Fullbright",
    Callback = function(v)
        if v then
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.FogEnd = 100000
            Lighting.GlobalShadows = false
            Lighting.Ambient = Color3.fromRGB(178, 178, 178)
        else
            Lighting.Brightness = 1
            Lighting.FogEnd = 10000
            Lighting.GlobalShadows = true
            Lighting.Ambient = Color3.fromRGB(0, 0, 0)
        end
        Notify("Nova", v and "Fullbright ON" or "Fullbright OFF", 2)
    end
})

VisualsTab:CreateSlider({
    Name = "Field of View",
    Range = {30, 120},
    Increment = 1,
    Suffix = "°",
    CurrentValue = 70,
    Flag = "CamFOV",
    Callback = function(v) Camera.FieldOfView = v end
})

VisualsTab:CreateSlider({
    Name = "Time of Day",
    Range = {0, 24},
    Increment = 0.5,
    Suffix = "h",
    CurrentValue = 14,
    Flag = "TimeOfDay",
    Callback = function(v) Lighting.ClockTime = v end
})

VisualsTab:CreateSlider({
    Name = "Fog Distance",
    Range = {0, 100000},
    Increment = 1000,
    Suffix = " studs",
    CurrentValue = 10000,
    Flag = "FogDist",
    Callback = function(v) Lighting.FogEnd = v end
})

VisualsTab:CreateSection("World (Free)")

VisualsTab:CreateButton({
    Name = "🌈 Remove Post-Processing",
    Callback = function()
        local c = 0
        for _, fx in pairs(Lighting:GetChildren()) do
            if fx:IsA("Atmosphere") or fx:IsA("BloomEffect") or
               fx:IsA("BlurEffect") or fx:IsA("ColorCorrectionEffect") then
                fx:Destroy()
                c = c + 1
            end
        end
        Notify("Nova", "Removed " .. c .. " effects", 2)
    end
})

VisualsTab:CreateButton({
    Name = "🗑️ Remove Invisible Walls",
    Callback = function()
        local c = 0
        for _, part in pairs(Workspace:GetDescendants()) do
            if part:IsA("BasePart") and part.Transparency >= 0.9 and part.CanCollide then
                part.CanCollide = false
                c = c + 1
            end
        end
        Notify("Nova", "Removed " .. c .. " invisible walls", 2)
    end
})

-- ═══════════════════════════════════════════
-- TAB 6: SERVER
-- ═══════════════════════════════════════════
local ServerTab = Window:CreateTab("Server", 4483362458)

ServerTab:CreateSection("Server Info")

ServerTab:CreateParagraph({
    Title = "Server Info",
    Content = string.format(
        "Players: %d/%d\nGame ID: %d\nPlace Version: %d\nJob ID: %s",
        #Players:GetPlayers(),
        Players.MaxPlayers,
        game.PlaceId,
        game.PlaceVersion,
        game.JobId
    )
})

ServerTab:CreateSection("Server Actions")

ServerTab:CreateButton({
    Name = "📋 Copy Rejoin Link",
    Callback = function()
        if setclipboard then
            setclipboard("roblox://experiences/start?placeId=" .. game.PlaceId .. "&gameInstanceId=" .. game.JobId)
            Notify("Nova", "Server link copied", 2)
        end
    end
})

ServerTab:CreateButton({
    Name = "🔄 Rejoin Server",
    Callback = function()
        Notify("Nova", "Rejoining...", 1)
        task.wait(0.5)
        game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end
})

ServerTab:CreateButton({
    Name = "🆕 Join New Server",
    Callback = function()
        Notify("Nova", "Joining new server...", 1)
        task.wait(0.5)
        game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
    end
})

-- ═══════════════════════════════════════════
-- TAB 7: SETTINGS
-- ═══════════════════════════════════════════
local SettingsTab = Window:CreateTab("Settings", 4483362458)

-- Tier display
local tierEmoji = IsElite() and "👑" or (IsPremium() and "💎" or "🆓")

SettingsTab:CreateSection("Current Tier: " .. tierEmoji .. " " .. UserTier)

SettingsTab:CreateParagraph({
    Title = "Your Features",
    Content = IsElite() and "✅ All features unlocked! Thank you for your support!" or
              IsPremium() and "✅ Premium unlocked!\nUpgrade to Elite for: Wall Check, Inf Jump, Limb Targeting, Config Save" or
              "🆓 Free tier active\nUpgrade to Premium for: Health ESP, Tracers, Fly, Noclip, Player Tools\nUpgrade to Elite for everything!"
})

-- Key activation
SettingsTab:CreateSection("⚡ Activate Key")

SettingsTab:CreateParagraph({
    Title = "How to Upgrade",
    Content = "Paste your Premium or Elite key below and press Enter.\nYour tier saves permanently - you only need to do this once!"
})

SettingsTab:CreateInput({
    Name = "Enter Key Here",
    PlaceholderText = "Paste your upgrade key here...",
    RemoveTextAfterFocusLost = true,
    Flag = "TierKeyInput",
    Callback = function(text)
        if ActivateKey(text) then
            local e = IsElite() and "👑 Elite" or (IsPremium() and "💎 Premium" or "🆓 Free")
            Notify("Nova", "✅ " .. e .. " activated! Features unlocked instantly.", 5)
            print("[Nova] Tier upgraded to: " .. UserTier)
        else
            Notify("Nova", "❌ Invalid key. Check your key and try again.", 3)
        end
    end
})

-- Key link
SettingsTab:CreateSection("Key Link")

SettingsTab:CreateButton({
    Name = "📋 Copy Key Link",
    Callback = function()
        if setclipboard then
            setclipboard("https://direct-link.net/2303175/rUZPiU7veMCB")
            Notify("Nova", "Key link copied to clipboard!", 2)
        end
    end
})

-- Config saving (Elite)
SettingsTab:CreateSection("Config Saving (Elite 👑)")

SettingsTab:CreateButton({
    Name = "💾 Save Config 👑",
    Callback = function()
        if TierLock("Elite") then return end
        pcall(function() Rayfield:SaveConfiguration() end)
        Notify("Nova", "Config saved!", 2)
    end
})

SettingsTab:CreateButton({
    Name = "📂 Load Config 👑",
    Callback = function()
        if TierLock("Elite") then return end
        pcall(function() Rayfield:LoadConfiguration() end)
        Notify("Nova", "Config loaded!", 2)
    end
})

-- Hub settings
SettingsTab:CreateSection("Hub Settings")

SettingsTab:CreateKeybind({
    Name = "Toggle UI",
    CurrentKeybind = "RightControl",
    Flag = "UIToggle",
    Callback = function() end
})

SettingsTab:CreateButton({
    Name = "🗑️ Destroy Nova",
    Callback = function()
        StopAim()
        for p in pairs(ESP.Objects) do RemoveESP(p) end
        pcall(function() FOVCircle:Remove() end)
        for _, c in pairs(Connections) do
            pcall(function() c:Disconnect() end)
        end
        Rayfield:Destroy()
    end
})

SettingsTab:CreateParagraph({
    Title = "Nova v2.2",
    Content = "Built by Heath\nPowered by Rayfield UI\n\nRightCtrl = Toggle UI\nHold RMB = Lock Aim (Free)\n\n🆓 Free → ESP, Aim Lock, Speed, Visuals\n💎 Premium → + Health, Tracers, Fly, Noclip\n👑 Elite → + Wall Check, Inf Jump, Config"
})

-- ═══════════════════════════════════════════
-- MAIN LOOPS
-- ═══════════════════════════════════════════

-- Render: ESP + FOV Circle
Connections.Render = RunService.RenderStepped:Connect(function()
    -- FOV circle follows mouse (hidden while locked)
    if Aim.Enabled and Aim.ShowFOV and not Aim.Holding then
        FOVCircle.Position = UserInputService:GetMouseLocation()
        FOVCircle.Radius = Aim.FOV
        FOVCircle.Visible = true
    else
        FOVCircle.Visible = false
    end

    -- Render ESP
    RenderESP()
end)

-- HOLD RMB to lock, RELEASE to unlock
Connections.AimDown = UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        if Aim.Enabled then
            Aim.Holding = true
            Aim.LockedTarget = nil -- Re-acquire fresh target
        end
    end
end)

Connections.AimUp = UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        Aim.Holding = false
        Aim.LockedTarget = nil
    end
end)

-- Noclip (Premium+)
Connections.Noclip = RunService.Stepped:Connect(function()
    if Char.NoclipEnabled and IsPremium() and LocalPlayer.Character then
        for _, p in pairs(LocalPlayer.Character:GetDescendants()) do
            if p:IsA("BasePart") then
                p.CanCollide = false
            end
        end
    end
end)

-- Speed + Fly
Connections.Heartbeat = RunService.Heartbeat:Connect(function()
    -- Speed hack (Free)
    if Char.SpeedEnabled and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = Char.SpeedValue end
    end

    -- Fly system (Premium+)
    if Char.FlyEnabled and IsPremium() and LocalPlayer.Character then
        local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then
            -- Create BodyVelocity if needed
            local bv = root:FindFirstChild("NovaFlyBV")
            local bg = root:FindFirstChild("NovaFlyBG")

            if not bv then
                bv = Instance.new("BodyVelocity")
                bv.Name = "NovaFlyBV"
                bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bv.Velocity = Vector3.zero
                bv.Parent = root
            end

            if not bg then
                bg = Instance.new("BodyGyro")
                bg.Name = "NovaFlyBG"
                bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                bg.P = 9e4
                bg.Parent = root
            end

            -- Calculate fly direction from input
            local dir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end

            bv.Velocity = dir * Char.FlySpeed
            bg.CFrame = Camera.CFrame
        end
    end
end)

-- Infinite Jump (Elite)
Connections.InfJump = UserInputService.JumpRequest:Connect(function()
    if Char.InfJumpEnabled and IsElite() and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- ESP: Player join/leave + respawn handling
Connections.Join = Players.PlayerAdded:Connect(function(player)
    if ESP.Enabled then
        CreateESP(player)
    end
    player.CharacterAdded:Connect(function()
        task.wait(1)
        if ESP.Enabled then
            CreateESP(player)
        end
    end)
end)

Connections.Leave = Players.PlayerRemoving:Connect(function(player)
    RemoveESP(player)
    if Aim.LockedTarget == player then
        Aim.LockedTarget = nil
    end
end)

-- Init ESP for all current players
for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        CreateESP(player)
        player.CharacterAdded:Connect(function()
            task.wait(1)
            if ESP.Enabled then
                CreateESP(player)
            end
        end)
    end
end

-- Re-apply settings on local respawn
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    if Char.SpeedEnabled then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = Char.SpeedValue end
    end
end)

-- Start aim bind (checks Aim.Enabled internally)
StartAim()

-- ═══════════════════════════════════════════
-- STARTUP
-- ═══════════════════════════════════════════
Notify("Nova", tierEmoji .. " " .. UserTier .. " tier loaded! RightCtrl to toggle UI.", 5)

-- Prompt free users to upgrade
if UserTier == "Free" then
    task.wait(3)
    Notify("Nova", "💡 Have a Premium/Elite key? Go to Settings → Activate Key!", 8)
end

print([[
╔══════════════════════════════════════════════════╗
║               NOVA v2.2 LOADED                   ║
║                                                  ║
║  🆓 Free:    ESP, Aim Lock, Speed, Visuals       ║
║  💎 Premium: + Health, Tracers, Fly, Noclip      ║
║  👑 Elite:   + Wall Check, Inf Jump, Config      ║
║                                                  ║
║  RightCtrl = UI | Hold RMB = Lock Aim            ║
╚══════════════════════════════════════════════════╝
]])
print("[Nova] Tier: " .. UserTier)
