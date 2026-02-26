--[[
    ╔══════════════════════════════════════════════════╗
    ║                 NOVA v2.0                        ║
    ║         Built with Rayfield UI Library           ║
    ║        For use in YOUR OWN game only             ║
    ╚══════════════════════════════════════════════════╝
    
    TIERS:
    Free    → Basic ESP (boxes, names, distance), Speed, Jump, Fullbright, Server Tools
    Premium → Full ESP (health, tracers, color), Aim Lock, Fly, Noclip, Player Tools
    Elite   → Everything + Infinite Jump, Wall Check, All Target Parts, Config Save
    
    HOLD RMB = Lock aim (Premium+)
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
-- KEY TIER DETECTION
-- ═══════════════════════════════════════════
local FREE_KEYS = {"HQHDRTAMNDSOSUI9HSL78BAJRKLIUASLOP"}
local PREMIUM_KEYS = {"NOVA-PREMIUM-VIP"}
local ELITE_KEYS = {"NOVA-LIFETIME-ELITE"}

local ALL_KEYS = {}
for _, k in ipairs(FREE_KEYS) do table.insert(ALL_KEYS, k) end
for _, k in ipairs(PREMIUM_KEYS) do table.insert(ALL_KEYS, k) end
for _, k in ipairs(ELITE_KEYS) do table.insert(ALL_KEYS, k) end

-- Try to read saved key to detect tier
local UserTier = "Free"

local function DetectTier()
    -- Check multiple possible paths where Rayfield saves keys
    local possiblePaths = {
        "NovaKey.txt",
        "Rayfield/NovaKey.txt",
        "RayfieldKey/NovaKey.txt",
        "Rayfield/Keys/NovaKey.txt",
    }

    local savedKey = nil

    for _, path in ipairs(possiblePaths) do
        local success, result = pcall(function()
            if isfile and isfile(path) then
                return readfile(path)
            end
            return nil
        end)
        if success and result and result ~= "" then
            savedKey = result
            break
        end
    end

    -- Also try listing files to find it
    if not savedKey then
        pcall(function()
            if isfile and isfile("NovaKey.txt") then
                savedKey = readfile("NovaKey.txt")
            end
        end)
    end

    if savedKey then
        -- Strip whitespace, newlines, quotes
        savedKey = savedKey:gsub("%s+", ""):gsub('"', ""):gsub("'", "")

        for _, k in ipairs(ELITE_KEYS) do
            if savedKey:find(k, 1, true) then UserTier = "Elite"; return end
        end
        for _, k in ipairs(PREMIUM_KEYS) do
            if savedKey:find(k, 1, true) then UserTier = "Premium"; return end
        end
        for _, k in ipairs(FREE_KEYS) do
            if savedKey:find(k, 1, true) then UserTier = "Free"; return end
        end
    end
end

-- Also detect based on which key the user just entered this session
local function DetectTierFromInput(inputKey)
    if not inputKey then return end
    inputKey = inputKey:gsub("%s+", "")
    for _, k in ipairs(ELITE_KEYS) do
        if inputKey == k then UserTier = "Elite"; return end
    end
    for _, k in ipairs(PREMIUM_KEYS) do
        if inputKey == k then UserTier = "Premium"; return end
    end
    for _, k in ipairs(FREE_KEYS) do
        if inputKey == k then UserTier = "Free"; return end
    end
end

DetectTier()

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
KeyLinkGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
KeyLinkGui.DisplayOrder = 999
KeyLinkGui.Parent = game:GetService("CoreGui")

local CopyButton = Instance.new("TextButton")
CopyButton.Size = UDim2.new(0, 220, 0, 45)
CopyButton.Position = UDim2.new(0.5, -110, 0.55, 0)
CopyButton.BackgroundColor3 = Color3.fromRGB(30, 120, 255)
CopyButton.TextColor3 = Color3.new(1, 1, 1)
CopyButton.Text = "📋  Copy Key Link"
CopyButton.TextSize = 16
CopyButton.Font = Enum.Font.GothamBold
CopyButton.Parent = KeyLinkGui
CopyButton.AutoButtonColor = true

local CopyCorner = Instance.new("UICorner")
CopyCorner.CornerRadius = UDim.new(0, 8)
CopyCorner.Parent = CopyButton

local CopyStroke = Instance.new("UIStroke")
CopyStroke.Color = Color3.fromRGB(60, 150, 255)
CopyStroke.Thickness = 1.5
CopyStroke.Parent = CopyButton

CopyButton.MouseButton1Click:Connect(function()
    if setclipboard then
        setclipboard("https://direct-link.net/2303175/rUZPiU7veMCB")
        CopyButton.Text = "✅  Copied!"
        CopyButton.BackgroundColor3 = Color3.fromRGB(30, 180, 60)
        task.wait(1.5)
        CopyButton.Text = "📋  Copy Key Link"
        CopyButton.BackgroundColor3 = Color3.fromRGB(30, 120, 255)
    end
end)

task.spawn(function()
    task.wait(120)
    if KeyLinkGui and KeyLinkGui.Parent then
        KeyLinkGui:Destroy()
    end
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
        Note = "Copy this link to get your key:\nhttps://direct-link.net/2303175/rUZPiU7veMCB\n\nFree & Premium tiers available\nKeys save automatically - enter once, play forever",
        FileName = "NovaKey",
        SaveKey = true,
        GrabKeyFromSite = false,
        Key = ALL_KEYS
    },

    -- Config saving (Elite feature, but we save for all - Elite gets load)
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "NovaConfigs",
        FileName = "NovaSettings"
    }
})

-- Key accepted, remove the copy button and detect tier
if KeyLinkGui and KeyLinkGui.Parent then
    KeyLinkGui:Destroy()
end

-- Aggressively detect tier after key is accepted
DetectTier()

-- If still Free, brute force search every .txt file for elite/premium keys
if UserTier == "Free" then
    pcall(function()
        if listfiles then
            local function searchFolder(folder)
                local files = listfiles(folder)
                for _, file in ipairs(files) do
                    if file:find("Nova") and file:find(".txt") then
                        local content = readfile(file)
                        if content then
                            DetectTierFromInput(content:gsub("%s+", ""):gsub('"', ""))
                            if UserTier ~= "Free" then return end
                        end
                    end
                end
            end
            pcall(function() searchFolder(".") end)
            pcall(function() searchFolder("Rayfield") end)
            pcall(function() searchFolder("RayfieldKey") end)
        end
    end)
end

-- Last resort: if we STILL can't detect, check the workspace folder
if UserTier == "Free" then
    pcall(function()
        if isfolder and isfolder("Rayfield") and listfiles then
            for _, file in ipairs(listfiles("Rayfield")) do
                if file:find("Key") or file:find("Nova") then
                    local content = readfile(file)
                    if content then
                        DetectTierFromInput(content:gsub("%s+", ""):gsub('"', ""))
                    end
                end
            end
        end
    end)
end

-- Give Rayfield a moment to save, then try one more time
if UserTier == "Free" then
    task.wait(1)
    DetectTier()
end

-- Debug: print detected tier
print("[Nova] Detected tier: " .. UserTier)

-- ═══════════════════════════════════════════
-- UTILITIES
-- ═══════════════════════════════════════════
local function Notify(title, content, duration)
    Rayfield:Notify({Title = title, Content = content, Duration = duration or 3, Image = 4483362458})
end

local function TierLock(requiredTier)
    if requiredTier == "Premium" and not IsPremium() then
        Notify("Nova", "⚠️ Premium feature! Upgrade your key to unlock.", 3)
        return true
    end
    if requiredTier == "Elite" and not IsElite() then
        Notify("Nova", "👑 Elite feature! Upgrade to Elite to unlock.", 3)
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
    for _, p in pairs(Players:GetPlayers()) do
        if string.lower(p.Name):find(string.lower(name)) or
           string.lower(p.DisplayName):find(string.lower(name)) then
            return p
        end
    end
    return nil
end

local function GetPlayerNames()
    local names = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(names, p.DisplayName .. " (" .. p.Name .. ")")
        end
    end
    if #names == 0 then table.insert(names, "No players") end
    return names
end

local function ResolveTargetPart(character, partName)
    if not character then return nil end
    local direct = character:FindFirstChild(partName)
    if direct then return direct end
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
    return character:FindFirstChild("Head")
end

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
    for k, v in pairs(props) do d[k] = v end
    return d
end

local function CreateESP(player)
    if player == LocalPlayer then return end
    if ESP.Objects[player] then
        for _, d in pairs(ESP.Objects[player]) do pcall(function() d:Remove() end) end
    end
    ESP.Objects[player] = {
        BoxOutline = NewDraw("Square", {Thickness = 3, Filled = false, Color = Color3.new(0,0,0), Transparency = 0.5, Visible = false}),
        Box = NewDraw("Square", {Thickness = 1.5, Filled = false, Color = ESP.Color, Transparency = 1, Visible = false}),
        Name = NewDraw("Text", {Size = 14, Center = true, Outline = true, Color = Color3.new(1,1,1), Font = 2, Visible = false}),
        Distance = NewDraw("Text", {Size = 13, Center = true, Outline = true, Color = Color3.fromRGB(200,200,200), Font = 2, Visible = false}),
        HealthBG = NewDraw("Line", {Thickness = 3, Color = Color3.fromRGB(40,40,40), Transparency = 0.7, Visible = false}),
        HealthBar = NewDraw("Line", {Thickness = 1.5, Transparency = 1, Visible = false}),
        HealthText = NewDraw("Text", {Size = 12, Center = false, Outline = true, Color = Color3.new(1,1,1), Font = 2, Visible = false}),
        Tracer = NewDraw("Line", {Thickness = 1.5, Color = ESP.Color, Transparency = 0.7, Visible = false}),
    }
end

local function RemoveESP(player)
    if ESP.Objects[player] then
        for _, d in pairs(ESP.Objects[player]) do pcall(function() d:Remove() end) end
        ESP.Objects[player] = nil
    end
end

local function HideESP(data)
    for _, d in pairs(data) do d.Visible = false end
end

local function RenderESP()
    for player, data in pairs(ESP.Objects) do
        if not ESP.Enabled or not player or not player.Parent then HideESP(data); continue end
        if not IsAlive(player) then HideESP(data); continue end
        if ESP.TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
            HideESP(data); continue
        end

        local char = player.Character
        local root = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not root or not head or not hum then HideESP(data); continue end

        local rootPos, onScreen = Camera:WorldToViewportPoint(root.Position)
        local dist = (root.Position - Camera.CFrame.Position).Magnitude
        if not onScreen or dist > ESP.MaxDistance then HideESP(data); continue end

        local topPos = Camera:WorldToViewportPoint((head.CFrame * CFrame.new(0, 0.5, 0)).Position)
        local bottomPos = Camera:WorldToViewportPoint((root.CFrame * CFrame.new(0, -3, 0)).Position)
        local boxH = math.abs(bottomPos.Y - topPos.Y)
        local boxW = boxH * 0.6
        local boxX = rootPos.X - boxW / 2
        local boxY = topPos.Y

        -- Boxes (Free)
        if ESP.ShowBox then
            data.BoxOutline.Size = Vector2.new(boxW, boxH)
            data.BoxOutline.Position = Vector2.new(boxX, boxY)
            data.BoxOutline.Visible = true
            data.Box.Size = Vector2.new(boxW, boxH)
            data.Box.Position = Vector2.new(boxX, boxY)
            data.Box.Color = ESP.Color
            data.Box.Visible = true
        else data.Box.Visible = false; data.BoxOutline.Visible = false end

        -- Names (Free)
        if ESP.ShowNames then
            data.Name.Text = player.DisplayName
            data.Name.Position = Vector2.new(rootPos.X, boxY - 16)
            data.Name.Visible = true
        else data.Name.Visible = false end

        -- Distance (Free)
        if ESP.ShowDistance then
            data.Distance.Text = "[" .. math.floor(dist) .. "m]"
            data.Distance.Position = Vector2.new(rootPos.X, boxY + boxH + 2)
            data.Distance.Visible = true
        else data.Distance.Visible = false end

        -- Health (Premium+)
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
            data.HealthBG.Visible = false; data.HealthBar.Visible = false; data.HealthText.Visible = false
        end

        -- Tracers (Premium+)
        if ESP.ShowTracers and IsPremium() then
            data.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
            data.Tracer.To = Vector2.new(rootPos.X, boxY + boxH)
            data.Tracer.Color = ESP.Color
            data.Tracer.Visible = true
        else data.Tracer.Visible = false end
    end
end

-- ═══════════════════════════════════════════
-- AIM LOCK SYSTEM (Premium+)
-- ═══════════════════════════════════════════
local AIM_BIND_NAME = "NovaAimLock"
local isAimBound = false

local function GetClosestPlayerInFOV()
    local closest = nil
    local closestDist = Aim.FOV
    local center = UserInputService:GetMouseLocation()

    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if not IsAlive(player) then continue end
        if Aim.TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then continue end

        local char = player.Character
        local part = ResolveTargetPart(char, Aim.TargetPart)
        if not part then continue end

        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end

        if Aim.WallCheck and not IsVisible(part) then continue end

        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local yDiff = math.abs(part.Position.Y - LocalPlayer.Character.HumanoidRootPart.Position.Y)
            if yDiff > Aim.MaxYDiff then continue end
        end

        local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
        if dist < closestDist then
            closestDist = dist
            closest = player
        end
    end
    return closest
end

local function AimLockStep()
    if not Aim.Enabled or not Aim.Holding or not IsPremium() then return end

    if not Aim.LockedTarget or not IsAlive(Aim.LockedTarget) then
        Aim.LockedTarget = GetClosestPlayerInFOV()
    end
    if not Aim.LockedTarget then return end

    local char = Aim.LockedTarget.Character
    if not char then Aim.LockedTarget = nil; return end

    local part = ResolveTargetPart(char, Aim.TargetPart)
    if not part then Aim.LockedTarget = nil; return end

    if Aim.WallCheck and not IsVisible(part) then
        Aim.LockedTarget = nil; return
    end

    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local yDiff = math.abs(part.Position.Y - LocalPlayer.Character.HumanoidRootPart.Position.Y)
        if yDiff > Aim.MaxYDiff then
            Aim.LockedTarget = nil; return
        end
    end

    local camPos = Camera.CFrame.Position
    local targetCF = CFrame.lookAt(camPos, part.Position)
    Camera.CFrame = Camera.CFrame:Lerp(targetCF, Aim.Smoothness)
end

local function StartAimBind()
    if isAimBound then return end
    RunService:BindToRenderStep(AIM_BIND_NAME, 301, AimLockStep)
    isAimBound = true
end

local function StopAimBind()
    if not isAimBound then return end
    RunService:UnbindFromRenderStep(AIM_BIND_NAME)
    isAimBound = false
end

-- ═══════════════════════════════════════════
-- TAB 1: ESP
-- ═══════════════════════════════════════════
local ESPTab = Window:CreateTab("ESP", 4483362458)
ESPTab:CreateSection("ESP Controls (Free)")

ESPTab:CreateToggle({
    Name = "Enable ESP", CurrentValue = false, Flag = "ESPToggle",
    Callback = function(v)
        ESP.Enabled = v
        if v then
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and not ESP.Objects[p] then CreateESP(p) end
            end
            Notify("Nova", "ESP Enabled", 2)
        else
            for _, data in pairs(ESP.Objects) do HideESP(data) end
            Notify("Nova", "ESP Disabled", 2)
        end
    end
})
ESPTab:CreateToggle({Name = "Boxes", CurrentValue = true, Flag = "ESPBox", Callback = function(v) ESP.ShowBox = v end})
ESPTab:CreateToggle({Name = "Names", CurrentValue = true, Flag = "ESPNames", Callback = function(v) ESP.ShowNames = v end})
ESPTab:CreateToggle({Name = "Distance", CurrentValue = true, Flag = "ESPDist", Callback = function(v) ESP.ShowDistance = v end})
ESPTab:CreateToggle({Name = "Team Check", CurrentValue = false, Flag = "ESPTeam", Callback = function(v) ESP.TeamCheck = v end})
ESPTab:CreateSlider({
    Name = "Max Distance", Range = {100, 5000}, Increment = 50, Suffix = " studs",
    CurrentValue = 1000, Flag = "ESPMaxDist", Callback = function(v) ESP.MaxDistance = v end
})

ESPTab:CreateSection("ESP Premium Features 💎")

ESPTab:CreateToggle({Name = "Health Bars 💎", CurrentValue = true, Flag = "ESPHealth",
    Callback = function(v)
        if TierLock("Premium") then return end
        ESP.ShowHealth = v
    end
})
ESPTab:CreateToggle({Name = "Tracers 💎", CurrentValue = false, Flag = "ESPTracers",
    Callback = function(v)
        if TierLock("Premium") then return end
        ESP.ShowTracers = v
    end
})
ESPTab:CreateColorPicker({Name = "ESP Color 💎", Color = Color3.fromRGB(0, 255, 170), Flag = "ESPColor",
    Callback = function(v)
        if TierLock("Premium") then return end
        ESP.Color = v
    end
})

-- ═══════════════════════════════════════════
-- TAB 2: AIM LOCK (Premium+)
-- ═══════════════════════════════════════════
local AimTab = Window:CreateTab("Aim Lock 💎", 4483362458)
AimTab:CreateSection("Aim Lock (Premium)")

AimTab:CreateToggle({
    Name = "Enable Aim Lock 💎", CurrentValue = false, Flag = "AimToggle",
    Callback = function(v)
        if TierLock("Premium") then return end
        Aim.Enabled = v
        FOVCircle.Visible = v and Aim.ShowFOV
        if v then
            StartAimBind()
            Notify("Nova", "Aim Lock ON (Hold RMB)", 2)
        else
            Aim.Holding = false; Aim.LockedTarget = nil
            StopAimBind()
            Notify("Nova", "Aim Lock OFF", 2)
        end
    end
})

AimTab:CreateToggle({Name = "Team Check", CurrentValue = false, Flag = "AimTeam",
    Callback = function(v) Aim.TeamCheck = v end})

AimTab:CreateToggle({Name = "Show FOV Circle", CurrentValue = true, Flag = "ShowFOV",
    Callback = function(v)
        Aim.ShowFOV = v
        FOVCircle.Visible = v and Aim.Enabled
    end
})

AimTab:CreateSection("Tuning")

AimTab:CreateSlider({Name = "FOV Radius", Range = {50, 500}, Increment = 10, Suffix = " px",
    CurrentValue = 150, Flag = "AimFOV",
    Callback = function(v) Aim.FOV = v; FOVCircle.Radius = v end})

AimTab:CreateSlider({Name = "Lock Speed", Range = {1, 100}, Increment = 1, Suffix = "%",
    CurrentValue = 50, Flag = "AimSmooth",
    Callback = function(v) Aim.Smoothness = v / 100 end})

AimTab:CreateSlider({Name = "Max Height Diff", Range = {10, 200}, Increment = 5, Suffix = " studs",
    CurrentValue = 50, Flag = "AimMaxY",
    Callback = function(v) Aim.MaxYDiff = v end})

AimTab:CreateSection("Target Part")

AimTab:CreateDropdown({
    Name = "Lock To (Head/Torso = Free, rest = Elite 👑)",
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
        local eliteParts = {["Left Arm"]=true,["Right Arm"]=true,["Left Leg"]=true,["Right Leg"]=true,["Left Foot"]=true,["Right Foot"]=true}
        if eliteParts[part] and not IsElite() then
            Notify("Nova", "👑 Elite feature! Limb targeting requires Elite tier.", 3)
            return
        end
        Aim.TargetPart = part
        Notify("Nova", "Locking to: " .. part, 2)
    end
})

AimTab:CreateSection("Elite Features 👑")

AimTab:CreateToggle({Name = "Wall Check 👑", CurrentValue = false, Flag = "WallCheck",
    Callback = function(v)
        if TierLock("Elite") then return end
        Aim.WallCheck = v
        Notify("Nova", v and "Won't lock through walls" or "Locks through walls", 2)
    end
})

AimTab:CreateColorPicker({Name = "FOV Circle Color 👑", Color = Color3.fromRGB(255, 255, 255), Flag = "FOVColor",
    Callback = function(v)
        if TierLock("Elite") then return end
        FOVCircle.Color = v
    end
})

-- ═══════════════════════════════════════════
-- TAB 3: PLAYERS (Premium+)
-- ═══════════════════════════════════════════
local PlayerTab = Window:CreateTab("Players 💎", 4483362458)
PlayerTab:CreateSection("Player Management (Premium)")

local PlayerDropdown = PlayerTab:CreateDropdown({
    Name = "Select Player", Options = GetPlayerNames(), CurrentOption = {},
    MultiOption = false, Flag = "SelPlayer",
    Callback = function(v)
        local name = type(v) == "table" and v[1] or v
        local username = string.match(name, "%((.+)%)")
        if username then SelectedPlayer = GetPlayerByName(username) end
    end
})
PlayerTab:CreateButton({Name = "Refresh Player List", Callback = function()
    PlayerDropdown:Set(GetPlayerNames()); Notify("Nova", "Refreshed", 2)
end})
PlayerTab:CreateButton({Name = "Teleport to Player 💎", Callback = function()
    if TierLock("Premium") then return end
    if SelectedPlayer and IsAlive(SelectedPlayer) and IsAlive(LocalPlayer) then
        LocalPlayer.Character.HumanoidRootPart.CFrame = SelectedPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 5)
        Notify("Nova", "Teleported to " .. SelectedPlayer.DisplayName, 2)
    else Notify("Nova", "No valid player", 2) end
end})
PlayerTab:CreateButton({Name = "Spectate Player 💎", Callback = function()
    if TierLock("Premium") then return end
    if SelectedPlayer and SelectedPlayer.Character then
        local hum = SelectedPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then Camera.CameraSubject = hum; Notify("Nova", "Spectating " .. SelectedPlayer.DisplayName, 2) end
    end
end})
PlayerTab:CreateButton({Name = "Stop Spectating", Callback = function()
    if LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then Camera.CameraSubject = hum; Notify("Nova", "Back to self", 2) end
    end
end})
PlayerTab:CreateButton({Name = "Copy Player Info 💎", Callback = function()
    if TierLock("Premium") then return end
    if SelectedPlayer and setclipboard then
        setclipboard(string.format("Name: %s | Display: %s | ID: %d | Age: %d days",
            SelectedPlayer.Name, SelectedPlayer.DisplayName, SelectedPlayer.UserId, SelectedPlayer.AccountAge))
        Notify("Nova", "Copied", 2)
    end
end})

-- ═══════════════════════════════════════════
-- TAB 4: CHARACTER
-- ═══════════════════════════════════════════
local CharTab = Window:CreateTab("Character", 4483362458)
CharTab:CreateSection("Movement (Free)")

CharTab:CreateToggle({
    Name = "Speed Hack", CurrentValue = false, Flag = "SpeedToggle",
    Callback = function(v)
        Char.SpeedEnabled = v
        if not v and LocalPlayer.Character then
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = 16 end
        end
        Notify("Nova", v and ("Speed: " .. Char.SpeedValue) or "Speed reset", 2)
    end
})
CharTab:CreateSlider({Name = "Walk Speed", Range = {16, 200}, Increment = 1, Suffix = "",
    CurrentValue = 16, Flag = "WalkSpeed", Callback = function(v) Char.SpeedValue = v end})
CharTab:CreateSlider({Name = "Jump Power", Range = {50, 300}, Increment = 5, Suffix = "",
    CurrentValue = 50, Flag = "JumpPower",
    Callback = function(v)
        if LocalPlayer.Character then
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.UseJumpPower = true; hum.JumpPower = v end
        end
    end
})

CharTab:CreateSection("Premium Movement 💎")

CharTab:CreateToggle({Name = "Fly 💎", CurrentValue = false, Flag = "FlyToggle",
    Callback = function(v)
        if TierLock("Premium") then return end
        Char.FlyEnabled = v
        if not v and LocalPlayer.Character then
            local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local bv = root:FindFirstChild("NovaFlyBV"); if bv then bv:Destroy() end
                local bg = root:FindFirstChild("NovaFlyBG"); if bg then bg:Destroy() end
            end
        end
        Notify("Nova", v and "Fly ON (WASD+Space/Shift)" or "Fly OFF", 2)
    end
})
CharTab:CreateSlider({Name = "Fly Speed", Range = {10, 200}, Increment = 5, Suffix = "",
    CurrentValue = 50, Flag = "FlySpeed", Callback = function(v) Char.FlySpeed = v end})

CharTab:CreateToggle({Name = "Noclip 💎", CurrentValue = false, Flag = "Noclip",
    Callback = function(v)
        if TierLock("Premium") then return end
        Char.NoclipEnabled = v; Notify("Nova", v and "Noclip ON" or "Noclip OFF", 2)
    end
})

CharTab:CreateSection("Elite Movement 👑")

CharTab:CreateToggle({Name = "Infinite Jump 👑", CurrentValue = false, Flag = "InfJump",
    Callback = function(v)
        if TierLock("Elite") then return end
        Char.InfJumpEnabled = v; Notify("Nova", v and "Inf Jump ON" or "Inf Jump OFF", 2)
    end
})

CharTab:CreateSection("Other")
CharTab:CreateButton({Name = "Reset Character", Callback = function()
    if LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = 0 end
    end
end})

-- ═══════════════════════════════════════════
-- TAB 5: VISUALS
-- ═══════════════════════════════════════════
local VisualsTab = Window:CreateTab("Visuals", 4483362458)
VisualsTab:CreateSection("Lighting (Free)")

VisualsTab:CreateToggle({Name = "Fullbright", CurrentValue = false, Flag = "Fullbright",
    Callback = function(v)
        if v then
            Lighting.Brightness = 2; Lighting.ClockTime = 14; Lighting.FogEnd = 100000
            Lighting.GlobalShadows = false; Lighting.Ambient = Color3.fromRGB(178,178,178)
        else
            Lighting.Brightness = 1; Lighting.FogEnd = 10000
            Lighting.GlobalShadows = true; Lighting.Ambient = Color3.fromRGB(0,0,0)
        end
    end
})
VisualsTab:CreateSlider({Name = "Field of View", Range = {30, 120}, Increment = 1, Suffix = "°",
    CurrentValue = 70, Flag = "CamFOV", Callback = function(v) Camera.FieldOfView = v end})
VisualsTab:CreateSlider({Name = "Time of Day", Range = {0, 24}, Increment = 0.5, Suffix = "h",
    CurrentValue = 14, Flag = "TimeOfDay", Callback = function(v) Lighting.ClockTime = v end})
VisualsTab:CreateSlider({Name = "Fog Distance", Range = {0, 100000}, Increment = 1000, Suffix = " studs",
    CurrentValue = 10000, Flag = "FogDist", Callback = function(v) Lighting.FogEnd = v end})

VisualsTab:CreateSection("World (Free)")
VisualsTab:CreateButton({Name = "Remove Post-Processing", Callback = function()
    local c = 0
    for _, fx in pairs(Lighting:GetChildren()) do
        if fx:IsA("Atmosphere") or fx:IsA("BloomEffect") or fx:IsA("BlurEffect") or fx:IsA("ColorCorrectionEffect") then
            fx:Destroy(); c = c + 1
        end
    end
    Notify("Nova", "Removed " .. c .. " effects", 2)
end})
VisualsTab:CreateButton({Name = "Remove Invisible Walls", Callback = function()
    local c = 0
    for _, part in pairs(Workspace:GetDescendants()) do
        if part:IsA("BasePart") and part.Transparency >= 0.9 and part.CanCollide then
            part.CanCollide = false; c = c + 1
        end
    end
    Notify("Nova", "Removed " .. c .. " walls", 2)
end})

-- ═══════════════════════════════════════════
-- TAB 6: SERVER
-- ═══════════════════════════════════════════
local ServerTab = Window:CreateTab("Server", 4483362458)
ServerTab:CreateSection("Info (Free)")
ServerTab:CreateParagraph({Title = "Server Info",
    Content = string.format("Players: %d/%d\nGame ID: %d\nVersion: %d",
        #Players:GetPlayers(), Players.MaxPlayers, game.PlaceId, game.PlaceVersion)})
ServerTab:CreateSection("Actions (Free)")
ServerTab:CreateButton({Name = "Copy Server Link", Callback = function()
    if setclipboard then
        setclipboard("roblox://experiences/start?placeId=" .. game.PlaceId .. "&gameInstanceId=" .. game.JobId)
        Notify("Nova", "Copied", 2)
    end
end})
ServerTab:CreateButton({Name = "Rejoin Server", Callback = function()
    task.wait(0.5); game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end})
ServerTab:CreateButton({Name = "Join New Server", Callback = function()
    task.wait(0.5); game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
end})

-- ═══════════════════════════════════════════
-- TAB 7: SETTINGS
-- ═══════════════════════════════════════════
local SettingsTab = Window:CreateTab("Settings", 4483362458)

SettingsTab:CreateSection("Your Tier")
local tierEmoji = UserTier == "Elite" and "👑" or (UserTier == "Premium" and "💎" or "🆓")
SettingsTab:CreateParagraph({Title = tierEmoji .. " " .. UserTier .. " Tier",
    Content = UserTier == "Free" and "Basic ESP, Speed, Jump, Fullbright, Server Tools\nUpgrade to Premium for Aim Lock, Fly, Tracers & more!" or
              UserTier == "Premium" and "Full ESP, Aim Lock, Fly, Noclip, Player Tools\nUpgrade to Elite for Wall Check, Inf Jump, Limb Targeting!" or
              "All features unlocked. Thank you for your support!"
})

SettingsTab:CreateSection("Key System")
SettingsTab:CreateButton({Name = "📋 Copy Key Link", Callback = function()
    if setclipboard then
        setclipboard("https://direct-link.net/2303175/rUZPiU7veMCB")
        Notify("Nova", "Key link copied!", 2)
    end
end})

SettingsTab:CreateButton({Name = "🔄 Re-Verify Tier", Callback = function()
    DetectTier()
    local tierEmoji2 = UserTier == "Elite" and "👑" or (UserTier == "Premium" and "💎" or "🆓")
    Notify("Nova", tierEmoji2 .. " Detected: " .. UserTier .. " tier. Rejoin if incorrect.", 4)
end})

SettingsTab:CreateDropdown({
    Name = "Manual Tier Override (if auto-detect fails)",
    Options = {"Free", "Premium", "Elite"},
    CurrentOption = {UserTier},
    MultiOption = false,
    Flag = "TierOverride",
    Callback = function(v)
        local pick = type(v) == "table" and v[1] or v
        -- Verify they actually have the right key before allowing override
        local savedKey = nil
        pcall(function()
            local paths = {"NovaKey.txt", "Rayfield/NovaKey.txt", "RayfieldKey/NovaKey.txt"}
            for _, p in ipairs(paths) do
                if isfile and isfile(p) then savedKey = readfile(p):gsub("%s+",""):gsub('"',""); break end
            end
        end)

        local valid = false
        if pick == "Elite" then
            for _, k in ipairs(ELITE_KEYS) do if savedKey and savedKey:find(k, 1, true) then valid = true end end
        elseif pick == "Premium" then
            for _, k in ipairs(PREMIUM_KEYS) do if savedKey and savedKey:find(k, 1, true) then valid = true end end
            if not valid then
                for _, k in ipairs(ELITE_KEYS) do if savedKey and savedKey:find(k, 1, true) then valid = true end end
            end
        else
            valid = true
        end

        if valid then
            UserTier = pick
            local e = UserTier == "Elite" and "👑" or (UserTier == "Premium" and "💎" or "🆓")
            Notify("Nova", e .. " Tier set to " .. UserTier .. "! All features updated.", 3)
        else
            Notify("Nova", "⚠️ Your saved key doesn't match " .. pick .. " tier.", 3)
        end
    end
})

SettingsTab:CreateSection("Config (Elite 👑)")
SettingsTab:CreateButton({Name = "💾 Save Config 👑", Callback = function()
    if TierLock("Elite") then return end
    pcall(function()
        Rayfield:SaveConfiguration()
    end)
    Notify("Nova", "Config saved!", 2)
end})

SettingsTab:CreateButton({Name = "📂 Load Config 👑", Callback = function()
    if TierLock("Elite") then return end
    pcall(function()
        Rayfield:LoadConfiguration()
    end)
    Notify("Nova", "Config loaded!", 2)
end})

SettingsTab:CreateSection("Hub Settings")
SettingsTab:CreateKeybind({Name = "Toggle UI", CurrentKeybind = "RightControl", Flag = "UIToggle", Callback = function() end})
SettingsTab:CreateButton({Name = "Destroy Nova", Callback = function()
    StopAimBind()
    for p in pairs(ESP.Objects) do RemoveESP(p) end
    pcall(function() FOVCircle:Remove() end)
    for _, c in pairs(Connections) do pcall(function() c:Disconnect() end) end
    Rayfield:Destroy()
end})
SettingsTab:CreateParagraph({Title = "Nova v2.0",
    Content = "Built by Heath\nPowered by Rayfield UI\n\nRightCtrl = Toggle UI\nHold RMB = Lock Aim (Premium+)"})

-- ═══════════════════════════════════════════
-- MAIN LOOPS
-- ═══════════════════════════════════════════
Connections.Render = RunService.RenderStepped:Connect(function()
    if Aim.Enabled and Aim.ShowFOV and not Aim.Holding then
        FOVCircle.Position = UserInputService:GetMouseLocation()
        FOVCircle.Radius = Aim.FOV
        FOVCircle.Visible = true
    else
        FOVCircle.Visible = false
    end
    RenderESP()
end)

Connections.AimDown = UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        if Aim.Enabled and IsPremium() then
            Aim.Holding = true
            Aim.LockedTarget = nil
        end
    end
end)
Connections.AimUp = UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        Aim.Holding = false
        Aim.LockedTarget = nil
    end
end)

Connections.Noclip = RunService.Stepped:Connect(function()
    if Char.NoclipEnabled and IsPremium() and LocalPlayer.Character then
        for _, p in pairs(LocalPlayer.Character:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end
end)

Connections.Heartbeat = RunService.Heartbeat:Connect(function()
    if Char.SpeedEnabled and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = Char.SpeedValue end
    end
    if Char.FlyEnabled and IsPremium() and LocalPlayer.Character then
        local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then
            local bv = root:FindFirstChild("NovaFlyBV")
            local bg = root:FindFirstChild("NovaFlyBG")
            if not bv then
                bv = Instance.new("BodyVelocity"); bv.Name = "NovaFlyBV"
                bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bv.Velocity = Vector3.zero; bv.Parent = root
            end
            if not bg then
                bg = Instance.new("BodyGyro"); bg.Name = "NovaFlyBG"
                bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                bg.P = 9e4; bg.Parent = root
            end
            local dir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0,1,0) end
            bv.Velocity = dir * Char.FlySpeed
            bg.CFrame = Camera.CFrame
        end
    end
end)

Connections.InfJump = UserInputService.JumpRequest:Connect(function()
    if Char.InfJumpEnabled and IsElite() and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

Connections.Join = Players.PlayerAdded:Connect(function(player)
    if ESP.Enabled then CreateESP(player) end
    player.CharacterAdded:Connect(function()
        task.wait(1); if ESP.Enabled then CreateESP(player) end
    end)
end)
Connections.Leave = Players.PlayerRemoving:Connect(function(player)
    RemoveESP(player)
    if Aim.LockedTarget == player then Aim.LockedTarget = nil; Aim.Holding = false end
end)

for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        CreateESP(player)
        player.CharacterAdded:Connect(function()
            task.wait(1); if ESP.Enabled then CreateESP(player) end
        end)
    end
end

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    if Char.SpeedEnabled then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = Char.SpeedValue end
    end
end)

StartAimBind()

-- ═══════════════════════════════════════════
Notify("Nova", tierEmoji .. " " .. UserTier .. " tier loaded! RightCtrl = UI", 5)
print([[
╔══════════════════════════════════════════════════╗
║               NOVA v2.0 LOADED                   ║
║                                                  ║
║  🆓 Free:    ESP, Speed, Jump, Visuals, Server   ║
║  💎 Premium: + Aim Lock, Fly, Noclip, Players    ║
║  👑 Elite:   + Wall Check, Inf Jump, Config Save  ║
║                                                  ║
║  RightCtrl = UI | Hold RMB = Lock (Premium+)     ║
╚══════════════════════════════════════════════════╝
]])
