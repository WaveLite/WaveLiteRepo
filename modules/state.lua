-- modules/state.lua

_G.WaveLiteState = {
    Sliders = {
        Prediction = 0.59, Smoothness = 1.00,
        FlySpeed = 25.00, FOVRadius = 150, CamFOV = 70,
    },
    Toggles = {
        TeamCheck=false, WallCheck=false, ClickTP=false, NameESP=false,
        BoxESP=false, Tracers=false, NoFog=false, Maxzoom=false,
        Noclip=false, FOVCircle=false, LockIndicator=false,
        HealthBars=false, CamFOV=false,
    },
    Keybinds = { CamLockToggle=nil, FlyToggle=nil },
    AimPart = "HumanoidRootPart",
}

local SliderConfig = {
    Prediction = { Min=0,   Max=1,   Decimals=2 },
    Smoothness  = { Min=1,   Max=10,  Decimals=2 },
    FlySpeed    = { Min=1,   Max=50,  Decimals=2 },
    FOVRadius   = { Min=50,  Max=500, Decimals=0 },
    CamFOV      = { Min=50,  Max=120, Decimals=0 },
}

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

local themedObjects={} local themedCheckboxes={} local themedSliders={} local themedKeybinds={}
local currentThemeName = "dark"
local T = THEMES.dark

local function registerThemed(obj, prop, role)
    table.insert(themedObjects, { obj=obj, prop=prop, role=role })
end

local function applyTheme(themeName)
    currentThemeName = themeName
    T = THEMES[themeName]
    for _, e in ipairs(themedObjects) do pcall(function() e.obj[e.prop]=T[e.role] end) end
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

return {
    State             = _G.WaveLiteState,
    SliderConfig      = SliderConfig,
    THEMES            = THEMES,
    T                 = function() return T end,
    currentThemeName  = function() return currentThemeName end,
    themedObjects     = themedObjects,
    themedCheckboxes  = themedCheckboxes,
    themedSliders     = themedSliders,
    themedKeybinds    = themedKeybinds,
    registerThemed    = registerThemed,
    applyTheme        = applyTheme,
    formatValue       = formatValue,
    valueToAlpha      = valueToAlpha,
    alphaToValue      = alphaToValue,
}
