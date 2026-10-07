-- trickyhub: client-only. Studio: StarterPlayer > StarterPlayerScripts > LocalScript.
-- No remote downloads or server requests. Server rules may override movement.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer
assert(player, "Run this script on the client")
local playerGui = player:WaitForChild("PlayerGui")
local previous = playerGui:FindFirstChild("trickyhub_ui")
if previous then
    local cleanup = previous:FindFirstChild("Cleanup")
    if cleanup and cleanup:IsA("BindableEvent") then cleanup:Fire() end
    previous:Destroy()
end

local enabled = {Fly=false, Noclip=false, Speed=false, Jump=false, InfJump=false,
    ClickTP=false, ESP=false, FullBright=false}
local settings = {Speed=100, Jump=150, Fly=80}
local connections, highlights, collision = {}, {}, {}
local character, humanoid, root, baseline
local flyAttachment, flyVelocity, flyOrientation, savedFlight
local originalLighting, originalSky, originalAtmosphere = {}, {}, {}
local skyChanged, dead = false, false
local function connect(signal, callback)
    local c = signal:Connect(callback)
    table.insert(connections, c)
    return c
end
for _, key in ipairs({"Brightness", "ClockTime", "GlobalShadows", "Ambient", "OutdoorAmbient"}) do
    originalLighting[key] = Lighting[key]
end
for _, item in ipairs(Lighting:GetChildren()) do
    if item:IsA("Sky") then table.insert(originalSky, item:Clone()) end
    if item:IsA("Atmosphere") then table.insert(originalAtmosphere, item:Clone()) end
end
local gui = Instance.new("ScreenGui")
gui.Name = "trickyhub_ui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui
local cleanupEvent = Instance.new("BindableEvent")
cleanupEvent.Name = "Cleanup"
cleanupEvent.Parent = gui
local function rounded(instance, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = instance
end
local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(530, 460)
frame.Position = UDim2.new(.5, -265, .5, -230)
frame.BackgroundColor3 = Color3.fromRGB(18, 19, 25)
frame.BorderSizePixel = 0
frame.Parent = gui
rounded(frame, 12)
local scale = Instance.new("UIScale")
scale.Parent = frame
local function fitScreen()
    local camera = workspace.CurrentCamera
    if camera then scale.Scale = math.clamp(math.min(camera.ViewportSize.X / 550, camera.ViewportSize.Y / 480), .2, 1) end
end
local header = Instance.new("TextLabel")
header.Size = UDim2.new(1, -65, 0, 52)
header.Position = UDim2.fromOffset(16, 0)
header.BackgroundTransparency = 1
header.Text = "trickyhub · client"
header.TextColor3 = Color3.fromRGB(50, 175, 255)
header.Font = Enum.Font.GothamBold
header.TextSize = 24
header.TextXAlignment = Enum.TextXAlignment.Left
header.Active = true
header.Parent = frame
local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(38, 38)
close.Position = UDim2.new(1, -46, 0, 7)
close.Text = "×"
close.TextSize = 24
close.TextColor3 = Color3.new(1, 1, 1)
close.BackgroundColor3 = Color3.fromRGB(55, 35, 40)
close.Parent = frame
rounded(close)
local container = Instance.new("ScrollingFrame")
container.Size = UDim2.new(1, -32, 1, -112)
container.Position = UDim2.fromOffset(16, 56)
container.BackgroundTransparency = 1
container.BorderSizePixel = 0
container.ScrollBarThickness = 4
container.AutomaticCanvasSize = Enum.AutomaticSize.Y
container.CanvasSize = UDim2.new()
container.Parent = frame
local layout = Instance.new("UIGridLayout")
layout.CellSize = UDim2.new(.5, -8, 0, 44)
layout.CellPadding = UDim2.fromOffset(8, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = container
local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -32, 0, 48)
status.Position = UDim2.new(0, 16, 1, -52)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(185, 190, 200)
status.TextSize = 12
status.TextWrapped = true
status.Font = Enum.Font.Gotham
status.Text = "RightAlt: меню · Fly: WASD, Space/↑ вверх, Ctrl/↓ вниз · Ctrl + клик: TP"
status.Parent = frame
local order = 0
local function button(label, callback)
    order += 1
    local b = Instance.new("TextButton")
    b.LayoutOrder = order
    b.BackgroundColor3 = Color3.fromRGB(32, 35, 44)
    b.TextColor3 = Color3.fromRGB(235, 238, 245)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 14
    b.Text = label
    b.Parent = container
    rounded(b)
    connect(b.Activated, function()
        local ok, err = pcall(callback)
        if not ok then status.Text = "Ошибка: " .. tostring(err); warn(err) end
    end)
    return b
end
local function restoreCollision()
    for part, value in pairs(collision) do
        if part.Parent then part.CanCollide = value end
    end
    table.clear(collision)
end
local function stopFly()
    if flyVelocity then flyVelocity:Destroy(); flyVelocity = nil end
    if flyOrientation then flyOrientation:Destroy(); flyOrientation = nil end
    if flyAttachment then flyAttachment:Destroy(); flyAttachment = nil end
    if savedFlight and savedFlight.h.Parent then
        savedFlight.h.PlatformStand = savedFlight.platform
        savedFlight.h.AutoRotate = savedFlight.rotate
    end
    savedFlight = nil
end
local function startFly()
    stopFly()
    if not root or not humanoid or humanoid.Health <= 0 then return end
    savedFlight = {h=humanoid, platform=humanoid.PlatformStand, rotate=humanoid.AutoRotate}
    humanoid.PlatformStand = true
    humanoid.AutoRotate = false
    flyAttachment = Instance.new("Attachment")
    flyAttachment.Parent = root
    flyVelocity = Instance.new("LinearVelocity")
    flyVelocity.Attachment0 = flyAttachment
    flyVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
    flyVelocity.MaxForce = math.huge
    flyVelocity.VectorVelocity = Vector3.zero
    flyVelocity.Parent = root
    flyOrientation = Instance.new("AlignOrientation")
    flyOrientation.Attachment0 = flyAttachment
    flyOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
    flyOrientation.MaxTorque = math.huge
    flyOrientation.Responsiveness = 25
    flyOrientation.Parent = root
end
local function applyMovement()
    if not humanoid or not baseline then return end
    humanoid.WalkSpeed = enabled.Speed and settings.Speed or baseline.speed
    if enabled.Jump then
        humanoid.UseJumpPower = true
        humanoid.JumpPower = settings.Jump
    else
        humanoid.UseJumpPower = baseline.useJump
        humanoid.JumpPower = baseline.jumpPower
        humanoid.JumpHeight = baseline.jumpHeight
    end
end
local function refreshLighting()
    for key, value in pairs(originalLighting) do Lighting[key] = value end
    if skyChanged then Lighting.ClockTime = 0 end
    if enabled.FullBright then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(180, 180, 180)
        Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
    end
end
local function clearSky()
    for _, item in ipairs(Lighting:GetChildren()) do
        if item:IsA("Sky") or item:IsA("Atmosphere") then item:Destroy() end
    end
end
local function resetSky()
    if skyChanged then
        clearSky()
        for _, item in ipairs(originalSky) do item:Clone().Parent = Lighting end
        for _, item in ipairs(originalAtmosphere) do item:Clone().Parent = Lighting end
        skyChanged = false
        refreshLighting()
    end
end
local function setSky(id)
    clearSky()
    skyChanged = true
    local sky = Instance.new("Sky")
    for _, key in ipairs({"SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp"}) do
        sky[key] = "rbxassetid://" .. tostring(id)
    end
    sky.Parent = Lighting
    refreshLighting()
    status.Text = "Небо применено. Вид зависит от доступности текстуры; одинаковые грани могут иметь швы."
end
local function clearESP()
    for _, h in pairs(highlights) do h:Destroy() end
    table.clear(highlights)
end
local function refreshESP()
    for p, h in pairs(highlights) do
        if not enabled.ESP or p.Parent ~= Players or p.Character ~= h.Adornee then
            h:Destroy(); highlights[p] = nil
        end
    end
    if not enabled.ESP then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character and not highlights[p] then
            local h = Instance.new("Highlight")
            h.Name = "TrickyESP"
            h.Adornee = p.Character
            h.FillColor = Color3.fromRGB(0, 160, 255)
            h.FillTransparency = .6
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.Parent = gui
            highlights[p] = h
        end
    end
end
local toggleButtons = {}
local function toggle(key, label, action)
    local b
    b = button(label .. ": OFF", function()
        enabled[key] = not enabled[key]
        b.Text = label .. (enabled[key] and ": ON" or ": OFF")
        b.BackgroundColor3 = enabled[key] and Color3.fromRGB(0, 110, 175) or Color3.fromRGB(32, 35, 44)
        if action then action() end
    end)
    toggleButtons[key] = b
end
toggle("Fly", "Fly", function() if enabled.Fly then startFly() else stopFly() end end)
toggle("Noclip", "Noclip", function() if not enabled.Noclip then restoreCollision() end end)
toggle("Speed", "Speed", applyMovement)
toggle("Jump", "Jump", applyMovement)
toggle("InfJump", "Infinite Jump")
toggle("ClickTP", "Ctrl + Click TP")
toggle("ESP", "ESP", refreshESP)
toggle("FullBright", "FullBright", refreshLighting)
button("Sky: Stars", function() setSky(7088418096) end)
button("Sky: Purple", function() setSky(600886096) end)
button("Sky: Anime", function() setSky(252760981) end)
button("Sky: Reset", resetSky)
local deathConnection
local function unbindCharacter()
    if deathConnection then deathConnection:Disconnect(); deathConnection = nil end
    stopFly()
    restoreCollision()
    if humanoid and humanoid.Parent and baseline then
        humanoid.WalkSpeed = baseline.speed
        humanoid.UseJumpPower = baseline.useJump
        humanoid.JumpPower = baseline.jumpPower
        humanoid.JumpHeight = baseline.jumpHeight
    end
    character, humanoid, root, baseline = nil, nil, nil, nil
end
local function bindCharacter(char)
    unbindCharacter()
    character = char
    local h = char:WaitForChild("Humanoid", 10)
    local r = char:WaitForChild("HumanoidRootPart", 10)
    if dead or character ~= char or not h or not r then return end
    humanoid, root = h, r
    baseline = {speed=h.WalkSpeed, useJump=h.UseJumpPower, jumpPower=h.JumpPower, jumpHeight=h.JumpHeight}
    applyMovement()
    deathConnection = h.Died:Connect(function() stopFly(); restoreCollision() end)
    if enabled.Fly then startFly() end
end
connect(player.CharacterAdded, function(char) task.spawn(bindCharacter, char) end)
connect(player.CharacterRemoving, function(char) if character == char then unbindCharacter() end end)
connect(RunService.Stepped, function()
    if enabled.Noclip and character and humanoid and humanoid.Health > 0 then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                if collision[part] == nil then collision[part] = part.CanCollide end
                part.CanCollide = false
            end
        end
    end
end)
local elapsed = 0
connect(RunService.RenderStepped, function(dt)
    fitScreen()
    elapsed += dt
    if elapsed >= .25 then elapsed = 0; refreshESP() end
    if not flyVelocity or not flyOrientation then return end
    local camera = workspace.CurrentCamera
    if not camera or not root or not root.Parent then stopFly(); return end
    local direction = Vector3.zero
    if not UIS:GetFocusedTextBox() then
        if UIS:IsKeyDown(Enum.KeyCode.W) then direction += camera.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then direction -= camera.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then direction -= camera.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then direction += camera.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) or UIS:IsKeyDown(Enum.KeyCode.Up) then direction += Vector3.yAxis end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.Down) then direction -= Vector3.yAxis end
        -- MoveDirection also supports the mobile thumbstick.
        if direction.Magnitude == 0 then direction = humanoid.MoveDirection end
    end
    flyVelocity.VectorVelocity = direction.Magnitude > 0 and direction.Unit * settings.Fly or Vector3.zero
    flyOrientation.CFrame = camera.CFrame.Rotation
end)
connect(UIS.JumpRequest, function()
    if enabled.InfJump and not enabled.Fly and humanoid and humanoid.Health > 0 and not UIS:GetFocusedTextBox() then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)
local mouse = player:GetMouse()
connect(UIS.InputBegan, function(input, processed)
    if processed or UIS:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.RightAlt then frame.Visible = not frame.Visible end
    if input.UserInputType == Enum.UserInputType.MouseButton1 and enabled.ClickTP and UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
        if character and root and humanoid and humanoid.Health > 0 and mouse.Target then
            root.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2 + .5, 0)) * root.CFrame.Rotation
            root.AssemblyLinearVelocity = Vector3.zero
        end
    end
end)
local drag, dragStart, frameStart
connect(header.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        drag, dragStart, frameStart = input, input.Position, frame.Position
    end
end)
connect(UIS.InputChanged, function(input)
    if drag and (input == drag or (drag.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement)) then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(frameStart.X.Scale, frameStart.X.Offset + delta.X, frameStart.Y.Scale, frameStart.Y.Offset + delta.Y)
    end
end)
connect(UIS.InputEnded, function(input) if input == drag then drag = nil end end)
local function cleanup()
    if dead then return end
    dead = true
    for _, c in ipairs(connections) do c:Disconnect() end
    table.clear(connections)
    unbindCharacter()
    clearESP()
    enabled.FullBright = false
    resetSky()
    skyChanged = false
    refreshLighting()
    for _, item in ipairs(originalSky) do item:Destroy() end
    for _, item in ipairs(originalAtmosphere) do item:Destroy() end
    gui:Destroy()
end
connect(cleanupEvent.Event, cleanup)
connect(close.Activated, cleanup)
connect(gui.Destroying, cleanup)
if player.Character then task.spawn(bindCharacter, player.Character) end
fitScreen()

