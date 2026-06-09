local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local Lighting         = game:GetService("Lighting")
local LocalPlayer      = Players.LocalPlayer
local Camera           = workspace.CurrentCamera
local State            = _G.WaveLiteState
 
local function getHRP()
	local char = LocalPlayer.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end
 
-- ═══════════════════════════════════════════════
-- FLY
-- ═══════════════════════════════════════════════
local flyActive      = false
local flyConnection  = nil
local flyLastMoveDir = Vector3.new(0, 0, 1)
local FLY_DESYNC     = 1.25
 
local function flyGetRoot()
	local char = LocalPlayer.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end
 
local function startFly()
	if flyActive then return end
	local char = LocalPlayer.Character if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	local humanoid = char:FindFirstChild("Humanoid")
	if not root or not humanoid then return end
	humanoid.PlatformStand = false humanoid.WalkSpeed = 0
	humanoid:ChangeState(Enum.HumanoidStateType.Running)
	flyActive = true
	flyConnection = RunService.Heartbeat:Connect(function(dt)
		if not flyActive then return end
		local rootPart = flyGetRoot() if not rootPart then return end
		local speed    = State.Sliders.FlySpeed
		local camLook  = Camera.CFrame.LookVector
		local camRight = Camera.CFrame.RightVector
		local moveDir  = Vector3.new(0, 0, 0)
		if UserInputService:IsKeyDown(Enum.KeyCode.W)           then moveDir = moveDir + camLook end
		if UserInputService:IsKeyDown(Enum.KeyCode.S)           then moveDir = moveDir - camLook end
		if UserInputService:IsKeyDown(Enum.KeyCode.A)           then moveDir = moveDir - camRight end
		if UserInputService:IsKeyDown(Enum.KeyCode.D)           then moveDir = moveDir + camRight end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space)       then moveDir = moveDir + Vector3.new(0,1,0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.new(0,1,0) end
		local isMoving = moveDir.Magnitude > 0
		if isMoving then moveDir = moveDir.Unit flyLastMoveDir = moveDir end
		local targetPos = rootPart.Position + (moveDir * speed * dt * 60)
		local targetCFrame
		if isMoving then
			targetCFrame = CFrame.lookAt(targetPos, targetPos + moveDir)
		else
			targetCFrame = CFrame.new(targetPos) * CFrame.lookAt(Vector3.new(), flyLastMoveDir).Rotation
		end
		if isMoving then
			local desyncOffset = moveDir * FLY_DESYNC + Vector3.new(math.sin(tick()*3.2)*0.18, math.cos(tick()*2.7)*0.12, 0)
			rootPart.CFrame = targetCFrame + desyncOffset
			rootPart.AssemblyLinearVelocity = moveDir * speed * 0.65
		else
			rootPart.CFrame = targetCFrame
			rootPart.AssemblyLinearVelocity = Vector3.new(0,0,0)
		end
		if isMoving then
			local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
			if hum then hum:ChangeState(Enum.HumanoidStateType.Running) end
		end
	end)
end
 
local function stopFly()
	if not flyActive then return end
	flyActive = false
	if flyConnection then flyConnection:Disconnect() flyConnection = nil end
	local char = LocalPlayer.Character
	if char then
		local humanoid = char:FindFirstChild("Humanoid")
		local root     = char:FindFirstChild("HumanoidRootPart")
		if humanoid then
			humanoid.PlatformStand = false
			humanoid.WalkSpeed = 16
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end
		if root then root.AssemblyLinearVelocity = Vector3.new(0,0,0) end
	end
end
 
_G.WaveLite_Fly_Toggle = function()
	if flyActive then stopFly() else startFly() end
end
 
LocalPlayer.CharacterAdded:Connect(function()
	task.wait(0.5)
	if flyActive then flyActive = false startFly() end
end)
 
-- ═══════════════════════════════════════════════
-- NOCLIP
-- ═══════════════════════════════════════════════
local noclipConnection = nil
 
_G.WaveLite_Noclip_Toggle = function(on)
	if on then
		if noclipConnection then return end
		noclipConnection = RunService.Stepped:Connect(function()
			local char = LocalPlayer.Character
			if char then
				for _, part in ipairs(char:GetDescendants()) do
					if part:IsA("BasePart") then part.CanCollide = false end
				end
			end
		end)
	else
		if noclipConnection then noclipConnection:Disconnect() noclipConnection = nil end
		RunService.Heartbeat:Wait()
		task.defer(function()
			local char = LocalPlayer.Character
			if not char then return end
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then pcall(function() part.CanCollide = true end) end
			end
		end)
	end
end
 
LocalPlayer.CharacterAdded:Connect(function()
	task.wait(0.1)
	if State.Toggles.Noclip and not noclipConnection then
		noclipConnection = RunService.Stepped:Connect(function()
			local char = LocalPlayer.Character
			if char then
				for _, part in ipairs(char:GetDescendants()) do
					if part:IsA("BasePart") then part.CanCollide = false end
				end
			end
		end)
	end
end)
 
-- ═══════════════════════════════════════════════
-- CAM LOCK
-- ═══════════════════════════════════════════════
local camLockActive     = false
local camLockedTarget   = nil
local wallCheckCache    = {}
local wallCheckFrame    = 0
local WALLCHECK_INTERVAL = 6
 
local fovCircle = Drawing.new("Circle")
fovCircle.Visible = false fovCircle.Color = Color3.fromRGB(255,255,255)
fovCircle.Thickness = 1 fovCircle.Transparency = 0.5
fovCircle.Filled = false fovCircle.NumSides = 64 fovCircle.ZIndex = 8
 
local lockDot = Drawing.new("Circle")
lockDot.Visible = false lockDot.Color = Color3.fromRGB(255,80,80)
lockDot.Thickness = 1 lockDot.Transparency = 0
lockDot.Filled = true lockDot.Radius = 4 lockDot.NumSides = 16 lockDot.ZIndex = 9
 
local function camIsEnemy(plr)
	if not State.Toggles.TeamCheck then return true end
	if LocalPlayer.Team == nil or plr.Team == nil then return true end
	return LocalPlayer.Team ~= plr.Team
end
 
local function camIsValidTarget(plr)
	if plr == nil then return false end
	if not plr.Character then return false end
	local hum = plr.Character:FindFirstChild("Humanoid")
	if not hum or hum.Health <= 0 then return false end
	if not camIsEnemy(plr) then return false end
	if not plr.Character:FindFirstChild("HumanoidRootPart") then return false end
	return true
end
 
local function camIsVisible(plr) return wallCheckCache[plr] == true end
 
local function doWallChecks()
	wallCheckFrame = wallCheckFrame + 1
	if wallCheckFrame < WALLCHECK_INTERVAL then return end
	wallCheckFrame = 0
	local origin = Camera.CFrame.Position
	local rp = RaycastParams.new()
	rp.FilterDescendantsInstances = { LocalPlayer.Character }
	rp.FilterType = Enum.RaycastFilterType.Exclude
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer and plr.Character then
			local part = plr.Character:FindFirstChild(State.AimPart)
			if part then
				local dir    = part.Position - origin
				local result = workspace:Raycast(origin, dir, rp)
				if result then
					local targetModel = part:FindFirstAncestorOfClass("Model")
					wallCheckCache[plr] = result.Instance:IsDescendantOf(targetModel)
				else
					wallCheckCache[plr] = true
				end
			else
				wallCheckCache[plr] = false
			end
		end
	end
end
 
Players.PlayerRemoving:Connect(function(plr)
	if camLockedTarget == plr then camLockedTarget = nil end
	wallCheckCache[plr] = nil
end)
 
RunService.RenderStepped:Connect(function()
	local center = Camera.ViewportSize / 2
	local fovR   = State.Sliders.FOVRadius
	if camLockActive and State.Toggles.FOVCircle then
		fovCircle.Position = center fovCircle.Radius = fovR fovCircle.Visible = true
	else
		fovCircle.Visible = false
	end
	if not camLockActive then lockDot.Visible = false return end
	if State.Toggles.WallCheck then doWallChecks() end
	if camLockedTarget ~= nil and not camIsValidTarget(camLockedTarget) then camLockedTarget = nil end
	if camLockedTarget == nil then
		local bestTarget, bestDist = nil, fovR
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr == LocalPlayer then continue end
			if not camIsValidTarget(plr) then continue end
			if State.Toggles.WallCheck and not camIsVisible(plr) then continue end
			local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local spos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
				if onScreen then
					local dist = (Vector2.new(spos.X, spos.Y) - center).Magnitude
					if dist < bestDist then bestDist = dist bestTarget = plr end
				end
			end
		end
		camLockedTarget = bestTarget
	end
	if camLockedTarget then
		local aimPart = camLockedTarget.Character and (camLockedTarget.Character:FindFirstChild(State.AimPart) or camLockedTarget.Character:FindFirstChild("HumanoidRootPart"))
		local root    = camLockedTarget.Character and camLockedTarget.Character:FindFirstChild("HumanoidRootPart")
		if aimPart and root then
			local vel        = root.AssemblyLinearVelocity * State.Sliders.Prediction
			local smoothness = math.max(State.Sliders.Smoothness, 1)
			Camera.CFrame    = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, aimPart.Position + vel), 1 / smoothness)
			if State.Toggles.LockIndicator then
				local sp, onScreen = Camera:WorldToViewportPoint(aimPart.Position + vel)
				if onScreen then lockDot.Position = Vector2.new(sp.X, sp.Y) lockDot.Visible = true
				else lockDot.Visible = false end
			else
				lockDot.Visible = false
			end
		else
			lockDot.Visible = false
		end
	else
		lockDot.Visible = false
	end
end)
 
_G.WaveLite_CamLock_Toggle = function()
	camLockActive = not camLockActive
	if not camLockActive then
		camLockedTarget   = nil
		fovCircle.Visible = false
		lockDot.Visible   = false
	end
end
 
-- ═══════════════════════════════════════════════
-- NO FOG
-- ═══════════════════════════════════════════════
local savedLightingEffects = {}
local POST_FX_CLASSES = { "BlurEffect","BloomEffect","DepthOfFieldEffect","ColorCorrectionEffect","SunRaysEffect","Atmosphere" }
 
local function collectPostFX()
	local found = {}
	for _, class in ipairs(POST_FX_CLASSES) do
		for _, obj in ipairs(Lighting:GetDescendants()) do
			if obj:IsA(class) then table.insert(found, obj) end
		end
		local inWorkspace = workspace:FindFirstChildOfClass(class)
		if inWorkspace then table.insert(found, inWorkspace) end
	end
	return found
end
 
_G.WaveLite_NoFog_Toggle = function(on)
	if on then
		savedLightingEffects.FogEnd   = Lighting.FogEnd
		savedLightingEffects.FogStart = Lighting.FogStart
		Lighting.FogEnd   = 9999999
		Lighting.FogStart = 9999998
		savedLightingEffects.fx = {}
		for _, obj in ipairs(collectPostFX()) do
			table.insert(savedLightingEffects.fx, { obj = obj, was = obj.Enabled })
			pcall(function() obj.Enabled = false end)
		end
	else
		Lighting.FogEnd   = savedLightingEffects.FogEnd   or 9999999
		Lighting.FogStart = savedLightingEffects.FogStart or 9999998
		if savedLightingEffects.fx then
			for _, entry in ipairs(savedLightingEffects.fx) do
				pcall(function() entry.obj.Enabled = entry.was end)
			end
		end
		savedLightingEffects = {}
	end
end
 
-- ═══════════════════════════════════════════════
-- MAXZOOM
-- ═══════════════════════════════════════════════
local maxzoomConn     = nil
local maxzoomCharConn = nil
 
local function applyMaxzoom()
	pcall(function() LocalPlayer.CameraMaxZoomDistance = 500 end)
	pcall(function() game:GetService("StarterPlayer").CameraMaxZoomDistance = 500 end)
end
 
_G.WaveLite_Maxzoom_Toggle = function(on)
	if on then
		applyMaxzoom()
		maxzoomConn = RunService.Heartbeat:Connect(function()
			if State.Toggles.Maxzoom then pcall(function() LocalPlayer.CameraMaxZoomDistance = 500 end) end
		end)
		maxzoomCharConn = LocalPlayer.CharacterAdded:Connect(function()
			task.wait(0.1) if State.Toggles.Maxzoom then applyMaxzoom() end
		end)
	else
		if maxzoomConn     then maxzoomConn:Disconnect()     maxzoomConn     = nil end
		if maxzoomCharConn then maxzoomCharConn:Disconnect() maxzoomCharConn = nil end
		pcall(function() LocalPlayer.CameraMaxZoomDistance = 400 end)
	end
end
 
-- ═══════════════════════════════════════════════
-- CAM FOV
-- ═══════════════════════════════════════════════
local camFOVConn = nil
 
_G.WaveLite_CamFOV_Toggle = function(on)
	if on then
		if camFOVConn then return end
		camFOVConn = RunService.Heartbeat:Connect(function()
			if State.Toggles.CamFOV then pcall(function() Camera.FieldOfView = State.Sliders.CamFOV end) end
		end)
	else
		if camFOVConn then camFOVConn:Disconnect() camFOVConn = nil end
		pcall(function() Camera.FieldOfView = 70 end)
	end
end
 
-- ═══════════════════════════════════════════════
-- NAME ESP
-- ═══════════════════════════════════════════════
local nameESPObjects = {}
 
local function addNameESP(player)
	if player == LocalPlayer then return end
	local function applyTag(char)
		if not char then return end
		pcall(function() if nameESPObjects[player] then nameESPObjects[player]:Destroy() end end)
		local hrp = char:WaitForChild("HumanoidRootPart", 3) if not hrp then return end
		local bb = Instance.new("BillboardGui")
		bb.Name = "WL_NameESP" bb.Parent = hrp bb.Size = UDim2.fromOffset(120, 20)
		bb.StudsOffset = Vector3.new(0, 3.2, 0) bb.AlwaysOnTop = true bb.LightInfluence = 0 bb.ResetOnSpawn = false
		local lbl = Instance.new("TextLabel")
		lbl.Parent = bb lbl.Size = UDim2.new(1,0,1,0) lbl.BackgroundTransparency = 1
		lbl.Text = player.DisplayName lbl.TextColor3 = Color3.fromRGB(255,255,255) lbl.TextSize = 13
		lbl.Font = Enum.Font.GothamBold lbl.TextStrokeTransparency = 0.4 lbl.TextStrokeColor3 = Color3.fromRGB(0,0,0)
		nameESPObjects[player] = bb
	end
	applyTag(player.Character)
	player.CharacterAdded:Connect(function(char)
		if State.Toggles.NameESP then task.wait(0.2) applyTag(char) end
	end)
end
 
local function removeNameESP(player)
	if nameESPObjects[player] then
		pcall(function() nameESPObjects[player]:Destroy() end)
		nameESPObjects[player] = nil
	end
end
 
_G.WaveLite_NameESP_Toggle = function(on)
	if on then
		for _, p in ipairs(Players:GetPlayers()) do addNameESP(p) end
	else
		for p in pairs(nameESPObjects) do removeNameESP(p) end
	end
end
 
Players.PlayerAdded:Connect(function(p)   if State.Toggles.NameESP then addNameESP(p) end end)
Players.PlayerRemoving:Connect(function(p) removeNameESP(p) end)
 
-- ═══════════════════════════════════════════════
-- BOX ESP
-- ═══════════════════════════════════════════════
local boxDrawings = {}
local boxESPConn  = nil
local BOX_COLOR   = Color3.fromRGB(255, 50, 50)
local BOX_THICK   = 1.5
 
local function getCharScreenBounds(char)
	local hrp = char:FindFirstChild("HumanoidRootPart") if not hrp then return nil end
	local charHeight = 5
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then charHeight = (hum.HipHeight + 2.5) * 2 end
	local halfH   = charHeight / 2
	local feetPos = hrp.Position - Vector3.new(0, halfH, 0)
	local headPos = hrp.Position + Vector3.new(0, halfH + 0.5, 0)
	local feetSP  = Camera:WorldToViewportPoint(feetPos)
	local headSP  = Camera:WorldToViewportPoint(headPos)
	if feetSP.Z <= 0 or headSP.Z <= 0 then return nil end
	local screenH = math.abs(feetSP.Y - headSP.Y) if screenH < 4 then return nil end
	local hrpSP   = Camera:WorldToViewportPoint(hrp.Position)
	local halfW   = screenH * 0.25
	return hrpSP.X - halfW, math.min(feetSP.Y, headSP.Y), hrpSP.X + halfW, math.max(feetSP.Y, headSP.Y)
end
 
local function newBoxDrawings()
	local t = { lines = {}, hbar = {}, dist = nil }
	for i = 1, 4 do
		local l = Drawing.new("Line") l.Color = BOX_COLOR l.Thickness = BOX_THICK l.Visible = false l.ZIndex = 5
		t.lines[i] = l
	end
	local hbg   = Drawing.new("Line") hbg.Color   = Color3.fromRGB(60,60,60) hbg.Thickness   = 3 hbg.Visible   = false hbg.ZIndex   = 5
	local hfill = Drawing.new("Line") hfill.Color = Color3.fromRGB(0,255,0)  hfill.Thickness = 3 hfill.Visible = false hfill.ZIndex = 6
	t.hbar[1] = hbg t.hbar[2] = hfill
	local dist = Drawing.new("Text")
	dist.Visible = false dist.Color = Color3.fromRGB(255,255,255) dist.Size = 11
	dist.Font = Drawing.Fonts.UI dist.Center = true dist.Outline = true
	dist.OutlineColor = Color3.fromRGB(0,0,0) dist.ZIndex = 6
	t.dist = dist
	return t
end
 
local function showBoxDrawings(d, x1, y1, x2, y2, healthPct, distText)
	d.lines[1].From=Vector2.new(x1,y1) d.lines[1].To=Vector2.new(x2,y1)
	d.lines[2].From=Vector2.new(x1,y2) d.lines[2].To=Vector2.new(x2,y2)
	d.lines[3].From=Vector2.new(x1,y1) d.lines[3].To=Vector2.new(x1,y2)
	d.lines[4].From=Vector2.new(x2,y1) d.lines[4].To=Vector2.new(x2,y2)
	for _, l in ipairs(d.lines) do l.Visible = true end
	local barX = x1 - 5 local barTop = y1 local barBot = y2 local barH = barBot - barTop
	d.hbar[1].From=Vector2.new(barX,barTop) d.hbar[1].To=Vector2.new(barX,barBot) d.hbar[1].Visible=State.Toggles.HealthBars
	local fillTop = barBot-(barH*healthPct)
	local r = math.floor(255*(1-healthPct)) local g = math.floor(255*healthPct)
	d.hbar[2].Color=Color3.fromRGB(r,g,0) d.hbar[2].From=Vector2.new(barX,fillTop) d.hbar[2].To=Vector2.new(barX,barBot) d.hbar[2].Visible=State.Toggles.HealthBars
	d.dist.Text=distText d.dist.Position=Vector2.new((x1+x2)/2, y2+2) d.dist.Visible=true
end
 
local function hideBoxDrawings(d)
	for _, l in ipairs(d.lines) do l.Visible = false end
	d.hbar[1].Visible=false d.hbar[2].Visible=false d.dist.Visible=false
end
 
local function destroyBoxDrawings(d)
	for _, l in ipairs(d.lines) do pcall(function() l:Remove() end) end
	pcall(function() d.hbar[1]:Remove() end)
	pcall(function() d.hbar[2]:Remove() end)
	pcall(function() d.dist:Remove() end)
end
 
local function updateBoxESP()
	local localHRP = getHRP()
	for _, player in ipairs(Players:GetPlayers()) do
		if player == LocalPlayer then continue end
		if not boxDrawings[player] then boxDrawings[player] = newBoxDrawings() end
		local char = player.Character local d = boxDrawings[player]
		if char then
			local x1,y1,x2,y2 = getCharScreenBounds(char)
			if x1 then
				local hum       = char:FindFirstChildOfClass("Humanoid")
				local healthPct = (hum and hum.MaxHealth > 0) and math.clamp(hum.Health/hum.MaxHealth,0,1) or 1
				local hrp       = char:FindFirstChild("HumanoidRootPart")
				local distText  = ""
				if localHRP and hrp then distText = math.floor((localHRP.Position-hrp.Position).Magnitude).."m" end
				showBoxDrawings(d, x1, y1, x2, y2, healthPct, distText)
			else
				hideBoxDrawings(d)
			end
		else
			hideBoxDrawings(d)
		end
	end
	for player, d in pairs(boxDrawings) do
		if not player or not player.Parent then destroyBoxDrawings(d) boxDrawings[player] = nil end
	end
end
 
local function clearBoxESP()
	for _, d in pairs(boxDrawings) do destroyBoxDrawings(d) end
	boxDrawings = {}
end
 
_G.WaveLite_BoxESP_Toggle = function(on)
	if on then
		if not boxESPConn then boxESPConn = RunService.RenderStepped:Connect(updateBoxESP) end
	else
		if boxESPConn then boxESPConn:Disconnect() boxESPConn = nil end
		clearBoxESP()
	end
end
 
Players.PlayerRemoving:Connect(function(p)
	if boxDrawings[p] then destroyBoxDrawings(boxDrawings[p]) boxDrawings[p] = nil end
end)
 
-- ═══════════════════════════════════════════════
-- TRACERS
-- ═══════════════════════════════════════════════
local tracerObjects = {}
local tracerConn    = nil
 
local function updateTracers()
	local cam      = Camera local localHRP = getHRP() local vp = cam.ViewportSize
	local from     = Vector2.new(vp.X/2, vp.Y)
	for _, player in ipairs(Players:GetPlayers()) do
		if player == LocalPlayer then continue end
		local td = tracerObjects[player]
		if not td then
			local line  = Drawing.new("Line")
			line.Visible=false line.Color=Color3.fromRGB(255,60,60) line.Thickness=1.5 line.Transparency=0.15 line.ZIndex=5
			local label = Drawing.new("Text")
			label.Visible=false label.Color=Color3.fromRGB(255,255,255) label.Size=13
			label.Font=Drawing.Fonts.UI label.Center=true label.Outline=true label.OutlineColor=Color3.fromRGB(0,0,0) label.ZIndex=6
			td = { line=line, label=label }
			tracerObjects[player] = td
		end
		local char = player.Character local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local sp, onScreen = cam:WorldToViewportPoint(hrp.Position)
			if onScreen then
				local to   = Vector2.new(sp.X, sp.Y)
				local dist = localHRP and math.floor((localHRP.Position-hrp.Position).Magnitude) or 0
				td.line.From=from td.line.To=to td.line.Visible=true
				td.label.Text=tostring(dist).."m"
				td.label.Position=Vector2.new((from.X+to.X)/2, (from.Y+to.Y)/2-8)
				td.label.Visible=true
			else
				td.line.Visible=false td.label.Visible=false
			end
		else
			td.line.Visible=false td.label.Visible=false
		end
	end
	for player, td in pairs(tracerObjects) do
		if not player or not player.Parent then
			pcall(function() td.line:Remove() end)
			pcall(function() td.label:Remove() end)
			tracerObjects[player] = nil
		end
	end
end
 
local function clearAllTracers()
	for _, td in pairs(tracerObjects) do
		pcall(function() td.line:Remove() end)
		pcall(function() td.label:Remove() end)
	end
	tracerObjects = {}
end
 
_G.WaveLite_Tracers_Toggle = function(on)
	if on then
		if not tracerConn then tracerConn = RunService.RenderStepped:Connect(updateTracers) end
	else
		if tracerConn then tracerConn:Disconnect() tracerConn = nil end
		clearAllTracers()
	end
end
 
Players.PlayerRemoving:Connect(function(p)
	if tracerObjects[p] then
		pcall(function() tracerObjects[p].line:Remove() end)
		pcall(function() tracerObjects[p].label:Remove() end)
		tracerObjects[p] = nil
	end
end)
 
-- ═══════════════════════════════════════════════
-- CLICK TP
-- ═══════════════════════════════════════════════
local clickTPTool        = nil
local clickTPConn        = nil
local clickTPRespawnConn = nil
 
_G.WaveLite_ClickTP_Remove = function()
	if clickTPConn        then clickTPConn:Disconnect()        clickTPConn        = nil end
	if clickTPRespawnConn then clickTPRespawnConn:Disconnect() clickTPRespawnConn = nil end
	if clickTPTool        then pcall(function() clickTPTool:Destroy() end) clickTPTool = nil end
end
 
_G.WaveLite_ClickTP_Create = function()
	_G.WaveLite_ClickTP_Remove()
	local tool = Instance.new("Tool")
	tool.Name = "TP Tool" tool.RequiresHandle = false
	tool.ToolTip = "Click anywhere to teleport" tool.CanBeDropped = false
	clickTPConn = tool.Activated:Connect(function()
		if not State.Toggles.ClickTP then return end
		local hrp = getHRP() if not hrp then return end
		local mouse   = LocalPlayer:GetMouse()
		local unitRay = Camera:ScreenPointToRay(mouse.X, mouse.Y)
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		rp.FilterDescendantsInstances = { LocalPlayer.Character }
		local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 2048, rp)
		if result then hrp.CFrame = CFrame.new(result.Position + Vector3.new(0, 3, 0)) end
	end)
	clickTPTool        = tool
	tool.Parent        = LocalPlayer.Backpack
	clickTPRespawnConn = LocalPlayer.CharacterAdded:Connect(function()
		task.wait(0.5)
		if State.Toggles.ClickTP and clickTPTool then clickTPTool.Parent = LocalPlayer.Backpack end
	end)
end
