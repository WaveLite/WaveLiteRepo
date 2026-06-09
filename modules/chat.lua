local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local LocalPlayer      = Players.LocalPlayer
 
local State      = _G.WaveLiteState
local ScreenGui  = _G.WaveLite_ScreenGui
local GearBtn    = _G.WaveLite_GearBtn
 
local function T()    return _G.WaveLite_T() end
local function make() return _G.WaveLite_Make end
local function tween(obj, t, props)
	TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end
local mkObj = _G.WaveLite_Make
local function registerThemed(obj, prop, role) _G.WaveLite_RegisterThemed(obj, prop, role) end
 
local DB_URL    = "https://wavelite-counter-default-rtdb.firebaseio.com/"
local myUsername = LocalPlayer.Name
local myDisplay  = LocalPlayer.DisplayName
 
local function httpRequest(method, url, body)
	local res = nil
	pcall(function()
		local opts = { Url=url, Method=method, Headers={["Content-Type"]="application/json"} }
		if body then opts.Body = body end
		if syn and syn.request then res=syn.request(opts)
		elseif request then res=request(opts)
		elseif http and http.request then res=http.request(opts) end
	end)
	return res
end
local function jsonEscape(s)
	s=s:gsub('\\','\\\\') s=s:gsub('"','\\"') s=s:gsub('\n','\\n') s=s:gsub('\r','\\r') return s
end
 
local myRole            = nil
local chatBanned        = false
local scriptBanned      = false
local spamStrikes       = 0
local localTimeoutUntil = 0
local recentMessages    = {}
local lastSentText      = ""
local SESSION_ID        = tostring(os.time())..tostring(math.random(1000,9999))
 
local BLOCKED_PATTERNS = {
	"child porn","cp link","csam","loli","shota","rape video","snuff film",
	"how to make.*bomb","how to.*explosiv","ddos.*ip","dox.*address",
	"buy.*drugs.*ship","sell.*fent","sell.*meth","hire.*hitman","kill.*for money",
}
local function containsBlockedContent(text)
	local lower = text:lower()
	for _, pattern in ipairs(BLOCKED_PATTERNS) do
		if lower:find(pattern) then return true end
	end
	return false
end
local function isGibberish(text)
	if text:find("(.)%1%1%1%1%1%1%1") then return true end
	local stripped = text:lower():gsub("[^a-z]","")
	if #stripped > 6 then
		local vowels = stripped:gsub("[^aeiou]","")
		if #vowels == 0 then return true end
		if (#vowels/#stripped) < 0.05 and #stripped > 8 then return true end
	end
	return false
end
local function isBurstSpam()
	local now = os.time()
	local fresh = {}
	for _, t in ipairs(recentMessages) do if now-t < 10 then table.insert(fresh, t) end end
	recentMessages = fresh
	return #recentMessages >= 4
end
 
-- Load moderation status
task.spawn(function()
	pcall(function()
		local banRes = httpRequest("GET", DB_URL.."script_bans/"..myUsername..".json", nil)
		if banRes and banRes.Body and banRes.Body~="null" and banRes.Body~="" then
			if banRes.Body:match('"banned"%s*:%s*(true)') then scriptBanned=true end
		end
		local chatBanRes = httpRequest("GET", DB_URL.."bans/"..myUsername..".json", nil)
		if chatBanRes and chatBanRes.Body and chatBanRes.Body~="null" and chatBanRes.Body~="" then
			if chatBanRes.Body:match('"banned"%s*:%s*(true)') then chatBanned=true end
		end
		local modRes = httpRequest("GET", DB_URL.."mods/"..myUsername..".json", nil)
		if modRes and modRes.Body and modRes.Body~="null" and modRes.Body~="" then
			local role = modRes.Body:match('"role"%s*:%s*"([^"]+)"')
			if role then myRole=role end
		end
		local toRes = httpRequest("GET", DB_URL.."timeouts/"..myUsername..".json", nil)
		if toRes and toRes.Body and toRes.Body~="null" and toRes.Body~="" then
			local until_ = toRes.Body:match('"until"%s*:%s*(%d+)')
			local strikes = toRes.Body:match('"strikes"%s*:%s*(%d+)')
			if until_ then localTimeoutUntil=tonumber(until_) end
			if strikes then spamStrikes=tonumber(strikes) end
		end
	end)
end)
 
local function saveTimeout(until_, reason, strikes)
	pcall(function()
		httpRequest("PUT", DB_URL.."timeouts/"..myUsername..".json",
			'{"until":'..tostring(until_)..',"reason":"'..jsonEscape(reason)..'","strikes":'..tostring(strikes)..'}')
	end)
end
local function modTimeoutUser(username, seconds, reason)
	pcall(function()
		local until_ = os.time()+seconds local strikes=0
		local toRes = httpRequest("GET", DB_URL.."timeouts/"..username..".json", nil)
		if toRes and toRes.Body and toRes.Body~="null" and toRes.Body~="" then
			local s=toRes.Body:match('"strikes"%s*:%s*(%d+)') if s then strikes=tonumber(s) end
		end
		httpRequest("PUT", DB_URL.."timeouts/"..username..".json",
			'{"until":'..tostring(until_)..',"reason":"'..jsonEscape(reason)..'","strikes":'..tostring(strikes)..'}')
	end)
end
local function modChatBanUser(username, reason)
	pcall(function() httpRequest("PUT", DB_URL.."bans/"..username..".json", '{"banned":true,"reason":"'..jsonEscape(reason)..'"}') end)
end
local function modScriptBanUser(username, reason)
	pcall(function() httpRequest("PUT", DB_URL.."script_bans/"..username..".json", '{"banned":true,"reason":"'..jsonEscape(reason)..'"}') end)
end
local function modDeleteMessage(msgId)
	pcall(function() httpRequest("PUT", DB_URL.."deleted_messages/"..msgId..".json", '{"deleted":true}') end)
end
local function fetchDeletedIds()
	local deleted = {}
	pcall(function()
		local res = httpRequest("GET", DB_URL.."deleted_messages.json", nil)
		if not res or not res.Body or res.Body=="null" or res.Body=="" then return end
		for id in res.Body:gmatch('"([^"]+)":%{"deleted":true%}') do deleted[id]=true end
	end)
	return deleted
end
 
-- Chat layout constants
local CHAT_W        = 220 local CHAT_H        = 260
local CHAT_HEADER_H = 26  local CHAT_INPUT_H  = 26
local CHAT_MARGIN   = 14  local MAX_MESSAGES  = 30
local PILL_W2=48 local PILL_H2=22
local chatVisible=false local chatMinimized=false local chatLocked=true local chatHasNotif=false
local chatDefaultPos
local Tc = _G.WaveLite_T()
 
local ChatPanel = mkObj("Frame",{
	Name="ChatPanel",Parent=ScreenGui,Size=UDim2.fromOffset(CHAT_W,CHAT_H),
	Position=UDim2.new(1,-(CHAT_W+CHAT_MARGIN),1,-(CHAT_H+CHAT_MARGIN)),
	BackgroundColor3=Tc.BG,BorderSizePixel=0,ClipsDescendants=false,Active=true,Visible=false,ZIndex=15,
})
chatDefaultPos = ChatPanel.Position
registerThemed(ChatPanel,"BackgroundColor3","BG")
pcall(function() local cc=Instance.new("UICorner") cc.CornerRadius=UDim.new(0,10) cc.Parent=ChatPanel end)
pcall(function()
	local cs=Instance.new("UIStroke") cs.Color=Tc.BORDER cs.Thickness=1.5 cs.Parent=ChatPanel
	registerThemed(cs,"Color","BORDER")
end)
local cpHlTop  = mkObj("Frame",{Parent=ChatPanel,Size=UDim2.new(1,-4,0,1),Position=UDim2.fromOffset(2,2),BackgroundColor3=Tc.HIGHLIGHT,BorderSizePixel=0,ZIndex=16})
local cpHlLeft = mkObj("Frame",{Parent=ChatPanel,Size=UDim2.new(0,1,1,-4),Position=UDim2.fromOffset(2,2),BackgroundColor3=Tc.HIGHLIGHT,BorderSizePixel=0,ZIndex=16})
registerThemed(cpHlTop,"BackgroundColor3","HIGHLIGHT") registerThemed(cpHlLeft,"BackgroundColor3","HIGHLIGHT")
 
local ChatHeader = mkObj("Frame",{Parent=ChatPanel,Size=UDim2.new(1,0,0,CHAT_HEADER_H),BackgroundColor3=Tc.HEADER,BorderSizePixel=0,ZIndex=16})
registerThemed(ChatHeader,"BackgroundColor3","HEADER")
pcall(function() local chc=Instance.new("UICorner") chc.CornerRadius=UDim.new(0,10) chc.Parent=ChatHeader end)
mkObj("Frame",{Parent=ChatHeader,Size=UDim2.new(1,0,0,1),BackgroundColor3=Tc.HIGHLIGHT,BorderSizePixel=0,ZIndex=17})
local chSep = mkObj("Frame",{Parent=ChatHeader,Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=Tc.BORDER,BorderSizePixel=0,ZIndex=17})
registerThemed(chSep,"BackgroundColor3","BORDER")
 
local MinimizeBtn = mkObj("TextButton",{Parent=ChatHeader,Size=UDim2.fromOffset(24,24),Position=UDim2.fromOffset(2,1),BackgroundTransparency=1,Text="—",TextColor3=Tc.SUBTEXT,TextSize=11,Font=Enum.Font.GothamBold,AutoButtonColor=false,ZIndex=18})
registerThemed(MinimizeBtn,"TextColor3","SUBTEXT")
MinimizeBtn.MouseEnter:Connect(function() MinimizeBtn.TextColor3=_G.WaveLite_T().TEXT end)
MinimizeBtn.MouseLeave:Connect(function() MinimizeBtn.TextColor3=_G.WaveLite_T().SUBTEXT end)
mkObj("TextLabel",{Parent=ChatHeader,Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="CHAT",TextColor3=Tc.FILL,TextSize=11,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Center,ZIndex=17})
local LockBtn = mkObj("TextButton",{Parent=ChatHeader,Size=UDim2.fromOffset(24,24),Position=UDim2.new(1,-26,0,1),BackgroundTransparency=1,Text="🔒",TextSize=12,Font=Enum.Font.GothamBold,AutoButtonColor=false,ZIndex=18})
 
local MyUserStrip = mkObj("Frame",{Parent=ChatPanel,Size=UDim2.new(1,-4,0,20),Position=UDim2.fromOffset(2,CHAT_HEADER_H+3),BackgroundColor3=Tc.CHECKBOX,BorderSizePixel=0,ZIndex=16})
registerThemed(MyUserStrip,"BackgroundColor3","CHECKBOX")
pcall(function() local mc=Instance.new("UICorner") mc.CornerRadius=UDim.new(0,4) mc.Parent=MyUserStrip end)
mkObj("TextLabel",{Parent=MyUserStrip,Size=UDim2.fromOffset(14,20),Position=UDim2.fromOffset(4,0),BackgroundTransparency=1,Text="👤",TextSize=10,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,ZIndex=17})
mkObj("TextLabel",{Parent=MyUserStrip,Size=UDim2.new(1,-20,1,0),Position=UDim2.fromOffset(18,0),BackgroundTransparency=1,Text=myDisplay,TextColor3=Tc.TEXT,TextSize=10,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,ZIndex=17})
 
local CHAT_BODY_TOP = CHAT_HEADER_H+26+4
local CHAT_BODY_H   = CHAT_H-CHAT_BODY_TOP-CHAT_INPUT_H-6
local ChatLog = mkObj("ScrollingFrame",{Parent=ChatPanel,Size=UDim2.new(1,-4,0,CHAT_BODY_H),Position=UDim2.fromOffset(2,CHAT_BODY_TOP),BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.new(),ScrollBarThickness=3,ScrollBarImageColor3=Tc.SCROLL,ScrollingDirection=Enum.ScrollingDirection.Y,AutomaticCanvasSize=Enum.AutomaticSize.None,ZIndex=16})
registerThemed(ChatLog,"ScrollBarImageColor3","SCROLL")
mkObj("UIPadding",{Parent=ChatLog,PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,4),PaddingTop=UDim.new(0,2),PaddingBottom=UDim.new(0,2)})
local ChatLayout = mkObj("UIListLayout",{Parent=ChatLog,Padding=UDim.new(0,2),SortOrder=Enum.SortOrder.LayoutOrder})
ChatLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	ChatLog.CanvasSize=UDim2.fromOffset(0,ChatLayout.AbsoluteContentSize.Y+4)
	ChatLog.CanvasPosition=Vector2.new(0,math.max(0,ChatLayout.AbsoluteContentSize.Y-ChatLog.AbsoluteSize.Y+4))
end)
 
local ChatInputFrame = mkObj("Frame",{Parent=ChatPanel,Size=UDim2.new(1,-6,0,CHAT_INPUT_H),Position=UDim2.new(0,3,1,-(CHAT_INPUT_H+4)),BackgroundColor3=Tc.CHECKBOX,BorderSizePixel=0,ZIndex=16})
registerThemed(ChatInputFrame,"BackgroundColor3","CHECKBOX")
pcall(function() local ic=Instance.new("UICorner") ic.CornerRadius=UDim.new(0,8) ic.Parent=ChatInputFrame end)
pcall(function()
	local is=Instance.new("UIStroke") is.Color=Tc.CB_BORDER is.Thickness=1 is.Parent=ChatInputFrame
	registerThemed(is,"Color","CB_BORDER")
end)
local ChatInput = mkObj("TextBox",{Parent=ChatInputFrame,Size=UDim2.new(1,-34,1,0),Position=UDim2.fromOffset(0,0),BackgroundTransparency=1,Text="",PlaceholderText="Enter text here...",PlaceholderColor3=Tc.SUBTEXT,TextColor3=Tc.TEXT,TextSize=10,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,ClearTextOnFocus=false,TextWrapped=false,ZIndex=17})
mkObj("UIPadding",{Parent=ChatInput,PaddingLeft=UDim.new(0,7)})
registerThemed(ChatInput,"TextColor3","TEXT") registerThemed(ChatInput,"PlaceholderColor3","SUBTEXT")
ChatInput:GetPropertyChangedSignal("Text"):Connect(function()
	if #ChatInput.Text > 60 then ChatInput.Text=ChatInput.Text:sub(1,60) end
end)
local SendBtn = mkObj("TextButton",{Parent=ChatInputFrame,Size=UDim2.fromOffset(30,CHAT_INPUT_H-4),Position=UDim2.new(1,-32,0,2),BackgroundColor3=Tc.FILL,BorderSizePixel=0,Text="↑",TextColor3=Color3.fromRGB(255,255,255),TextSize=13,Font=Enum.Font.GothamBold,AutoButtonColor=false,ZIndex=17})
registerThemed(SendBtn,"BackgroundColor3","FILL")
pcall(function() local sc=Instance.new("UICorner") sc.CornerRadius=UDim.new(0,6) sc.Parent=SendBtn end)
SendBtn.MouseEnter:Connect(function() tween(SendBtn,0.08,{BackgroundColor3=_G.WaveLite_T().KNOB}) end)
SendBtn.MouseLeave:Connect(function() tween(SendBtn,0.08,{BackgroundColor3=_G.WaveLite_T().FILL}) end)
 
local ChatWarnLabel = mkObj("TextLabel",{Parent=ChatPanel,Size=UDim2.new(1,-6,0,18),Position=UDim2.new(0,3,1,-(CHAT_INPUT_H+26)),BackgroundTransparency=1,Text="",TextColor3=Color3.fromRGB(255,80,80),TextSize=9,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Center,TextWrapped=true,ZIndex=17,Visible=false})
local warnThread = nil
local function showChatWarning(msg)
	ChatWarnLabel.Text=msg ChatWarnLabel.Visible=true
	if warnThread then task.cancel(warnThread) end
	warnThread = task.delay(4, function() ChatWarnLabel.Visible=false ChatWarnLabel.Text="" end)
end
 
local MinimizedPill = mkObj("TextButton",{Name="MinimizedPill",Parent=ScreenGui,Size=UDim2.fromOffset(PILL_W2,PILL_H2),Position=UDim2.new(1,-(PILL_W2+CHAT_MARGIN),1,-(PILL_H2+CHAT_MARGIN)),BackgroundColor3=Tc.HEADER,BorderSizePixel=0,Text="💬",TextSize=12,Font=Enum.Font.GothamBold,AutoButtonColor=false,Visible=false,ZIndex=15})
registerThemed(MinimizedPill,"BackgroundColor3","HEADER")
pcall(function() local mc=Instance.new("UICorner") mc.CornerRadius=UDim.new(0,10) mc.Parent=MinimizedPill end)
pcall(function()
	local ms=Instance.new("UIStroke") ms.Color=Tc.BORDER ms.Thickness=1.5 ms.Parent=MinimizedPill
	registerThemed(ms,"Color","BORDER")
end)
local NotifDot = mkObj("Frame",{Parent=MinimizedPill,Size=UDim2.fromOffset(8,8),Position=UDim2.new(1,-2,0,-2),BackgroundColor3=Color3.fromRGB(255,60,60),BorderSizePixel=0,Visible=false,ZIndex=16})
pcall(function() local nc=Instance.new("UICorner") nc.CornerRadius=UDim.new(1,0) nc.Parent=NotifDot end)
 
-- Mod popup
local activePopup = nil
local function closePopup()
	if activePopup then pcall(function() activePopup:Destroy() end) activePopup=nil end
end
local function showModPopup(targetUsername, targetDisplay, msgId)
	closePopup()
	if myRole~="owner" and myRole~="mod" then return end
	local POP_W=190 local POP_H=msgId and 200 or 180
	local Backdrop = mkObj("TextButton",{Parent=ScreenGui,Size=UDim2.new(1,0,1,0),BackgroundTransparency=0.4,BackgroundColor3=Color3.fromRGB(0,0,0),BorderSizePixel=0,Text="",ZIndex=28})
	local Tl = _G.WaveLite_T()
	local Popup = mkObj("Frame",{Parent=ScreenGui,Size=UDim2.fromOffset(POP_W,POP_H),Position=UDim2.new(0.5,-POP_W/2,0.5,-POP_H/2),BackgroundColor3=Tl.PANEL,BorderSizePixel=0,ZIndex=29})
	activePopup=Popup
	pcall(function() local pc=Instance.new("UICorner") pc.CornerRadius=UDim.new(0,8) pc.Parent=Popup end)
	pcall(function() local ps=Instance.new("UIStroke") ps.Color=Tl.BORDER ps.Thickness=1.5 ps.Parent=Popup end)
	mkObj("TextLabel",{Parent=Popup,Size=UDim2.new(1,-8,0,22),Position=UDim2.fromOffset(4,4),BackgroundTransparency=1,Text="Mod: "..targetDisplay,TextColor3=Tl.FILL,TextSize=11,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=30})
	mkObj("TextLabel",{Parent=Popup,Size=UDim2.new(1,-10,0,14),Position=UDim2.fromOffset(5,28),BackgroundTransparency=1,Text="Reason:",TextColor3=Tl.SUBTEXT,TextSize=9,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=30})
	local ReasonBox = mkObj("TextBox",{Parent=Popup,Size=UDim2.new(1,-10,0,20),Position=UDim2.fromOffset(5,42),BackgroundColor3=Tl.CHECKBOX,BorderSizePixel=0,Text="",PlaceholderText="Enter reason...",PlaceholderColor3=Tl.SUBTEXT,TextColor3=Tl.TEXT,TextSize=10,Font=Enum.Font.Gotham,ClearTextOnFocus=false,ZIndex=30})
	mkObj("UIPadding",{Parent=ReasonBox,PaddingLeft=UDim.new(0,4)})
	pcall(function() local rc=Instance.new("UICorner") rc.CornerRadius=UDim.new(0,4) rc.Parent=ReasonBox end)
	mkObj("TextLabel",{Parent=Popup,Size=UDim2.new(1,-10,0,14),Position=UDim2.fromOffset(5,66),BackgroundTransparency=1,Text="Duration (seconds, 0 = permanent):",TextColor3=Tl.SUBTEXT,TextSize=9,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=30})
	local DurBox = mkObj("TextBox",{Parent=Popup,Size=UDim2.new(1,-10,0,20),Position=UDim2.fromOffset(5,80),BackgroundColor3=Tl.CHECKBOX,BorderSizePixel=0,Text="900",PlaceholderText="seconds...",PlaceholderColor3=Tl.SUBTEXT,TextColor3=Tl.TEXT,TextSize=10,Font=Enum.Font.Gotham,ClearTextOnFocus=false,ZIndex=30})
	mkObj("UIPadding",{Parent=DurBox,PaddingLeft=UDim.new(0,4)})
	pcall(function() local dc=Instance.new("UICorner") dc.CornerRadius=UDim.new(0,4) dc.Parent=DurBox end)
	local btnY=106
	local function makePopBtn(label, color, yPos, onClick)
		local Btn = mkObj("TextButton",{Parent=Popup,Size=UDim2.new(1,-10,0,18),Position=UDim2.fromOffset(5,yPos),BackgroundColor3=color,BorderSizePixel=0,Text=label,TextColor3=Color3.fromRGB(255,255,255),TextSize=10,Font=Enum.Font.GothamBold,AutoButtonColor=false,ZIndex=30})
		pcall(function() local bc=Instance.new("UICorner") bc.CornerRadius=UDim.new(0,4) bc.Parent=Btn end)
		Btn.MouseButton1Click:Connect(function() onClick() closePopup() pcall(function() Backdrop:Destroy() end) end)
		return Btn
	end
	makePopBtn("⏱ Timeout",Color3.fromRGB(200,140,30),btnY,function()
		local reason=ReasonBox.Text~="" and ReasonBox.Text or "Timed out by moderator"
		local secs=tonumber(DurBox.Text) or 900 if secs<=0 then secs=999999999 end
		modTimeoutUser(targetUsername,secs,reason)
	end) btnY=btnY+22
	makePopBtn("🚫 Chat Ban",Color3.fromRGB(200,80,80),btnY,function()
		modChatBanUser(targetUsername, ReasonBox.Text~="" and ReasonBox.Text or "Chat banned by moderator")
	end) btnY=btnY+22
	if myRole=="owner" then
		makePopBtn("💀 Script Ban",Color3.fromRGB(120,30,30),btnY,function()
			modScriptBanUser(targetUsername, ReasonBox.Text~="" and ReasonBox.Text or "Banned by owner")
		end) btnY=btnY+22
	end
	if msgId then
		makePopBtn("🗑 Delete Message",Color3.fromRGB(80,80,100),btnY,function() modDeleteMessage(msgId) end)
		btnY=btnY+22
	end
	makePopBtn("Cancel",Color3.fromRGB(60,60,70),btnY,function() end)
	Backdrop.MouseButton1Click:Connect(function() closePopup() pcall(function() Backdrop:Destroy() end) end)
end
 
-- Message display
local USER_COLORS = {
	Color3.fromRGB(100,200,255),Color3.fromRGB(255,130,130),Color3.fromRGB(130,255,160),
	Color3.fromRGB(255,200,80), Color3.fromRGB(200,130,255),Color3.fromRGB(255,160,80),
	Color3.fromRGB(80,220,220), Color3.fromRGB(255,100,180),
}
local userColorCache = {}
local function getUserColor(username)
	if not userColorCache[username] then
		local hash=0
		for i=1,#username do hash=(hash*31+string.byte(username,i))%#USER_COLORS end
		userColorCache[username]=USER_COLORS[hash+1]
	end
	return userColorCache[username]
end
 
local messageCount=0 local lastMessageTs=0
local msgIdByOrder={} local msgUserByOrder={} local msgDisplayByOrder={} local hiddenMsgIds={}
 
local function addChatMessage(username, displayName, text, msgId, skipNotif)
	if msgId and hiddenMsgIds[msgId] then return end
	local labels={}
	for _, c in ipairs(ChatLog:GetChildren()) do
		if c:IsA("TextButton") or c:IsA("TextLabel") then table.insert(labels,c) end
	end
	if #labels >= MAX_MESSAGES then
		table.sort(labels,function(a,b) return a.LayoutOrder<b.LayoutOrder end)
		local removed=labels[1]
		msgIdByOrder[removed.LayoutOrder]=nil msgUserByOrder[removed.LayoutOrder]=nil msgDisplayByOrder[removed.LayoutOrder]=nil
		removed:Destroy()
	end
	messageCount=messageCount+1
	local order=messageCount
	local color=getUserColor(username)
	local hex=string.format("%02x%02x%02x",math.floor(color.R*255),math.floor(color.G*255),math.floor(color.B*255))
	local prefix = (username=="0_bd3") and "👑 " or ""
	local Tl = _G.WaveLite_T()
	local MsgBtn = mkObj("TextButton",{
		Parent=ChatLog,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
		BackgroundTransparency=1,Text='<b><font color="#'..hex..'">'..prefix..displayName..'</font></b>: '..text,
		TextColor3=Tl.TEXT,TextSize=10,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,
		TextYAlignment=Enum.TextYAlignment.Top,TextWrapped=true,RichText=true,LayoutOrder=order,ZIndex=17,AutoButtonColor=false,
	})
	registerThemed(MsgBtn,"TextColor3","TEXT")
	if myRole=="owner" or myRole=="mod" then
		MsgBtn.MouseEnter:Connect(function() MsgBtn.BackgroundTransparency=0.85 MsgBtn.BackgroundColor3=_G.WaveLite_T().CB_HOVER end)
		MsgBtn.MouseLeave:Connect(function() MsgBtn.BackgroundTransparency=1 end)
		MsgBtn.MouseButton1Click:Connect(function() showModPopup(username,displayName,msgId) end)
	end
	if msgId then
		msgIdByOrder[order]=msgId msgUserByOrder[order]=username msgDisplayByOrder[order]=displayName
	end
	if not skipNotif and chatMinimized and chatVisible then
		chatHasNotif=true NotifDot.Visible=true
	end
end
 
-- Firebase send/fetch
local MSG_ID_PREFIX = tostring(os.time()).."_"..SESSION_ID
local lastRateSend  = 0
local function sendMessage(text)
	text=text:sub(1,60):match("^%s*(.-)%s*$") if text=="" then return end
	local msgId=MSG_ID_PREFIX.."_"..tostring(os.time())..tostring(math.random(100,999))
	httpRequest("PUT", DB_URL.."messages/"..msgId..".json",
		'{"user":"'..jsonEscape(myUsername)..'","display":"'..jsonEscape(myDisplay)..'","text":"'..jsonEscape(text)..'","ts":'..tostring(os.time())..'}')
end
 
local function trySend()
	if scriptBanned then showChatWarning("You are banned from Wave Lite.") return end
	if chatBanned   then showChatWarning("You are chat banned.") return end
	if os.time() < localTimeoutUntil then
		local remaining=localTimeoutUntil-os.time()
		if remaining>3600 then showChatWarning("You are timed out for "..math.ceil(remaining/3600).." more hour(s). Reason: spamming.")
		else showChatWarning("You are timed out for "..math.ceil(remaining/60).." more minute(s). Reason: spamming.") end
		return
	end
	local text=ChatInput.Text:match("^%s*(.-)%s*$") if text=="" then return end
	if containsBlockedContent(text) then showChatWarning("⚠ Message blocked: contains disallowed content.") ChatInput.Text="" return end
	local spamDetected=false local spamReason=""
	if isGibberish(text) then spamDetected=true spamReason="gibberish / character spam"
	elseif isBurstSpam() then spamDetected=true spamReason="sending too fast"
	elseif text==lastSentText then spamDetected=true spamReason="repeated message" end
	if spamDetected then
		spamStrikes=spamStrikes+1 ChatInput.Text=""
		if spamStrikes==1 then showChatWarning("⚠ Warning: don't spam. Next offense = timeout.") saveTimeout(0,spamReason,spamStrikes)
		elseif spamStrikes==2 then localTimeoutUntil=os.time()+(15*60) saveTimeout(localTimeoutUntil,spamReason,spamStrikes) showChatWarning("You've been timed out for 15 minutes. Reason: spamming.")
		elseif spamStrikes==3 then localTimeoutUntil=os.time()+(6*3600) saveTimeout(localTimeoutUntil,spamReason,spamStrikes) showChatWarning("You've been timed out for 6 hours. Reason: spamming.")
		else localTimeoutUntil=os.time()+(72*3600) saveTimeout(localTimeoutUntil,spamReason,spamStrikes) showChatWarning("You've been timed out for 72 hours. Reason: spamming.") end
		return
	end
	local now=os.time()
	if now-lastRateSend<3 then showChatWarning("Slow down a little.") return end
	lastRateSend=now lastSentText=text table.insert(recentMessages,now) ChatInput.Text=""
	sendMessage(text)
end
 
SendBtn.MouseButton1Click:Connect(trySend)
ChatInput.FocusLost:Connect(function(enterPressed) if enterPressed then trySend() end end)
 
local function fetchMessages()
	pcall(function()
		local cutoff=os.time()-3600 local deleted=fetchDeletedIds()
		local res=httpRequest("GET", DB_URL.."messages.json", nil)
		if not res or not res.Body or res.Body=="null" or res.Body=="" then return end
		local toRes=httpRequest("GET", DB_URL.."timeouts/"..myUsername..".json", nil)
		if toRes and toRes.Body and toRes.Body~="null" and toRes.Body~="" then
			local until_=toRes.Body:match('"until"%s*:%s*(%d+)') local strikes=toRes.Body:match('"strikes"%s*:%s*(%d+)')
			if until_ then localTimeoutUntil=math.max(localTimeoutUntil,tonumber(until_)) end
			if strikes then spamStrikes=math.max(spamStrikes,tonumber(strikes)) end
		end
		local banRes=httpRequest("GET", DB_URL.."bans/"..myUsername..".json", nil)
		if banRes and banRes.Body and banRes.Body~="null" and banRes.Body~="" then
			if banRes.Body:match('"banned"%s*:%s*(true)') then chatBanned=true end
		end
		local msgs={}
		for msgId, msgData in res.Body:gmatch('"([^"]+)":%s*(%b{})') do
			local user=msgData:match('"user"%s*:%s*"([^"]*)"') local display=msgData:match('"display"%s*:%s*"([^"]*)"')
			local text=msgData:match('"text"%s*:%s*"([^"]*)"') local ts=msgData:match('"ts"%s*:%s*(%d+)')
			if user and text and ts then
				local tsNum=tonumber(ts)
				if tsNum and tsNum>=cutoff and tsNum>lastMessageTs then
					local dispName=(display and display~="") and display or user
					table.insert(msgs,{user=user,display=dispName,text=text,ts=tsNum,id=msgId})
				end
			end
		end
		table.sort(msgs,function(a,b) return a.ts<b.ts end)
		for _, msg in ipairs(msgs) do
			lastMessageTs=msg.ts
			if not deleted[msg.id] then addChatMessage(msg.user,msg.display,msg.text,msg.id)
			else hiddenMsgIds[msg.id]=true end
		end
		for _, child in ipairs(ChatLog:GetChildren()) do
			if child:IsA("TextButton") then
				local id=msgIdByOrder[child.LayoutOrder]
				if id and deleted[id] and not hiddenMsgIds[id] then hiddenMsgIds[id]=true child:Destroy() end
			end
		end
	end)
end
 
task.spawn(function()
	task.wait(1.5)
	while true do
		if chatVisible then fetchMessages() end
		task.wait(4)
	end
end)
 
-- Show/hide
local function showChatFull()   ChatPanel.Visible=true  MinimizedPill.Visible=false chatHasNotif=false NotifDot.Visible=false end
local function showChatMin()    ChatPanel.Visible=false MinimizedPill.Visible=true end
local function setChatVisible(on)
	chatVisible=on
	if not on then ChatPanel.Visible=false MinimizedPill.Visible=false
	else if chatMinimized then showChatMin() else showChatFull() end end
end
MinimizeBtn.MouseButton1Click:Connect(function() chatMinimized=true showChatMin() end)
MinimizedPill.MouseButton1Click:Connect(function() chatMinimized=false chatHasNotif=false NotifDot.Visible=false showChatFull() end)
GearBtn.MouseButton1Click:Connect(function() setChatVisible(not chatVisible) end)
 
-- Lock/drag
local chatDragging=false local chatDragStart=nil local chatDragOrigin=nil
local function updateLockBtn() LockBtn.Text=chatLocked and "🔒" or "🔓" end
updateLockBtn()
LockBtn.MouseButton1Click:Connect(function()
	chatLocked=not chatLocked updateLockBtn()
	if chatLocked then tween(ChatPanel,0.18,{Position=chatDefaultPos}) end
end)
ChatHeader.InputBegan:Connect(function(input)
	if chatLocked then return end
	if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
		chatDragging=true chatDragStart=input.Position chatDragOrigin=ChatPanel.Position
		input.Changed:Connect(function() if input.UserInputState==Enum.UserInputState.End then chatDragging=false end end)
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if chatDragging and chatDragStart and chatDragOrigin then
		if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then
			local delta=input.Position-chatDragStart
			ChatPanel.Position=UDim2.new(chatDragOrigin.X.Scale,chatDragOrigin.X.Offset+delta.X,chatDragOrigin.Y.Scale,chatDragOrigin.Y.Offset+delta.Y)
		end
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
		chatDragging=false
	end
end)
