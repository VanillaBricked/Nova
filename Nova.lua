--[[
    ╔══════════════════════════════════════════════════╗
    ║                 NOVA v1.5                        ║
    ║         Built with Rayfield UI Library           ║
    ║        For use in YOUR OWN game only             ║
    ╚══════════════════════════════════════════════════╝
    
    HOLD RMB = Lock aim to nearest player
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
    WallCheck = false
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
CopyButton.Position = UDim2.new(0.5, -110, 0.75, 0)
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

-- Destroy the button after a delay (key screen is gone by then)
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
        Key = {
            "HQHDRTAMNDSOSUI9HSL78BAJRKLIUASLOP",
            "NOVA-PREMIUM-VIP",
            "NOVA-LIFETIME-ELITE"
        }
    }
})

-- Key accepted, remove the copy button
if KeyLinkGui and KeyLinkGui.Parent then
    KeyLinkGui:Destroy()
end

-- ═══════════════════════════════════════════
-- UTILITIES
-- ═══════════════════════════════════════════
local function Notify(title, content, duration)
    Rayfield:Notify({Title = title, Content = content, Duration = duration or 3, Image = 4483362458})
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

        if ESP.ShowBox then
            data.BoxOutline.Size = Vector2.new(boxW, boxH)
            data.BoxOutline.Position = Vector2.new(boxX, boxY)
            data.BoxOutline.Visible = true
            data.Box.Size = Vector2.new(boxW, boxH)
            data.Box.Position = Vector2.new(boxX, boxY)
            data.Box.Color = ESP.Color
            data.Box.Visible = true
        else data.Box.Visible = false; data.BoxOutline.Visible = false end

        if ESP.ShowNames then
            data.Name.Text = player.DisplayName
            data.Name.Position = Vector2.new(rootPos.X, boxY - 16)
            data.Name.Visible = true
        else data.Name.Visible = false end

        if ESP.ShowDistance then
            data.Distance.Text = "[" .. math.floor(dist) .. "m]"
            data.Distance.Position = Vector2.new(rootPos.X, boxY + boxH + 2)
            data.Distance.Visible = true
        else data.Distance.Visible = false end

        if ESP.ShowHealth then
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

        if ESP.ShowTracers then
            data.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
            data.Tracer.To = Vector2.new(rootPos.X, boxY + boxH)
            data.Tracer.Color = ESP.Color
            data.Tracer.Visible = true
        else data.Tracer.Visible = false end
    end
end

-- ═══════════════════════════════════════════
-- AIM LOCK SYSTEM (FIXED - BindToRenderStep)
--
-- THE FIX: Instead of mousemoverel (which has
-- sensitivity issues) or Scriptable camera (which
-- hides weapons), we use BindToRenderStep with
-- priority 301 (AFTER Roblox's camera at 200).
-- This lets Roblox do its normal camera thing,
-- THEN we override the rotation to face the target.
-- Weapons stay visible. Camera stays normal.
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

        local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
        if dist < closestDist then
            closestDist = dist
            closest = player
        end
    end
    return closest
end

local function AimLockStep()
    if not Aim.Enabled or not Aim.Holding then return end

    -- Find target if needed
    if not Aim.LockedTarget or not IsAlive(Aim.LockedTarget) then
        Aim.LockedTarget = GetClosestPlayerInFOV()
    end
    if not Aim.LockedTarget then return end

    local char = Aim.LockedTarget.Character
    if not char then Aim.LockedTarget = nil; return end

    local part = ResolveTargetPart(char, Aim.TargetPart)
    if not part then Aim.LockedTarget = nil; return end

    -- Wall check on locked target
    if Aim.WallCheck and not IsVisible(part) then
        Aim.LockedTarget = nil
        return
    end

    -- Get current camera position, build a CFrame looking at target
    local camPos = Camera.CFrame.Position
    local targetCF = CFrame.lookAt(camPos, part.Position)

    -- Lerp for smoothness then apply
    Camera.CFrame = Camera.CFrame:Lerp(targetCF, Aim.Smoothness)
end

local function StartAimBind()
    if isAimBound then return end
    -- Priority 301 = runs AFTER Roblox camera controller (200)
    -- This is the key - Roblox updates camera first, then we override rotation
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
ESPTab:CreateSection("ESP Controls")

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
ESPTab:CreateToggle({Name = "Health Bars", CurrentValue = true, Flag = "ESPHealth", Callback = function(v) ESP.ShowHealth = v end})
ESPTab:CreateToggle({Name = "Tracers", CurrentValue = false, Flag = "ESPTracers", Callback = function(v) ESP.ShowTracers = v end})
ESPTab:CreateToggle({Name = "Team Check", CurrentValue = false, Flag = "ESPTeam", Callback = function(v) ESP.TeamCheck = v end})
ESPTab:CreateSlider({
    Name = "Max Distance", Range = {100, 5000}, Increment = 50, Suffix = " studs",
    CurrentValue = 1000, Flag = "ESPMaxDist", Callback = function(v) ESP.MaxDistance = v end
})
ESPTab:CreateColorPicker({
    Name = "ESP Color", Color = Color3.fromRGB(0, 255, 170), Flag = "ESPColor",
    Callback = function(v) ESP.Color = v end
})

-- ═══════════════════════════════════════════
-- TAB 2: AIM LOCK
-- ═══════════════════════════════════════════
local AimTab = Window:CreateTab("Aim Lock", 4483362458)
AimTab:CreateSection("Aim Lock")

AimTab:CreateToggle({
    Name = "Enable Aim Lock", CurrentValue = false, Flag = "AimToggle",
    Callback = function(v)
        Aim.Enabled = v
        FOVCircle.Visible = v and Aim.ShowFOV
        if v then
            StartAimBind()
            Notify("Nova", "Aim Lock ON (Hold RMB)", 2)
        else
            Aim.Holding = false
            Aim.LockedTarget = nil
            StopAimBind()
            Notify("Nova", "Aim Lock OFF", 2)
        end
    end
})

AimTab:CreateToggle({
    Name = "Wall Check", CurrentValue = false, Flag = "WallCheck",
    Callback = function(v)
        Aim.WallCheck = v
        Notify("Nova", v and "Won't lock through walls" or "Locks through walls", 2)
    end
})

AimTab:CreateToggle({
    Name = "Team Check", CurrentValue = false, Flag = "AimTeam",
    Callback = function(v) Aim.TeamCheck = v end
})

AimTab:CreateToggle({
    Name = "Show FOV Circle", CurrentValue = true, Flag = "ShowFOV",
    Callback = function(v)
        Aim.ShowFOV = v
        FOVCircle.Visible = v and Aim.Enabled
    end
})

AimTab:CreateSection("Tuning")

AimTab:CreateSlider({
    Name = "FOV Radius", Range = {50, 500}, Increment = 10, Suffix = " px",
    CurrentValue = 150, Flag = "AimFOV",
    Callback = function(v) Aim.FOV = v; FOVCircle.Radius = v end
})

AimTab:CreateSlider({
    Name = "Lock Speed", Range = {1, 100}, Increment = 1, Suffix = "%",
    CurrentValue = 50, Flag = "AimSmooth",
    Callback = function(v) Aim.Smoothness = v / 100 end
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
        Aim.TargetPart = type(v) == "table" and v[1] or v
        Notify("Nova", "Locking to: " .. Aim.TargetPart, 2)
    end
})

AimTab:CreateSection("Appearance")
AimTab:CreateColorPicker({
    Name = "FOV Circle Color", Color = Color3.fromRGB(255, 255, 255), Flag = "FOVColor",
    Callback = function(v) FOVCircle.Color = v end
})

-- ═══════════════════════════════════════════
-- TAB 3: PLAYERS
-- ═══════════════════════════════════════════
local PlayerTab = Window:CreateTab("Players", 4483362458)
PlayerTab:CreateSection("Player Management")

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
PlayerTab:CreateButton({Name = "Teleport to Player", Callback = function()
    if SelectedPlayer and IsAlive(SelectedPlayer) and IsAlive(LocalPlayer) then
        LocalPlayer.Character.HumanoidRootPart.CFrame = SelectedPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 5)
        Notify("Nova", "Teleported to " .. SelectedPlayer.DisplayName, 2)
    else Notify("Nova", "No valid player", 2) end
end})
PlayerTab:CreateButton({Name = "Spectate Player", Callback = function()
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
PlayerTab:CreateButton({Name = "Copy Player Info", Callback = function()
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
CharTab:CreateSection("Movement")

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
CharTab:CreateToggle({Name = "Infinite Jump", CurrentValue = false, Flag = "InfJump",
    Callback = function(v) Char.InfJumpEnabled = v; Notify("Nova", v and "Inf Jump ON" or "Inf Jump OFF", 2) end})
CharTab:CreateToggle({Name = "Noclip", CurrentValue = false, Flag = "Noclip",
    Callback = function(v) Char.NoclipEnabled = v; Notify("Nova", v and "Noclip ON" or "Noclip OFF", 2) end})

CharTab:CreateSection("Fly")
CharTab:CreateToggle({Name = "Fly", CurrentValue = false, Flag = "FlyToggle",
    Callback = function(v)
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
VisualsTab:CreateSection("Lighting")

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

VisualsTab:CreateSection("World")
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
ServerTab:CreateSection("Info")
ServerTab:CreateParagraph({Title = "Server Info",
    Content = string.format("Players: %d/%d\nGame ID: %d\nVersion: %d",
        #Players:GetPlayers(), Players.MaxPlayers, game.PlaceId, game.PlaceVersion)})
ServerTab:CreateSection("Actions")
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

SettingsTab:CreateSection("Key System")
SettingsTab:CreateButton({Name = "📋 Copy Key Link", Callback = function()
    if setclipboard then
        setclipboard("https://direct-link.net/2303175/rUZPiU7veMCB")
        Notify("Nova", "Key link copied to clipboard!", 2)
    end
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
SettingsTab:CreateParagraph({Title = "Nova v1.5",
    Content = "Built by Heath\nPowered by Rayfield UI\n\nRightCtrl = Toggle UI\nHold RMB = Lock Aim"})

-- ═══════════════════════════════════════════
-- MAIN LOOPS
-- ═══════════════════════════════════════════

-- Render: ESP + FOV circle
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

-- HOLD RMB to lock, RELEASE to unlock
Connections.AimDown = UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        if Aim.Enabled then
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

-- Noclip
Connections.Noclip = RunService.Stepped:Connect(function()
    if Char.NoclipEnabled and LocalPlayer.Character then
        for _, p in pairs(LocalPlayer.Character:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end
end)

-- Speed + Fly
Connections.Heartbeat = RunService.Heartbeat:Connect(function()
    if Char.SpeedEnabled and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = Char.SpeedValue end
    end
    if Char.FlyEnabled and LocalPlayer.Character then
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

-- Infinite Jump
Connections.InfJump = UserInputService.JumpRequest:Connect(function()
    if Char.InfJumpEnabled and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- ESP player handling
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

-- Start aim bind immediately (it checks Aim.Enabled internally)
StartAimBind()

-- ═══════════════════════════════════════════
Notify("Nova", "Loaded! Hold RMB to lock aim.", 5)
print([[
╔══════════════════════════════════════╗
║          NOVA v1.5 LOADED            ║
║  Hold RMB = Lock | RightCtrl = UI   ║
╚══════════════════════════════════════╝
]])
