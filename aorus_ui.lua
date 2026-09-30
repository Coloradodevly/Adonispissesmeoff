-- ============================================================
--   AorusUI  —  Lightweight Roblox UI Library
--   Style: dark panel · green accent · corner-bracket ESP
--   Components: Login, Window, Tabs, Toggles, ESP Renderer
-- ============================================================

local AorusUI = {}
AorusUI.__index = AorusUI

-- ── Services ────────────────────────────────────────────────
local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer    = Players.LocalPlayer

-- Resolve the safest GUI parent available on this executor.
-- Preference: gethui() > CoreGui > PlayerGui (last resort, most detectable).
local function resolveGuiParent()
    local ok, hui = pcall(function() return gethui and gethui() end)
    if ok and hui then return hui end

    local ok2, core = pcall(function() return game:GetService("CoreGui") end)
    if ok2 and core then
        -- Some executors expose CoreGui but block writes to it; test with a throwaway Instance.
        local ok3 = pcall(function()
            local test = Instance.new("Folder")
            test.Name = "AorusUI_Probe"
            test.Parent = core
            test:Destroy()
        end)
        if ok3 then return core end
    end

    -- Last resort
    return LocalPlayer:WaitForChild("PlayerGui")
end

local PlayerGui = resolveGuiParent()

-- ── Palette ─────────────────────────────────────────────────
local C = {
    bg          = Color3.fromRGB(13,  17,  23),   -- #0d1117
    panel       = Color3.fromRGB(22,  27,  34),   -- #161b22
    card        = Color3.fromRGB(31,  41,  55),   -- #1f2937
    border      = Color3.fromRGB(48,  54,  61),   -- #30363d
    accent      = Color3.fromRGB(0,   200, 150),  -- #00c896
    accentDim   = Color3.fromRGB(0,   140, 105),  -- dimmer green
    text        = Color3.fromRGB(230, 237, 243),  -- #e6edf3
    textDim     = Color3.fromRGB(139, 148, 158),  -- #8b949e
    danger      = Color3.fromRGB(248, 81,  73),   -- #f85149
    yellow      = Color3.fromRGB(255, 213, 79),   -- player dist
    white       = Color3.fromRGB(255, 255, 255),  -- bot dist
    espGreen    = Color3.fromRGB(0,   255, 140),
    espRed      = Color3.fromRGB(255, 60,  60),
}

-- ── Utility ──────────────────────────────────────────────────
local function make(class, props, parent)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    if parent then inst.Parent = parent end
    return inst
end

local function tween(inst, props, t, style, dir)
    TweenService:Create(inst,
        TweenInfo.new(t or 0.18, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
        props
    ):Play()
end

local function makeDraggable(frame, handle)
    handle = handle or frame
    local dragging, dragStart, startPos
    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = inp.Position
            startPos  = frame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType ~= Enum.UserInputType.MouseMovement
        and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = inp.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- ── Corner-bracket drawing helper ───────────────────────────
-- Returns a table of 4 Drawing lines forming corner brackets
local function makeCornerBracket(color, thickness, length)
    color     = color     or C.espGreen
    thickness = thickness or 1.5
    length    = length    or 8
    local lines = {}
    for i = 1, 8 do
        local l = Drawing.new("Line")
        l.Color     = color
        l.Thickness = thickness
        l.Visible   = false
        table.insert(lines, l)
    end
    -- lines[1..2] = TL, [3..4] = TR, [5..6] = BL, [7..8] = BR
    return lines
end

local function updateCornerBracket(lines, x1, y1, x2, y2, len)
    len = len or 8
    -- TL horizontal, TL vertical
    lines[1].From = Vector2.new(x1, y1)       lines[1].To = Vector2.new(x1+len, y1)
    lines[2].From = Vector2.new(x1, y1)       lines[2].To = Vector2.new(x1, y1+len)
    -- TR horizontal, TR vertical
    lines[3].From = Vector2.new(x2, y1)       lines[3].To = Vector2.new(x2-len, y1)
    lines[4].From = Vector2.new(x2, y1)       lines[4].To = Vector2.new(x2, y1+len)
    -- BL horizontal, BL vertical
    lines[5].From = Vector2.new(x1, y2)       lines[5].To = Vector2.new(x1+len, y2)
    lines[6].From = Vector2.new(x1, y2)       lines[6].To = Vector2.new(x1, y2-len)
    -- BR horizontal, BR vertical
    lines[7].From = Vector2.new(x2, y2)       lines[7].To = Vector2.new(x2-len, y2)
    lines[8].From = Vector2.new(x2, y2)       lines[8].To = Vector2.new(x2, y2-len)
    for _, l in ipairs(lines) do l.Visible = true end
end

local function hideCornerBracket(lines)
    for _, l in ipairs(lines) do l.Visible = false end
end

local function removeCornerBracket(lines)
    for _, l in ipairs(lines) do l:Remove() end
end

-- ── ESP Drawing Set ──────────────────────────────────────────
function AorusUI.newESPSet(isPlayer)
    local d = {}
    -- Corner bracket box (8 lines)
    d.box       = makeCornerBracket(C.espGreen, 1.5, 8)
    -- Tracer line
    d.tracer    = Drawing.new("Line")
    d.tracer.Color     = isPlayer and C.espGreen or C.espRed
    d.tracer.Thickness = 1
    d.tracer.Visible   = false
    -- Health bar (background + fill)
    d.healthBG  = Drawing.new("Square")
    d.healthBG.Color   = Color3.fromRGB(20, 20, 20)
    d.healthBG.Filled  = true
    d.healthBG.Visible = false
    d.healthFill = Drawing.new("Square")
    d.healthFill.Filled  = true
    d.healthFill.Visible = false
    -- Labels
    local function makeLabel(size, color, outline)
        local l = Drawing.new("Text")
        l.Size       = size or 11
        l.Color      = color or C.text
        l.Outline    = outline ~= false
        l.OutlineColor = Color3.fromRGB(0,0,0)
        l.Visible    = false
        l.Center     = true
        return l
    end
    d.nameLabel  = makeLabel(11, C.text)
    d.distLabel  = makeLabel(10, isPlayer and C.yellow or C.white)
    d.toolLabel  = makeLabel(10, C.textDim)
    d._isPlayer  = isPlayer
    return d
end

function AorusUI.updateESP(d, char, cam, opts)
    opts = opts or {}
    local showBox     = opts.showBox
    local showLine    = opts.showLine
    local showHealth  = opts.showHealth
    local showDetails = opts.showDetails

    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then
        AorusUI.hideESP(d) return
    end

    local sp, onScreen = cam:WorldToViewportPoint(hrp.Position)
    if not onScreen or sp.Z < 0 then
        AorusUI.hideESP(d) return
    end

    local dist     = math.floor((hrp.Position - cam.CFrame.Position).Magnitude)
    local scale    = 1 / sp.Z
    local height   = 5.5 / sp.Z * 100  -- approx screen height of char
    local width    = height * 0.45
    local sx, sy   = sp.X, sp.Y
    local x1, y1   = sx - width, sy - height
    local x2, y2   = sx + width, sy + height

    -- Box
    if showBox then
        updateCornerBracket(d.box, x1, y1, x2, y2, math.max(6, width * 0.35))
    else
        hideCornerBracket(d.box)
    end

    -- Tracer
    if showLine then
        local vp = cam.ViewportSize
        d.tracer.From    = Vector2.new(vp.X * 0.5, vp.Y)
        d.tracer.To      = Vector2.new(sx, y2)
        d.tracer.Visible = true
    else
        d.tracer.Visible = false
    end

    -- Health bar (left of box)
    if showHealth then
        local hp     = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
        local barW   = 3
        local barX   = x1 - barW - 2
        local barH   = y2 - y1
        local fillH  = barH * hp
        local healthColor = Color3.fromRGB(
            math.floor(255 * (1 - hp)),
            math.floor(255 * hp),
            60
        )
        d.healthBG.Position = Vector2.new(barX, y1)
        d.healthBG.Size     = Vector2.new(barW, barH)
        d.healthBG.Visible  = true
        d.healthFill.Color    = healthColor
        d.healthFill.Position = Vector2.new(barX, y2 - fillH)
        d.healthFill.Size     = Vector2.new(barW, fillH)
        d.healthFill.Visible  = true
    else
        d.healthBG.Visible   = false
        d.healthFill.Visible = false
    end

    -- Details: name / distance / tool
    if showDetails then
        -- Name above box
        local name = ""
        if d._isPlayer then
            local plr = Players:GetPlayerFromCharacter(char)
            name = plr and plr.Name or ""
        else
            name = char.Name
        end
        d.nameLabel.Position = Vector2.new(sx, y1 - 13)
        d.nameLabel.Text     = name
        d.nameLabel.Visible  = true

        -- Distance below box
        d.distLabel.Position = Vector2.new(sx, y2 + 2)
        d.distLabel.Text     = dist .. "m"
        d.distLabel.Visible  = true

        -- Tool (player only — held tool name)
        if d._isPlayer then
            local plr  = Players:GetPlayerFromCharacter(char)
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then
                d.toolLabel.Position = Vector2.new(sx, y2 + 13)
                d.toolLabel.Text     = "[" .. tool.Name .. "]"
                d.toolLabel.Visible  = true
            else
                d.toolLabel.Visible  = false
            end
        else
            d.toolLabel.Visible = false
        end
    else
        d.nameLabel.Visible = false
        d.distLabel.Visible = false
        d.toolLabel.Visible = false
    end
end

function AorusUI.hideESP(d)
    hideCornerBracket(d.box)
    d.tracer.Visible     = false
    d.healthBG.Visible   = false
    d.healthFill.Visible = false
    d.nameLabel.Visible  = false
    d.distLabel.Visible  = false
    d.toolLabel.Visible  = false
end

function AorusUI.removeESP(d)
    removeCornerBracket(d.box)
    d.tracer:Remove()
    d.healthBG:Remove()
    d.healthFill:Remove()
    d.nameLabel:Remove()
    d.distLabel:Remove()
    d.toolLabel:Remove()
end

-- ════════════════════════════════════════════════════════════
--   LOGIN SCREEN
-- ════════════════════════════════════════════════════════════

-- shared helper: fills input, runs onLogin, updates status
local function _tryLogin(key, keyInput, inputWrap, statusLabel, sg, opts)
    keyInput.Text = key
    statusLabel.TextColor3 = C.textDim
    statusLabel.Text = "Verifying..."
    task.spawn(function()
        local callOk, ok = true, true
        if opts.onLogin then
            callOk, ok = pcall(opts.onLogin, key)
            if not callOk then
                warn("[AorusUI] onLogin error: " .. tostring(ok))
                ok = false
            end
        end
        if ok == false then
            statusLabel.TextColor3 = C.danger
            statusLabel.Text = "Invalid key."
            tween(inputWrap, { BackgroundColor3 = Color3.fromRGB(60,20,20) }, 0.1)
            task.delay(0.4, function()
                tween(inputWrap, { BackgroundColor3 = C.panel }, 0.3)
            end)
        else
            statusLabel.TextColor3 = C.accent
            statusLabel.Text = "Authenticated!"
            task.delay(0.6, function() sg:Destroy() end)
        end
    end)
end

function AorusUI.createLogin(opts)
    opts = opts or {}
    -- opts.enabled         : boolean, default true. false = skip key system entirely.
    -- opts.logo            : string URL or nil
    -- opts.onLogin         : function(key) -> bool
    -- opts.onSkip          : function() -- called instead of onLogin when enabled = false
    -- opts.keyFromExternal : string URL -- when provided, a "GET KEY" button appears
    --                        below LOGIN. Clicking it copies the URL to the user's
    --                        clipboard and briefly shows "Link copied!" in the status.

    if opts.enabled == false then
        if opts.onSkip then
            local ok, err = pcall(opts.onSkip)
            if not ok then warn("[AorusUI] onSkip error: " .. tostring(err)) end
        elseif opts.onLogin then
            local ok, err = pcall(opts.onLogin, "")
            if not ok then warn("[AorusUI] onLogin error: " .. tostring(err)) end
        end
        return { gui = nil, input = nil, skipped = true }
    end

    local sg = make("ScreenGui", {
        Name = "AorusLogin", ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, PlayerGui)

    -- Full-screen background
    local bg = make("Frame", {
        Size = UDim2.fromScale(1,1),
        BackgroundColor3 = C.bg,
        BorderSizePixel  = 0,
    }, sg)

    -- Subtle grid vignette overlay
    local overlay = make("Frame", {
        Size = UDim2.fromScale(1,1),
        BackgroundTransparency = 0.92,
        BackgroundColor3 = C.accent,
        BorderSizePixel = 0,
    }, bg)

    -- Center container
    local container = make("Frame", {
        Size             = UDim2.fromOffset(320, 380),
        Position         = UDim2.fromScale(0.5, 0.5),
        AnchorPoint      = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel  = 0,
    }, bg)
    make("UIListLayout", {
        FillDirection       = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment   = Enum.VerticalAlignment.Center,
        Padding             = UDim.new(0, 24),
        SortOrder           = Enum.SortOrder.LayoutOrder,
    }, container)

    -- Logo area
    local logoFrame = make("Frame", {
        Size = UDim2.fromOffset(120, 100),
        BackgroundTransparency = 1,
        LayoutOrder = 1,
    }, container)
    if opts.logoImage then
        make("ImageLabel", {
            Size = UDim2.fromScale(1,1),
            BackgroundTransparency = 1,
            Image = opts.logoImage,
            ScaleType = Enum.ScaleType.Fit,
        }, logoFrame)
    else
        -- Text fallback
        make("TextLabel", {
            Size = UDim2.fromScale(1,1),
            BackgroundTransparency = 1,
            Text = opts.logoText or "AORUS",
            TextColor3 = C.text,
            Font = Enum.Font.GothamBold,
            TextSize = 32,
            TextXAlignment = Enum.TextXAlignment.Center,
        }, logoFrame)
        make("TextLabel", {
            Size = UDim2.new(1,0,0,14),
            Position = UDim2.new(0,0,1,-2),
            BackgroundTransparency = 1,
            Text = opts.subtitle or "ESP",
            TextColor3 = C.accent,
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Center,
        }, logoFrame)
    end

    -- Key input
    local inputWrap = make("Frame", {
        Size = UDim2.new(1,0,0,48),
        BackgroundColor3 = C.panel,
        BorderSizePixel = 0,
        LayoutOrder = 2,
    }, container)
    make("UICorner", { CornerRadius = UDim.new(0,10) }, inputWrap)
    make("UIStroke", { Color = C.border, Thickness = 1 }, inputWrap)

    local keyInput = make("TextBox", {
        Size = UDim2.new(1,-24,1,0),
        Position = UDim2.fromOffset(12,0),
        BackgroundTransparency = 1,
        Text = "",
        PlaceholderText = "Enter key...",
        PlaceholderColor3 = C.textDim,
        TextColor3 = C.text,
        Font = Enum.Font.Gotham,
        TextSize = 14,
        ClearTextOnFocus = false,
        BorderSizePixel = 0,
    }, inputWrap)

    -- Focus glow
    keyInput.Focused:Connect(function()
        tween(inputWrap, { BackgroundColor3 = Color3.fromRGB(28,35,44) }, 0.15)
        local stroke = inputWrap:FindFirstChildOfClass("UIStroke")
        if stroke then tween(stroke, { Color = C.accent }, 0.15) end
    end)
    keyInput.FocusLost:Connect(function()
        tween(inputWrap, { BackgroundColor3 = C.panel }, 0.15)
        local stroke = inputWrap:FindFirstChildOfClass("UIStroke")
        if stroke then tween(stroke, { Color = C.border }, 0.15) end
    end)

    -- Login button
    local loginBtn = make("TextButton", {
        Size = UDim2.new(1,0,0,52),
        BackgroundColor3 = C.accent,
        BorderSizePixel  = 0,
        Text             = "LOGIN",
        TextColor3       = Color3.fromRGB(10,10,10),
        Font             = Enum.Font.GothamBold,
        TextSize         = 15,
        LayoutOrder      = 3,
        AutoButtonColor  = false,
    }, container)
    make("UICorner", { CornerRadius = UDim.new(0,12) }, loginBtn)

    -- Button hover/press
    loginBtn.MouseEnter:Connect(function()
        tween(loginBtn, { BackgroundColor3 = Color3.fromRGB(0,220,165) }, 0.12)
    end)
    loginBtn.MouseLeave:Connect(function()
        tween(loginBtn, { BackgroundColor3 = C.accent }, 0.12)
    end)
    loginBtn.MouseButton1Down:Connect(function()
        tween(loginBtn, { BackgroundColor3 = C.accentDim, Size = UDim2.new(0.97,0,0,52) }, 0.08)
    end)
    loginBtn.MouseButton1Up:Connect(function()
        tween(loginBtn, { BackgroundColor3 = C.accent, Size = UDim2.new(1,0,0,52) }, 0.1)
    end)

    -- Status label
    local statusLabel = make("TextLabel", {
        Size = UDim2.new(1,0,0,16),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = C.danger,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Center,
        LayoutOrder = 4,
    }, container)

    loginBtn.MouseButton1Click:Connect(function()
        _tryLogin(keyInput.Text, keyInput, inputWrap, statusLabel, sg, opts)
    end)

    -- "Get Key" button — only shown when keyFromExternal is provided
    if opts.keyFromExternal then
        local getKeyBtn = make("TextButton", {
            Size            = UDim2.new(1, 0, 0, 36),
            BackgroundColor3 = C.panel,
            BorderSizePixel  = 0,
            Text             = "GET KEY",
            TextColor3       = C.accent,
            Font             = Enum.Font.GothamBold,
            TextSize         = 13,
            LayoutOrder      = 5,
            AutoButtonColor  = false,
        }, container)
        make("UICorner", { CornerRadius = UDim.new(0, 10) }, getKeyBtn)
        make("UIStroke", { Color = C.accent, Thickness = 1 }, getKeyBtn)

        -- subtle hover
        getKeyBtn.MouseEnter:Connect(function()
            tween(getKeyBtn, { BackgroundColor3 = Color3.fromRGB(28, 38, 44) }, 0.12)
        end)
        getKeyBtn.MouseLeave:Connect(function()
            tween(getKeyBtn, { BackgroundColor3 = C.panel }, 0.12)
        end)
        getKeyBtn.MouseButton1Down:Connect(function()
            tween(getKeyBtn, { Size = UDim2.new(0.97, 0, 0, 36) }, 0.08)
        end)
        getKeyBtn.MouseButton1Up:Connect(function()
            tween(getKeyBtn, { Size = UDim2.new(1, 0, 0, 36) }, 0.1)
        end)

        getKeyBtn.MouseButton1Click:Connect(function()
            -- copy link to clipboard (setclipboard is available in most executors)
            local copied = false
            if type(setclipboard) == "function" then
                pcall(setclipboard, opts.keyFromExternal)
                copied = true
            elseif type(Clipboard) == "table" and type(Clipboard.set) == "function" then
                pcall(Clipboard.set, opts.keyFromExternal)
                copied = true
            end

            if copied then
                statusLabel.TextColor3 = C.accent
                statusLabel.Text       = "Link copied to clipboard!"
            else
                -- executor has no clipboard API — show the link directly in status
                statusLabel.TextColor3 = C.textDim
                statusLabel.Text       = opts.keyFromExternal
            end

            -- reset status after 3 seconds
            task.delay(3, function()
                if statusLabel and statusLabel.Parent then
                    statusLabel.Text = ""
                end
            end)
        end)
    end

    return { gui = sg, input = keyInput }
end

-- ════════════════════════════════════════════════════════════
--   MAIN WINDOW  (sidebar tabs + feature panel)
-- ════════════════════════════════════════════════════════════
function AorusUI.createWindow(opts)
    opts = opts or {}
    -- opts.title    : string
    -- opts.subtitle : string (online count etc)

    local sg = make("ScreenGui", {
        Name = "AorusWindow", ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, PlayerGui)

    -- Root window frame
    local WIN_W, WIN_H = 520, 340
    local win = make("Frame", {
        Size             = UDim2.fromOffset(WIN_W, WIN_H),
        Position         = UDim2.fromScale(0.5, 0.5),
        AnchorPoint      = Vector2.new(0.5, 0.5),
        BackgroundColor3 = C.bg,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
    }, sg)
    make("UICorner", { CornerRadius = UDim.new(0,10) }, win)
    make("UIStroke", { Color = C.border, Thickness = 1 }, win)
    makeDraggable(win)

    -- ── Sidebar ────────────────────────────────────────────
    local SIDEBAR_W = 52
    local sidebar = make("Frame", {
        Size             = UDim2.new(0, SIDEBAR_W, 1, 0),
        BackgroundColor3 = C.panel,
        BorderSizePixel  = 0,
    }, win)
    make("UIListLayout", {
        FillDirection       = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment   = Enum.VerticalAlignment.Top,
        Padding             = UDim.new(0,4),
        SortOrder           = Enum.SortOrder.LayoutOrder,
    }, sidebar)
    -- Top padding
    make("Frame", {
        Size = UDim2.fromOffset(SIDEBAR_W, 8),
        BackgroundTransparency = 1,
        LayoutOrder = 0,
    }, sidebar)

    -- ── Header bar ─────────────────────────────────────────
    local HEADER_H = 38
    local header = make("Frame", {
        Size             = UDim2.new(1,-SIDEBAR_W, 0, HEADER_H),
        Position         = UDim2.fromOffset(SIDEBAR_W, 0),
        BackgroundColor3 = C.panel,
        BorderSizePixel  = 0,
    }, win)
    -- Online dot + count
    local onlineDot = make("Frame", {
        Size = UDim2.fromOffset(8,8),
        Position = UDim2.fromOffset(14, 15),
        BackgroundColor3 = C.accent,
        BorderSizePixel = 0,
    }, header)
    make("UICorner", { CornerRadius = UDim.new(1,0) }, onlineDot)
    local onlineLabel = make("TextLabel", {
        Size = UDim2.fromOffset(60, HEADER_H),
        Position = UDim2.fromOffset(26, 0),
        BackgroundTransparency = 1,
        Text = opts.subtitle or "0",
        TextColor3 = C.textDim,
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, header)

    -- ── Content panel ──────────────────────────────────────
    local content = make("Frame", {
        Size             = UDim2.new(1,-SIDEBAR_W, 1,-HEADER_H),
        Position         = UDim2.fromOffset(SIDEBAR_W, HEADER_H),
        BackgroundColor3 = C.bg,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
    }, win)

    -- Scrollable inner
    local scroll = make("ScrollingFrame", {
        Size = UDim2.fromScale(1,1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = C.border,
        CanvasSize = UDim2.fromScale(1,0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, content)
    make("UIPadding", {
        PaddingLeft   = UDim.new(0,14),
        PaddingRight  = UDim.new(0,14),
        PaddingTop    = UDim.new(0,10),
        PaddingBottom = UDim.new(0,10),
    }, scroll)
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        Padding       = UDim.new(0, 6),
        SortOrder     = Enum.SortOrder.LayoutOrder,
    }, scroll)

    local window = {
        gui       = sg,
        win       = win,
        sidebar   = sidebar,
        content   = scroll,
        _tabs     = {},
        _tabPages = {},
        _active   = nil,
        onlineLabel = onlineLabel,
    }

    -- ── Tab builder ────────────────────────────────────────
    function window:addTab(icon, label, order)
        local ok, result = pcall(self._addTabImpl, self, icon, label, order)
        if not ok then
            warn("[AorusUI] addTab('" .. tostring(label) .. "') failed safely: " .. tostring(result))
            return nil
        end
        return result
    end

    function window:_addTabImpl(icon, label, order)
        -- Sidebar icon button
        local btn = make("ImageButton", {
            Size = UDim2.fromOffset(SIDEBAR_W, SIDEBAR_W),
            BackgroundColor3 = C.panel,
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            Image = icon or "",
            ImageColor3 = C.textDim,
            AutoButtonColor = false,
            LayoutOrder = order or #self._tabs + 1,
        }, self.sidebar)
        make("UICorner", { CornerRadius = UDim.new(0,6) }, btn)

        -- If no image, use text label
        if not icon or icon == "" then
            btn.Image = ""
            make("TextLabel", {
                Size = UDim2.fromScale(1,1),
                BackgroundTransparency = 1,
                Text = label or "?",
                TextColor3 = C.textDim,
                Font = Enum.Font.GothamBold,
                TextSize = 10,
            }, btn)
        end

        -- Page (hidden by default)
        local page = make("Frame", {
            Size = UDim2.fromScale(1,1),
            BackgroundTransparency = 1,
            Visible = false,
        }, self.content)
        make("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            Padding = UDim.new(0,6),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, page)

        local tabIdx = #self._tabs + 1
        table.insert(self._tabs, btn)
        table.insert(self._tabPages, page)

        btn.MouseButton1Click:Connect(function()
            self:selectTab(tabIdx)
        end)

        -- Active indicator strip
        local strip = make("Frame", {
            Size = UDim2.new(0,3,0.6,0),
            Position = UDim2.new(0,0,0.2,0),
            BackgroundColor3 = C.accent,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
        }, btn)
        make("UICorner", { CornerRadius = UDim.new(1,0) }, strip)
        btn:SetAttribute("strip", strip)

        -- Select first tab automatically
        if tabIdx == 1 then self:selectTab(1) end

        return page
    end

    function window:selectTab(idx)
        local ok, err = pcall(self._selectTabImpl, self, idx)
        if not ok then
            warn("[AorusUI] selectTab(" .. tostring(idx) .. ") failed safely: " .. tostring(err))
        end
    end

    function window:_selectTabImpl(idx)
        for i, b in ipairs(self._tabs) do
            local active = (i == idx)
            local strip = b:GetAttribute("strip") -- stored differently, use FindFirstChild
            local stripFrame = b:FindFirstChildOfClass("Frame")
            if active then
                tween(b, { BackgroundTransparency = 0, BackgroundColor3 = C.card }, 0.15)
                local ic = b:FindFirstChildOfClass("ImageLabel") or b
                tween(ic, { ImageColor3 = C.accent }, 0.15)
                local lbl = b:FindFirstChildOfClass("TextLabel")
                if lbl then tween(lbl, { TextColor3 = C.accent }, 0.15) end
                if stripFrame then tween(stripFrame, { BackgroundTransparency = 0 }, 0.15) end
            else
                tween(b, { BackgroundTransparency = 0.5, BackgroundColor3 = C.panel }, 0.15)
                local ic = b:FindFirstChildOfClass("ImageLabel") or b
                tween(ic, { ImageColor3 = C.textDim }, 0.15)
                local lbl = b:FindFirstChildOfClass("TextLabel")
                if lbl then tween(lbl, { TextColor3 = C.textDim }, 0.15) end
                if stripFrame then tween(stripFrame, { BackgroundTransparency = 1 }, 0.15) end
            end
            self._tabPages[i].Visible = active
        end
        self._active = idx
    end

    return window
end

-- ════════════════════════════════════════════════════════════
--   SECTION HEADER  (separator label)
-- ════════════════════════════════════════════════════════════
function AorusUI.addSection(page, label, order)
    local row = make("Frame", {
        Size = UDim2.new(1,0,0,22),
        BackgroundTransparency = 1,
        LayoutOrder = order or 1,
    }, page)
    make("TextLabel", {
        Size = UDim2.fromOffset(0, 22),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = C.accent,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    -- Divider line after text
    local divider = make("Frame", {
        Size = UDim2.new(1,-80,0,1),
        Position = UDim2.new(0,76,0.5,0),
        BackgroundColor3 = C.border,
        BorderSizePixel = 0,
    }, row)
    return row
end

-- ════════════════════════════════════════════════════════════
--   TOGGLE ROW  (like the Details / Line / Box / Health rows)
-- ════════════════════════════════════════════════════════════
function AorusUI.addToggle(page, label, default, onChange, order)
    local state = default or false
    local ROW_H = 40

    local row = make("Frame", {
        Size = UDim2.new(1,0,0,ROW_H),
        BackgroundColor3 = C.panel,
        BorderSizePixel = 0,
        LayoutOrder = order or 1,
        ClipsDescendants = true,
    }, page)
    make("UICorner", { CornerRadius = UDim.new(0,8) }, row)

    -- Status dot (left, matches the green/grey circle in reference)
    local dot = make("Frame", {
        Size = UDim2.fromOffset(10,10),
        Position = UDim2.new(0,14,0.5,0),
        AnchorPoint = Vector2.new(0,0.5),
        BackgroundColor3 = state and C.accent or C.border,
        BorderSizePixel = 0,
    }, row)
    make("UICorner", { CornerRadius = UDim.new(1,0) }, dot)

    -- Label
    make("TextLabel", {
        Size = UDim2.new(1,-120,1,0),
        Position = UDim2.fromOffset(34,0),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = state and C.text or C.textDim,
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    -- Wrench/config button (right side — matches reference)
    local configBtn = make("TextButton", {
        Size = UDim2.fromOffset(70, ROW_H),
        Position = UDim2.new(1,-70,0,0),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
        Text = "⚙",
        TextColor3 = C.textDim,
        Font = Enum.Font.Gotham,
        TextSize = 14,
        AutoButtonColor = false,
    }, row)
    make("UICorner", {
        CornerRadius = UDim.new(0,8),
    }, configBtn)

    -- Click area (whole row toggles)
    local clickArea = make("TextButton", {
        Size = UDim2.new(1,-74,1,0),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 2,
    }, row)

    local textLabel = row:FindFirstChildOfClass("TextLabel")

    local function setState(val)
        state = val
        pcall(tween, dot, { BackgroundColor3 = state and C.accent or C.border }, 0.15)
        if textLabel then
            pcall(tween, textLabel, { TextColor3 = state and C.text or C.textDim }, 0.15)
        end
        if onChange then
            local ok, err = pcall(onChange, state)
            if not ok then
                warn("[AorusUI] toggle '" .. tostring(label) .. "' onChange error: " .. tostring(err))
            end
        end
    end

    clickArea.MouseButton1Click:Connect(function()
        setState(not state)
    end)
    clickArea.MouseEnter:Connect(function()
        tween(row, { BackgroundColor3 = Color3.fromRGB(28,35,44) }, 0.1)
    end)
    clickArea.MouseLeave:Connect(function()
        tween(row, { BackgroundColor3 = C.panel }, 0.1)
    end)

    local toggle = {
        frame     = row,
        dot       = dot,
        configBtn = configBtn,
        get       = function() return state end,
        set       = setState,
    }

    -- Config button callback
    function toggle:onConfig(fn)
        self.configBtn.MouseButton1Click:Connect(function(...)
            local ok, err = pcall(fn, ...)
            if not ok then
                warn("[AorusUI] toggle '" .. tostring(label) .. "' onConfig error: " .. tostring(err))
            end
        end)
    end

    return toggle
end

-- ════════════════════════════════════════════════════════════
--   COLOR PICKER  (small inline color swatch row)
-- ════════════════════════════════════════════════════════════
function AorusUI.addColorRow(page, label, default, onChange, order)
    local color = default or C.espGreen
    local ROW_H = 36

    local row = make("Frame", {
        Size = UDim2.new(1,0,0,ROW_H),
        BackgroundColor3 = C.panel,
        BorderSizePixel = 0,
        LayoutOrder = order or 1,
    }, page)
    make("UICorner", { CornerRadius = UDim.new(0,8) }, row)

    make("TextLabel", {
        Size = UDim2.new(1,-80,1,0),
        Position = UDim2.fromOffset(14,0),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = C.textDim,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local swatch = make("TextButton", {
        Size = UDim2.fromOffset(56,22),
        Position = UDim2.new(1,-68,0.5,0),
        AnchorPoint = Vector2.new(0,0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    }, row)
    make("UICorner", { CornerRadius = UDim.new(0,6) }, swatch)
    make("UIStroke", { Color = C.border, Thickness = 1 }, swatch)

    return {
        frame  = row,
        swatch = swatch,
        get    = function() return color end,
        set    = function(c) color = c; swatch.BackgroundColor3 = c; if onChange then onChange(c) end end,
    }
end

-- ════════════════════════════════════════════════════════════
--   USAGE EXAMPLE  (run this block to try the library)
-- ════════════════════════════════════════════════════════════
--[[

-- 1. Login gate
local login = AorusUI.createLogin({
    logoText = "AORUS",
    subtitle = "ESP",

    -- Adds a "GET KEY" button below LOGIN.
    -- Clicking it copies this link to the user's clipboard.
    keyFromExternal = "https://discord.gg/yourserver",

    onLogin = function(key)
        return key == "MY_KEY_HERE"
    end,
})

-- 2. After login, build main window
local win = AorusUI.createWindow({ subtitle = "1" })

-- 3. ESP tab
local espPage = win:addTab("", "ESP", 1)

AorusUI.addSection(espPage, "Players", 1)
local tDetails = AorusUI.addToggle(espPage, "Details", true,  function(v) end, 2)
local tLine    = AorusUI.addToggle(espPage, "Line",    false, function(v) end, 3)
local tBox     = AorusUI.addToggle(espPage, "Box",     true,  function(v) end, 4)
local tHealth  = AorusUI.addToggle(espPage, "Health",  true,  function(v) end, 5)

AorusUI.addSection(espPage, "Bots", 6)
local tBotDetails = AorusUI.addToggle(espPage, "Details", true,  function(v) end, 7)
local tBotLine    = AorusUI.addToggle(espPage, "Line",    false, function(v) end, 8)
local tBotBox     = AorusUI.addToggle(espPage, "Box",     true,  function(v) end, 9)
local tBotHealth  = AorusUI.addToggle(espPage, "Health",  true,  function(v) end, 10)

-- 4. ESP render loop
local espSets = {}
local cam = workspace.CurrentCamera

RunService.RenderStepped:Connect(function()
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local char = plr.Character
            if not espSets[char] then
                espSets[char] = AorusUI.newESPSet(true)
                char.AncestryChanged:Connect(function()
                    if not char:IsDescendantOf(game) then
                        AorusUI.removeESP(espSets[char])
                        espSets[char] = nil
                    end
                end)
            end
            AorusUI.updateESP(espSets[char], char, cam, {
                showBox     = tBox.get(),
                showLine    = tLine.get(),
                showHealth  = tHealth.get(),
                showDetails = tDetails.get(),
            })
        end
    end
end)

]]

-- ════════════════════════════════════════════════════════════
--   SAFETY WRAPPER
--   Wraps every public AorusUI.* function in xpcall so that if
--   a future Roblox/executor/game update breaks an internal
--   assumption (e.g. a renamed Instance, changed API surface),
--   the error is caught and logged instead of hard-crashing the
--   whole script. On failure the wrapped call returns nil (or
--   opts.fallback if supplied as an extra hidden arg).
-- ════════════════════════════════════════════════════════════
local function safeWrap(name, fn)
    return function(...)
        local args = { ... }
        local ok, result = xpcall(function()
            return fn(table.unpack(args))
        end, function(err)
            local trace = debug.traceback and debug.traceback(err, 2) or err
            warn(("[AorusUI] '%s' failed safely: %s"):format(name, tostring(trace)))
            return err
        end)
        if ok then
            return result
        end
        return nil
    end
end

for fnName, fn in pairs(AorusUI) do
    if type(fn) == "function" then
        AorusUI[fnName] = safeWrap(fnName, fn)
    end
end

return AorusUI
