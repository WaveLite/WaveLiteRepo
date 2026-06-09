-- modules/firebase.lua
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local DB_URL             = "https://wavelite-counter-default-rtdb.firebaseio.com/"
local SESSION_ID         = tostring(os.time())..tostring(math.random(1000,9999))
local KEEPALIVE_INTERVAL = 25
local COUNT_INTERVAL     = 30
local STALE_THRESHOLD    = 35

local myUsername = LocalPlayer.Name
local myDisplay  = LocalPlayer.DisplayName
local myRole     = nil
local chatBanned   = false
local scriptBanned = false

local spamStrikes       = 0
local localTimeoutUntil = 0
local recentMessages    = {}
local lastSentText      = ""

local function httpRequest(method, url, body)
    local res = nil
    pcall(function()
        local opts = { Url=url, Method=method, Headers={["Content-Type"]="application/json"} }
        if body then opts.Body = body end
        if syn and syn.request then res = syn.request(opts)
        elseif request then res = request(opts)
        elseif http and http.request then res = http.request(opts) end
    end)
    return res
end

local function jsonEscape(s)
    s=s:gsub('\\','\\\\') s=s:gsub('"','\\"') s=s:gsub('\n','\\n') s=s:gsub('\r','\\r') return s
end

local function registerSession()
    pcall(function()
        httpRequest("PUT", DB_URL.."sessions/"..SESSION_ID..".json",
            '{"ts":'..tostring(os.time())..',"user":"'..jsonEscape(myDisplay)..'"}')
    end)
end
local function removeSession()
    pcall(function() httpRequest("DELETE", DB_URL.."sessions/"..SESSION_ID..".json", nil) end)
end
local function fetchCount()
    local count = 0
    pcall(function()
        local res = httpRequest("GET", DB_URL.."sessions.json", nil)
        if res and res.Body and res.Body ~= "null" and res.Body ~= "" then
            local now = os.time()
            for ts in res.Body:gmatch('"ts":(%d+)') do
                if (now-tonumber(ts)) <= STALE_THRESHOLD then count=count+1 end
            end
        end
    end)
    return count
end
local function pruneStaleSessions()
    pcall(function()
        local res = httpRequest("GET", DB_URL.."sessions.json", nil)
        if not res or not res.Body or res.Body=="null" or res.Body=="" then return end
        local now = os.time()
        for sid, ts in res.Body:gmatch('"([^"]+)":%{[^}]*"ts":(%d+)') do
            if sid ~= SESSION_ID and (now-tonumber(ts)) > STALE_THRESHOLD then
                pcall(function() httpRequest("DELETE", DB_URL.."sessions/"..sid..".json", nil) end)
            end
        end
    end)
end
local function fetchMyModerationStatus()
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
end
local function saveTimeout(until_, reason, strikes)
    pcall(function()
        httpRequest("PUT", DB_URL.."timeouts/"..myUsername..".json",
            '{"until":'..tostring(until_)..',"reason":"'..jsonEscape(reason)..'","strikes":'..tostring(strikes)..'}')
    end)
end
local function modTimeoutUser(username, seconds, reason)
    pcall(function()
        local until_ = os.time()+seconds
        local strikes = 0
        local toRes = httpRequest("GET", DB_URL.."timeouts/"..username..".json", nil)
        if toRes and toRes.Body and toRes.Body~="null" and toRes.Body~="" then
            local s = toRes.Body:match('"strikes"%s*:%s*(%d+)')
            if s then strikes=tonumber(s) end
        end
        httpRequest("PUT", DB_URL.."timeouts/"..username..".json",
            '{"until":'..tostring(until_)..',"reason":"'..jsonEscape(reason)..'","strikes":'..tostring(strikes)..'}')
    end)
end
local function modChatBanUser(username, reason)
    pcall(function()
        httpRequest("PUT", DB_URL.."bans/"..username..".json", '{"banned":true,"reason":"'..jsonEscape(reason)..'"}')
    end)
end
local function modScriptBanUser(username, reason)
    pcall(function()
        httpRequest("PUT", DB_URL.."script_bans/"..username..".json", '{"banned":true,"reason":"'..jsonEscape(reason)..'"}')
    end)
end
local function modDeleteMessage(msgId)
    pcall(function()
        httpRequest("PUT", DB_URL.."deleted_messages/"..msgId..".json", '{"deleted":true}')
    end)
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

return {
    DB_URL              = DB_URL,
    SESSION_ID          = SESSION_ID,
    COUNT_INTERVAL      = COUNT_INTERVAL,
    myUsername          = myUsername,
    myDisplay           = myDisplay,
    myRole              = function() return myRole end,
    chatBanned          = function() return chatBanned end,
    scriptBanned        = function() return scriptBanned end,
    spamStrikes         = function() return spamStrikes end,
    setSpamStrikes      = function(v) spamStrikes=v end,
    localTimeoutUntil   = function() return localTimeoutUntil end,
    setLocalTimeout     = function(v) localTimeoutUntil=v end,
    recentMessages      = recentMessages,
    lastSentText        = function() return lastSentText end,
    setLastSentText     = function(v) lastSentText=v end,
    httpRequest         = httpRequest,
    jsonEscape          = jsonEscape,
    registerSession     = registerSession,
    removeSession       = removeSession,
    fetchCount          = fetchCount,
    pruneStaleSessions  = pruneStaleSessions,
    fetchMyModerationStatus = fetchMyModerationStatus,
    saveTimeout         = saveTimeout,
    modTimeoutUser      = modTimeoutUser,
    modChatBanUser      = modChatBanUser,
    modScriptBanUser    = modScriptBanUser,
    modDeleteMessage    = modDeleteMessage,
    fetchDeletedIds     = fetchDeletedIds,
}
