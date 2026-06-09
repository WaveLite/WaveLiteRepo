local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local CoreGui          = game:GetService("CoreGui")
local LocalPlayer      = Players.LocalPlayer
local Camera           = workspace.CurrentCamera
 
local State            = _G.WaveLiteState
 
local GuiParent = CoreGui
pcall(function() if gethui then GuiParent = gethui() end end)
 
-- Shared theme state (kept local, used by chat.lua too via ScreenGui reference)
local THEMES = {
	dark = {
		BG=Color3.fromRGB(22,22,26), HEADER=Color3.fromRGB(16,16,20),
		PANEL=Color3.fromRGB(28,28,33), BODY=Color3.fromRGB(24,24,29),
		BORDER=Color3.fromRGB(55,55,65), HIGHLIGHT=Color3.fromRGB(40,40,48),
		TEXT=Color3.fromRGB(210,210,215), SUBTEXT=Color3.fromRGB(130,130,140),
		CHECKBOX=Color3.fromRGB(36,36,44), CB_HOVER=Color3.fromRGB(48,48,58),
		CB_BORDER=Color3.fromRGB(70,70,85), MARK=Color3.fromRGB(130,200,255),
		TRACK=Color3.fromRGB(40,40,50), FILL=Color3.fromRGB(100,170,255),
		KNOB=Color3.fromRGB(180,220,255), VAL=Color3.fromRGB(100,170,255),
		SCROLL=Color3.fromRGB(70,70,90),
		LOGO_ID="rbxthumb://type=Asset&id=128151636315425&w=420&h=420",
		TOGGLE_EMOJI="🌙",
	},
	light = {
		BG=Color3.fromRGB(240,240,245), HEADER=Color3.fromRGB(225,225,232),
		PANEL=Color3.fromRGB(250,250,255), BODY=Color3.fromRGB(235,235,240),
		BORDER=Color3.fromRGB(160,160,175), HIGHLIGHT=Color3.fromRGB(255,255,255),
		TEXT=Color3.fromRGB(30,30,35), SUBTEXT=Color3.fromRGB(100,100,110),
		CHECKBOX=Color3.fromRGB(220,220,228), CB_HOVER=Color3.fromRGB(200,200,210),
		CB_BORDER=Color3.fromRGB(130,130,150), MARK=Color3.fromRGB(30,100,200),
		TRACK=Color3.fromRGB(190,190,200), FILL=Color3.fromRGB(60,120,210),
		KNOB=Color3.fromRGB(20,70,160), VAL=Color3.fromRGB(30,100,200),
		SCROLL=Color3.fromRGB(150,150,170),
		LOGO_ID="rbxthumb://type=Asset&id=78932354278279&w=420&h=420",
		TOGGLE_EMOJI="☀️",
	},
}
local currentThemeName = "dark"
local T                = THEMES.dark
local themedObjects    = {}
local themedCheckboxes = {}
local themedSliders    = {}
local themedKeybinds   = {}
 
local SliderConfig = {
	Prediction = { Min=0,   Max=1,   Decimals=2 },
	Smoothness  = { Min=1,   Max=10,  Decimals=2 },
	FlySpeed    = { Min=1,   Max=50,  Decimals=2 },
	FOVRadius   = { Min=50,  Max=500, Decimals=0 },
	CamFOV      = { Min=50,  Max=120, Decimals=0 },
}
 
local function make(className, props)
	local obj = Instance.new(className)
	for k, v in pairs(props or {}) do obj[k] = v end
	return obj
end
 
local function tween(obj, t, props)
	TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end
 
local function registerThemed(obj, prop, role)
	table.insert(themedObjects, { obj=obj, prop=prop, role=role })
end
 
local function applyTheme(themeName)
	currentThemeName = themeName
	T = THEMES[themeName]
	for _, entry in ipairs(themedObjects) do pcall(function() entry.obj[entry.prop]=T[entry.role] end) end
	for _, sd in ipairs(themedSliders) do
		pcall(function()
			sd.track.BackgroundColor3=T.TRACK sd.fill.BackgroundColor3=T.FILL
			sd.knob.BackgroundColor3=T.KNOB   sd.valueLabel.TextColor3=T.VAL
		end)
	end
	for _, cd in ipairs(themedCheckboxes) do
		pcall(function()
			cd.box.BackgroundColor3=T.CHECKBOX cd.box.BorderColor3=T.CB_BORDER cd.mark.TextColor3=T.MARK
		end)
	end
	for _, kb in ipairs(themedKeybinds) do
		pcall(function() kb.BackgroundColor3=T.CHECKBOX kb.BorderColor3=T.CB_BORDER kb.TextColor3=T.TEXT end)
	end
end
 
local function formatValue(sliderName, value)
	local config = SliderConfig[sliderName]
	local decimals = config and config.Decimals or 2
	return string.format("%."..tostring(decimals).."f", value)
end
local function valueToAlpha(sliderName, value)
	local config = SliderConfig[sliderName]
	if not config then return math.clamp(value,0,1) end
	return math.clamp((value-config.Min)/(config.Max-config.Min),0,1)
end
local function alphaToValue(sliderName, alpha)
	local config = SliderConfig[sliderName]
	if not config then return math.clamp(alpha,0,1) end
	local value = config.Min+((config.Max-config.Min)*alpha)
	return tonumber(formatValue(sliderName, value))
end
local function inputToKeyName(input)
	if input.UserInputType == Enum.UserInputType.Keyboard then return input.KeyCode.Name
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then return "M1"
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then return "M2"
	elseif input.UserInputType == Enum.UserInputType.MouseButton3 then return "M3"
	end return nil
end
 
-- ScreenGui
local ScreenGui = make("ScreenGui", {
	Name="WaveLite_UI", Parent=GuiParent, ResetOnSpawn=false,
	IgnoreGuiInset=true, ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
})
pcall(function() if syn and syn.protect_gui then syn.protect_gui(ScreenGui) end end)
 
-- Export ScreenGui globally so chat.lua can use it
_G.WaveLite_ScreenGui = ScreenGui
_G.WaveLite_T         = function() return T end
_G.WaveLite_Make      = make
_G.WaveLite_Tween     = tween
_G.WaveLite_RegisterThemed = registerThemed
_G.WaveLite_ThemedCheckboxes = themedCheckboxes
_G.WaveLite_ThemedSliders    = themedSliders
_G.WaveLite_ThemedKeybinds   = themedKeybinds
 
-- Firebase removeSession on close
pcall(function()
	game:BindToClose(function() pcall(function() _G.WaveLite_RemoveSession and _G.WaveLite_RemoveSession() end) end)
end)
pcall(function()
	ScreenGui.AncestryChanged:Connect(function()
		if not ScreenGui:IsDescendantOf(game) then
			pcall(function() _G.WaveLite_RemoveSession and _G.WaveLite_RemoveSession() end)
		end
	end)
end)
 
-- Script ban screen
task.spawn(function()
	task.wait(3)
	if _G.WaveLite_ScriptBanned and _G.WaveLite_ScriptBanned() then
		for _, c in ipairs(ScreenGui:GetChildren()) do c:Destroy() end
		local BanFrame = make("Frame", { Parent=ScreenGui, Size=UDim2.new(1,0,1,0), BackgroundColor3=Color3.fromRGB(10,10,12), BorderSizePixel=0 })
		make("TextLabel", { Parent=BanFrame, Size=UDim2.new(0.6,0,0.2,0), Position=UDim2.new(0.2,0,0.38,0), BackgroundTransparency=1, Text="🚫  You are banned from Wave Lite.", TextColor3=Color3.fromRGB(255,80,80), TextSize=22, Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Center })
		make("TextLabel", { Parent=BanFrame, Size=UDim2.new(0.6,0,0.1,0), Position=UDim2.new(0.2,0,0.54,0), BackgroundTransparency=1, Text="Contact support if you believe this is a mistake.", TextColor3=Color3.fromRGB(130,130,140), TextSize=14, Font=Enum.Font.Gotham, TextXAlignment=Enum.TextXAlignment.Center })
	end
end)
 
-- Layout constants
local MAIN_W   = 380 local MAIN_H   = 175 local HEADER_H = 32
local BODY_PAD = 6   local BOX_GAP  = 6   local ROW_H    = 20
local SIDE_W   = math.floor((MAIN_W-(BODY_PAD*2)-BOX_GAP)/2)
local SIDE_H   = MAIN_H - HEADER_H - 10
local COUNT_INTERVAL = 30
 
local Main = make("Frame", {
	Name="Main", Parent=ScreenGui, Size=UDim2.fromOffset(MAIN_W,MAIN_H),
	Position=UDim2.new(0.5,-MAIN_W/2,0.24,0), BackgroundColor3=T.BG,
	BorderSizePixel=0, ClipsDescendants=false, Active=true,
})
registerThemed(Main,"BackgroundColor3","BG")
pcall(function() local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,8) c.Parent=Main end)
local MainStroke
pcall(function()
	MainStroke=Instance.new("UIStroke") MainStroke.Color=T.BORDER MainStroke.Thickness=1.5 MainStroke.Parent=Main
	registerThemed(MainStroke,"Color","BORDER")
end)
local hlTop  = make("Frame",{Parent=Main,Size=UDim2.new(1,-4,0,1),Position=UDim2.fromOffset(2,2),BackgroundColor3=T.HIGHLIGHT,BorderSizePixel=0})
local hlLeft = make("Frame",{Parent=Main,Size=UDim2.new(0,1,1,-4),Position=UDim2.fromOffset(2,2),BackgroundColor3=T.HIGHLIGHT,BorderSizePixel=0})
registerThemed(hlTop,"BackgroundColor3","HIGHLIGHT") registerThemed(hlLeft,"BackgroundColor3","HIGHLIGHT")
 
local Header = make("Frame", {
	Name="Header",Parent=Main,Size=UDim2.new(1,0,0,HEADER_H),
	BackgroundColor3=T.HEADER,BorderSizePixel=0,ClipsDescendants=false,Active=true,
})
registerThemed(Header,"BackgroundColor3","HEADER")
pcall(function() local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,8) c.Parent=Header end)
local hHlTop = make("Frame",{Parent=Header,Size=UDim2.new(1,0,0,1),BackgroundColor3=T.HIGHLIGHT,BorderSizePixel=0})
local hSep   = make("Frame",{Parent=Header,Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=T.BORDER,BorderSizePixel=0})
registerThemed(hHlTop,"BackgroundColor3","HIGHLIGHT") registerThemed(hSep,"BackgroundColor3","BORDER")
 
local LogoImage = make("ImageLabel",{Name="Logo",Parent=Header,Size=UDim2.fromOffset(22,22),Position=UDim2.fromOffset(8,5),BackgroundTransparency=1,Image=T.LOGO_ID,ScaleType=Enum.ScaleType.Fit})
local TitleWave = make("TextLabel",{Name="TitleWave",Parent=Header,Size=UDim2.fromOffset(62,22),Position=UDim2.fromOffset(34,4),BackgroundTransparency=1,Text="WAVE",TextColor3=T.TEXT,TextSize=18,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center})
registerThemed(TitleWave,"TextColor3","TEXT")
local TitleLite = make("TextLabel",{Name="TitleLite",Parent=Header,Size=UDim2.fromOffset(28,22),Position=UDim2.fromOffset(96,4),BackgroundTransparency=1,Text="LITE",TextColor3=T.FILL,TextSize=11,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center})
registerThemed(TitleLite,"TextColor3","FILL")
 
local PILL_W=64 local PILL_H=20
local CountPill = make("Frame",{Name="CountPill",Parent=Header,Size=UDim2.fromOffset(PILL_W,PILL_H),Position=UDim2.new(0.5,-PILL_W/2,0.5,-PILL_H/2),BackgroundColor3=T.CHECKBOX,BorderSizePixel=0,ZIndex=5})
registerThemed(CountPill,"BackgroundColor3","CHECKBOX")
make("UICorner",{Parent=CountPill,CornerRadius=UDim.new(0,6)})
pcall(function() local ps=Instance.new("UIStroke") ps.Color=T.FILL ps.Thickness=1 ps.Transparency=0.55 ps.Parent=CountPill registerThemed(ps,"Color","FILL") end)
make("TextLabel",{Name="UserIcon",Parent=CountPill,Size=UDim2.fromOffset(14,PILL_H),Position=UDim2.fromOffset(6,0),BackgroundTransparency=1,Text="👤",TextSize=11,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,ZIndex=6})
local UserCountLabel = make("TextLabel",{Name="UserCount",Parent=CountPill,Size=UDim2.fromOffset(38,PILL_H),Position=UDim2.fromOffset(22,0),BackgroundTransparency=1,Text="...",TextColor3=T.TEXT,TextSize=11,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,ZIndex=6})
registerThemed(UserCountLabel,"TextColor3","TEXT")
 
task.spawn(function()
	task.wait(2)
	while true do
		pcall(function()
			if _G.WaveLite_FetchCount then UserCountLabel.Text = tostring(_G.WaveLite_FetchCount()) end
		end)
		task.wait(COUNT_INTERVAL)
	end
end)
 
local GearBtn = make("TextButton",{Name="ChatGearToggle",Parent=Header,Size=UDim2.fromOffset(26,26),Position=UDim2.new(1,-58,0,3),BackgroundTransparency=1,Text="💬",TextSize=14,Font=Enum.Font.GothamBold,AutoButtonColor=false,ZIndex=10})
GearBtn.MouseEnter:Connect(function() GearBtn.BackgroundTransparency=0.8 GearBtn.BackgroundColor3=T.CB_HOVER end)
GearBtn.MouseLeave:Connect(function() GearBtn.BackgroundTransparency=1 end)
 
local ThemeBtn = make("TextButton",{Name="ThemeToggle",Parent=Header,Size=UDim2.fromOffset(26,26),Position=UDim2.new(1,-30,0,3),BackgroundTransparency=1,Text=T.TOGGLE_EMOJI,TextSize=15,Font=Enum.Font.GothamBold,AutoButtonColor=false,ZIndex=10})
ThemeBtn.MouseButton1Click:Connect(function()
	local next = (currentThemeName=="dark") and "light" or "dark"
	applyTheme(next) LogoImage.Image=T.LOGO_ID ThemeBtn.Text=T.TOGGLE_EMOJI
end)
ThemeBtn.MouseEnter:Connect(function() ThemeBtn.BackgroundTransparency=0.8 ThemeBtn.BackgroundColor3=T.CB_HOVER end)
ThemeBtn.MouseLeave:Connect(function() ThemeBtn.BackgroundTransparency=1 end)
 
local Body = make("Frame",{Name="Body",Parent=Main,Size=UDim2.new(1,0,1,-HEADER_H),Position=UDim2.fromOffset(0,HEADER_H),BackgroundColor3=T.BODY,BorderSizePixel=0})
registerThemed(Body,"BackgroundColor3","BODY")
pcall(function() local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,8) c.Parent=Body end)
 
local function makePanel(parent, xPos)
	local Holder = make("Frame",{Parent=parent,Size=UDim2.fromOffset(SIDE_W,SIDE_H),Position=UDim2.fromOffset(xPos,4),BackgroundColor3=T.PANEL,BorderColor3=T.BORDER,BorderSizePixel=1,ClipsDescendants=true})
	registerThemed(Holder,"BackgroundColor3","PANEL") registerThemed(Holder,"BorderColor3","BORDER")
	local pHl = make("Frame",{Parent=Holder,Size=UDim2.new(1,-2,0,1),Position=UDim2.fromOffset(1,1),BackgroundColor3=T.HIGHLIGHT,BorderSizePixel=0})
	registerThemed(pHl,"BackgroundColor3","HIGHLIGHT")
	local Scroll = make("ScrollingFrame",{Parent=Holder,Size=UDim2.new(1,-2,1,-2),Position=UDim2.fromOffset(1,1),BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.new(),ScrollBarThickness=4,ScrollBarImageColor3=T.SCROLL,ScrollingDirection=Enum.ScrollingDirection.Y,AutomaticCanvasSize=Enum.AutomaticSize.None})
	registerThemed(Scroll,"ScrollBarImageColor3","SCROLL")
	make("UIPadding",{Parent=Scroll,PaddingTop=UDim.new(0,4),PaddingBottom=UDim.new(0,4),PaddingLeft=UDim.new(0,5),PaddingRight=UDim.new(0,5)})
	local Layout = make("UIListLayout",{Parent=Scroll,Padding=UDim.new(0,2),SortOrder=Enum.SortOrder.LayoutOrder})
	Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		Scroll.CanvasSize = UDim2.fromOffset(0, Layout.AbsoluteContentSize.Y+8)
	end)
	return Holder, Scroll, Layout
end
 
local LeftPanel,  LeftScroll  = makePanel(Body, BODY_PAD)
local RightPanel, RightScroll = makePanel(Body, BODY_PAD+SIDE_W+BOX_GAP)
 
local function makeRow(parent)
	return make("Frame",{Parent=parent,Size=UDim2.new(1,-2,0,ROW_H),BackgroundTransparency=1,BorderSizePixel=0})
end
local function makeLabel(parent, text, x, w)
	local lbl = make("TextLabel",{Parent=parent,Size=UDim2.fromOffset(w or 90,15),Position=UDim2.fromOffset(x,2),BackgroundTransparency=1,Text=text,TextColor3=T.TEXT,TextSize=11,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center})
	registerThemed(lbl,"TextColor3","TEXT") return lbl
end
local function makeCheckbox(parent, stateName, x, callback)
	local Box = make("TextButton",{Parent=parent,Size=UDim2.fromOffset(15,15),Position=UDim2.fromOffset(x,2),BackgroundColor3=T.CHECKBOX,BorderColor3=T.CB_BORDER,BorderSizePixel=1,Text="",AutoButtonColor=false})
	local cbHl = make("Frame",{Parent=Box,Size=UDim2.new(1,-2,0,1),Position=UDim2.fromOffset(1,1),BackgroundColor3=T.HIGHLIGHT,BorderSizePixel=0})
	registerThemed(cbHl,"BackgroundColor3","HIGHLIGHT")
	local Mark = make("TextLabel",{Parent=Box,Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text=State.Toggles[stateName] and "×" or "",TextColor3=T.MARK,TextSize=13,Font=Enum.Font.GothamBold})
	table.insert(themedCheckboxes,{box=Box,mark=Mark,stateName=stateName})
	Box.MouseEnter:Connect(function() tween(Box,0.08,{BackgroundColor3=T.CB_HOVER}) end)
	Box.MouseLeave:Connect(function() tween(Box,0.08,{BackgroundColor3=T.CHECKBOX}) end)
	Box.MouseButton1Click:Connect(function()
		State.Toggles[stateName] = not State.Toggles[stateName]
		Mark.Text = State.Toggles[stateName] and "×" or ""
		if callback then callback(State.Toggles[stateName]) end
	end)
	return Box
end
local waitingForKey = nil
local function makeKeybindBox(parent, stateName, x)
	local Box = make("TextButton",{Parent=parent,Size=UDim2.fromOffset(30,18),Position=UDim2.fromOffset(x,1),BackgroundColor3=T.CHECKBOX,BorderColor3=T.CB_BORDER,BorderSizePixel=1,Text=State.Keybinds[stateName] or "...",TextColor3=T.TEXT,TextSize=10,Font=Enum.Font.GothamBold,AutoButtonColor=false})
	local kbHl = make("Frame",{Parent=Box,Size=UDim2.new(1,-2,0,1),Position=UDim2.fromOffset(1,1),BackgroundColor3=T.HIGHLIGHT,BorderSizePixel=0})
	registerThemed(kbHl,"BackgroundColor3","HIGHLIGHT")
	table.insert(themedKeybinds,Box)
	Box.MouseEnter:Connect(function() tween(Box,0.08,{BackgroundColor3=T.CB_HOVER}) end)
	Box.MouseLeave:Connect(function() tween(Box,0.08,{BackgroundColor3=T.CHECKBOX}) end)
	Box.MouseButton1Click:Connect(function()
		if waitingForKey and waitingForKey.Box ~= Box then waitingForKey.Box.Text = State.Keybinds[waitingForKey.Name] or "..." end
		if waitingForKey and waitingForKey.Box == Box then Box.Text = State.Keybinds[stateName] or "..." waitingForKey=nil return end
		waitingForKey = {Name=stateName, Box=Box} Box.Text="KEY"
	end)
	return Box
end
local activeSlider = nil
local function makeSlider(parent, sliderName)
	local rawValue = State.Sliders[sliderName]
	local alpha    = valueToAlpha(sliderName, rawValue)
	local ValueLabel = make("TextLabel",{Parent=parent,Size=UDim2.fromOffset(31,15),Position=UDim2.fromOffset(72,2),BackgroundTransparency=1,Text=formatValue(sliderName,rawValue),TextColor3=T.VAL,TextSize=10,Font=Enum.Font.Code,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center})
	local Track = make("TextButton",{Parent=parent,Size=UDim2.fromOffset(50,8),Position=UDim2.fromOffset(106,5),BackgroundColor3=T.TRACK,BorderSizePixel=0,Text="",AutoButtonColor=false})
	local Fill  = make("Frame",{Parent=Track,Size=UDim2.new(alpha,0,1,0),BackgroundColor3=T.FILL,BorderSizePixel=0})
	local Knob  = make("Frame",{Parent=Track,Size=UDim2.fromOffset(6,14),Position=UDim2.new(alpha,-3,0.5,-7),BackgroundColor3=T.KNOB,BorderSizePixel=0})
	table.insert(themedSliders,{track=Track,fill=Fill,knob=Knob,valueLabel=ValueLabel})
	local function setFromX(mouseX)
		local relative = math.clamp((mouseX-Track.AbsolutePosition.X)/Track.AbsoluteSize.X,0,1)
		local value    = alphaToValue(sliderName, relative)
		State.Sliders[sliderName]=value ValueLabel.Text=formatValue(sliderName,value)
		Fill.Size=UDim2.new(relative,0,1,0) Knob.Position=UDim2.new(relative,-3,0.5,-7)
	end
	Track.InputBegan:Connect(function(input)
		if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
			activeSlider={Set=setFromX} setFromX(input.Position.X)
		end
	end)
	return Track
end
 
local AIM_PART_OPTIONS = {"HumanoidRootPart","Head"}
local AIM_PART_LABELS  = {"Root","Head"}
local activeDropdown   = nil
local camLockedTarget  = nil
local function closeDropdown()
	if activeDropdown then pcall(function() activeDropdown:Destroy() end) activeDropdown=nil end
end
local function makeAimPartDropdown(parent, x)
	local Btn = make("TextButton",{Parent=parent,Size=UDim2.fromOffset(46,18),Position=UDim2.fromOffset(x,1),BackgroundColor3=T.CHECKBOX,BorderColor3=T.CB_BORDER,BorderSizePixel=1,Text="Root",TextColor3=T.TEXT,TextSize=10,Font=Enum.Font.GothamBold,AutoButtonColor=false,ZIndex=2})
	local kbHl = make("Frame",{Parent=Btn,Size=UDim2.new(1,-2,0,1),Position=UDim2.fromOffset(1,1),BackgroundColor3=T.HIGHLIGHT,BorderSizePixel=0,ZIndex=3})
	registerThemed(kbHl,"BackgroundColor3","HIGHLIGHT")
	table.insert(themedKeybinds,Btn)
	Btn.MouseEnter:Connect(function() tween(Btn,0.08,{BackgroundColor3=T.CB_HOVER}) end)
	Btn.MouseLeave:Connect(function() tween(Btn,0.08,{BackgroundColor3=T.CHECKBOX}) end)
	Btn.MouseButton1Click:Connect(function()
		if activeDropdown then closeDropdown() return end
		local absPos=Btn.AbsolutePosition local ITEM_H=18 local POP_W=60
		local Backdrop = make("TextButton",{Parent=ScreenGui,Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,BorderSizePixel=0,Text="",ZIndex=19})
		local Popup = make("Frame",{Parent=ScreenGui,Size=UDim2.fromOffset(POP_W,ITEM_H*#AIM_PART_OPTIONS+2),Position=UDim2.fromOffset(absPos.X-8,absPos.Y+20),BackgroundColor3=T.PANEL,BorderColor3=T.BORDER,BorderSizePixel=1,ZIndex=20})
		registerThemed(Popup,"BackgroundColor3","PANEL") registerThemed(Popup,"BorderColor3","BORDER")
		activeDropdown=Popup
		Backdrop.MouseButton1Click:Connect(function() closeDropdown() pcall(function() Backdrop:Destroy() end) end)
		for i, partName in ipairs(AIM_PART_OPTIONS) do
			local isSelected = State.AimPart==partName
			local Item = make("TextButton",{Parent=Popup,Size=UDim2.fromOffset(POP_W-2,ITEM_H),Position=UDim2.fromOffset(1,1+(i-1)*ITEM_H),BackgroundColor3=isSelected and T.CB_HOVER or T.PANEL,BorderSizePixel=0,Text=AIM_PART_LABELS[i],TextColor3=isSelected and T.MARK or T.TEXT,TextSize=10,Font=Enum.Font.GothamBold,AutoButtonColor=false,ZIndex=21})
			Item.MouseEnter:Connect(function() tween(Item,0.06,{BackgroundColor3=T.CB_HOVER}) end)
			Item.MouseLeave:Connect(function() tween(Item,0.06,{BackgroundColor3=(State.AimPart==partName) and T.CB_HOVER or T.PANEL}) end)
			Item.MouseButton1Click:Connect(function()
				State.AimPart=partName Btn.Text=AIM_PART_LABELS[i] camLockedTarget=nil
				closeDropdown() pcall(function() Backdrop:Destroy() end)
			end)
		end
	end)
	return Btn
end
 
-- Populate left panel
do
	local row
	row=makeRow(LeftScroll) makeLabel(row,"Prediction",0,72) makeSlider(row,"Prediction")
	row=makeRow(LeftScroll) makeLabel(row,"Smoothness",0,72) makeSlider(row,"Smoothness")
	row=makeRow(LeftScroll) makeLabel(row,"CamLock Toggle",0,108) makeKeybindBox(row,"CamLockToggle",124)
	row=makeRow(LeftScroll) makeLabel(row,"Aim Part",0,72) makeAimPartDropdown(row,72)
	row=makeRow(LeftScroll) makeLabel(row,"FOV",0,72) makeSlider(row,"FOVRadius")
	row=makeRow(LeftScroll) makeLabel(row,"FOV Circle",0,90) makeCheckbox(row,"FOVCircle",139)
	row=makeRow(LeftScroll) makeLabel(row,"Lock Dot",0,90) makeCheckbox(row,"LockIndicator",139)
	row=makeRow(LeftScroll) makeLabel(row,"Team Check",0,90) makeCheckbox(row,"TeamCheck",139)
	row=makeRow(LeftScroll) makeLabel(row,"Wall Check",0,90) makeCheckbox(row,"WallCheck",139)
end
-- Populate right panel
do
	local row
	row=makeRow(RightScroll) makeLabel(row,"Fly Toggle",0,84) makeKeybindBox(row,"FlyToggle",139)
	row=makeRow(RightScroll) makeLabel(row,"Fly Speed",0,72) makeSlider(row,"FlySpeed")
	row=makeRow(RightScroll) makeLabel(row,"Name ESP",0,84) makeCheckbox(row,"NameESP",144,function(on) _G.WaveLite_NameESP_Toggle(on) end)
	row=makeRow(RightScroll) makeLabel(row,"Box ESP",0,84) makeCheckbox(row,"BoxESP",144,function(on) _G.WaveLite_BoxESP_Toggle(on) end)
	row=makeRow(RightScroll) makeLabel(row,"Health Bars",0,84) makeCheckbox(row,"HealthBars",144)
	row=makeRow(RightScroll) makeLabel(row,"Tracers",0,84) makeCheckbox(row,"Tracers",144,function(on) _G.WaveLite_Tracers_Toggle(on) end)
	row=makeRow(RightScroll) makeLabel(row,"No Fog",0,84) makeCheckbox(row,"NoFog",144,function(on) _G.WaveLite_NoFog_Toggle(on) end)
	row=makeRow(RightScroll) makeLabel(row,"Maxzoom",0,84) makeCheckbox(row,"Maxzoom",144,function(on) _G.WaveLite_Maxzoom_Toggle(on) end)
	row=makeRow(RightScroll) makeLabel(row,"Noclip",0,84) makeCheckbox(row,"Noclip",144,function(on) _G.WaveLite_Noclip_Toggle(on) end)
	row=makeRow(RightScroll) makeLabel(row,"Click TP",0,84) makeCheckbox(row,"ClickTP",144,function(on)
		if on then _G.WaveLite_ClickTP_Create() else _G.WaveLite_ClickTP_Remove() end
	end)
	row=makeRow(RightScroll) makeLabel(row,"Cam FOV",0,84) makeCheckbox(row,"CamFOV",144,function(on) _G.WaveLite_CamFOV_Toggle(on) end)
	row=makeRow(RightScroll) makeLabel(row,"FOV",0,72) makeSlider(row,"CamFOV")
end
 
-- Main drag
local dragging=false local dragStart=nil local startPos=nil
Header.InputBegan:Connect(function(input)
	if waitingForKey then return end
	if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
		dragging=true dragStart=input.Position startPos=Main.Position
		input.Changed:Connect(function() if input.UserInputState==Enum.UserInputState.End then dragging=false end end)
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if activeSlider then
		if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then activeSlider.Set(input.Position.X) end
		return
	end
	if dragging and dragStart and startPos then
		if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then
			local delta=input.Position-dragStart
			Main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
		end
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
		activeSlider=nil dragging=false
	end
end)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if waitingForKey then
		if input.KeyCode==Enum.KeyCode.Escape then waitingForKey.Box.Text=State.Keybinds[waitingForKey.Name] or "..." waitingForKey=nil return end
		local name=inputToKeyName(input) if not name then return end
		State.Keybinds[waitingForKey.Name]=name waitingForKey.Box.Text=name waitingForKey=nil return
	end
	if gameProcessed then return end
	local keyName=inputToKeyName(input) if not keyName then return end
	if State.Keybinds.FlyToggle     and keyName==State.Keybinds.FlyToggle     then _G.WaveLite_Fly_Toggle() end
	if State.Keybinds.CamLockToggle and keyName==State.Keybinds.CamLockToggle then _G.WaveLite_CamLock_Toggle() end
end)
 
-- Export GearBtn toggle for chat.lua
_G.WaveLite_GearBtn = GearBtn
