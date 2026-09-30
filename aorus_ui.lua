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
    bg          = Color3.fromRGB(14,  18,  24),   -- slightly warmer dark
    panel       = Color3.fromRGB(23,  28,  36),
    card        = Color3.fromRGB(32,  42,  56),
    border      = Color3.fromRGB(52,  58,  68),
    accent      = Color3.fromRGB(0,   195, 145),  -- slightly less neon
    accentDim   = Color3.fromRGB(0,   135, 100),
    text        = Color3.fromRGB(225, 232, 240),  -- slightly softer white
    textDim     = Color3.fromRGB(130, 140, 152),
    danger      = Color3.fromRGB(240, 85,  78),
    yellow      = Color3.fromRGB(255, 210, 75),
    white       = Color3.fromRGB(255, 255, 255),
    espGreen    = Color3.fromRGB(0,   245, 135),
    espRed      = Color3.fromRGB(255, 65,  65),
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
    lines[1].From = Vector2.new(x1, y1)       lines[1].To = Vector2.new(x1+len, y1)
    lines[2].From = Vector2.new(x1, y1)       lines[2].To = Vector2.new(x1, y1+len)
    lines[3].From = Vector2.new(x2, y1)       lines[3].To = Vector2.new(x2-len, y1)
    lines[4].From = Vector2.new(x2, y1)       lines[4].To = Vector2.new(x2, y1+len)
    lines[5].From = Vector2.new(x1, y2)       lines[5].To = Vector2.new(x1+len, y2)
    lines[6].From = Vector2.new(x1, y2)       lines[6].To = Vector2.new(x1, y2-len)
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

-- 2D full rectangle: 4 lines reusing the first 4 slots of the bracket table
local function update2DBox(lines, x1, y1, x2, y2)
    lines[1].From = Vector2.new(x1, y1) lines[1].To = Vector2.new(x2, y1)  -- top
    lines[2].From = Vector2.new(x2, y1) lines[2].To = Vector2.new(x2, y2)  -- right
    lines[3].From = Vector2.new(x2, y2) lines[3].To = Vector2.new(x1, y2)  -- bottom
    lines[4].From = Vector2.new(x1, y2) lines[4].To = Vector2.new(x1, y1)  -- left
    for i = 1, 4 do lines[i].Visible = true  end
    for i = 5, 8 do lines[i].Visible = false end  -- hide unused corners
end

-- 3D box: projects a world-space box around the HRP into screen space.
-- Expects d.box3d = table of 12 Drawing.Line objects.
local function update3DBox(lines, hrp, cam, width, height)
    -- build 8 world corners from the 2D screen bounds back to world
    -- approximation: offset half-widths in camera-relative X/Z
    local cf   = hrp.CFrame
    local hw   = width  * sp_z_placeholder  -- filled at call site
    local hh   = height * sp_z_placeholder
    -- We project the 8 corners of a world AABB around the character
    local pos  = hrp.Position
    local offX = cf.RightVector   * hw
    local offY = Vector3.new(0, hh, 0)
    local offZ = cf.LookVector    * hw

    local corners = {
        pos + offX + offY + offZ,  -- front top right
        pos - offX + offY + offZ,  -- front top left
        pos + offX - offY + offZ,  -- front bot right
        pos - offX - offY + offZ,  -- front bot left
        pos + offX + offY - offZ,  -- back top right
        pos - offX + offY - offZ,  -- back top left
        pos + offX - offY - offZ,  -- back bot right
        pos - offX - offY - offZ,  -- back bot left
    }

    local sc = {}
    for _, c in ipairs(corners) do
        local s, onScreen = cam:WorldToViewportPoint(c)
        table.insert(sc, { x = s.X, y = s.Y, vis = onScreen and s.Z > 0 })
    end

    -- 12 edges: 4 front, 4 back, 4 connecting
    local edges = {
        {1,2},{3,4},{1,3},{2,4},  -- front face
        {5,6},{7,8},{5,7},{6,8},  -- back face
        {1,5},{2,6},{3,7},{4,8},  -- connecting
    }
    for i, e in ipairs(edges) do
        local a, b = sc[e[1]], sc[e[2]]
        if a.vis and b.vis then
            lines[i].From    = Vector2.new(a.x, a.y)
            lines[i].To      = Vector2.new(b.x, b.y)
            lines[i].Visible = true
        else
            lines[i].Visible = false
        end
    end
end

local function hide3DBox(lines)
    for _, l in ipairs(lines) do l.Visible = false end
end

local function remove3DBox(lines)
    for _, l in ipairs(lines) do l:Remove() end
end

-- ── ESP Drawing Set ──────────────────────────────────────────
function AorusUI.newESPSet(isPlayer)
    local d = {}
    local espColor = isPlayer and C.espGreen or C.espRed
    -- Corner bracket / 2D box (8 lines, shared for both modes)
    d.box       = makeCornerBracket(espColor, 1.5, 8)
    -- 3D box (12 lines, hidden unless boxMode == "3D")
    d.box3d = {}
    for i = 1, 12 do
        local l = Drawing.new("Line")
        l.Color     = espColor
        l.Thickness = 1
        l.Visible   = false
        table.insert(d.box3d, l)
    end
    -- Tracer line
    d.tracer    = Drawing.new("Line")
    d.tracer.Color     = espColor
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
    -- Health text label (used when healthMode == "Text")
    d.healthLabel = makeLabel(10, C.text)
    d.healthLabel.Center = true
    -- Labels
    local function makeLabel(size, color, outline)
        local l = Drawing.new("Text")
        l.Size         = size or 11
        l.Color        = color or C.text
        l.Outline      = outline ~= false
        l.OutlineColor = Color3.fromRGB(0,0,0)
        l.Visible      = false
        l.Center       = true
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
    -- new mode opts (strings; fall back to defaults if nil)
    local boxMode     = opts.boxMode     or "Corner"   -- "Corner" | "2D" | "3D"
    local tracerPos   = opts.tracerPos   or "Bottom"   -- "Bottom" | "Top" | "Middle"
    local detailsMode = opts.detailsMode or "All"      -- "All" | "Name" | "Distance" | "Tool"
    local healthMode  = opts.healthMode  or "Bar"      -- "Bar" | "Text" | "Both"

    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then
        AorusUI.hideESP(d) return
    end

    local sp, onScreen = cam:WorldToViewportPoint(hrp.Position)
    if not onScreen or sp.Z < 0 then
        AorusUI.hideESP(d) return
    end

    local dist   = math.floor((hrp.Position - cam.CFrame.Position).Magnitude)
    local height = 5.5 / sp.Z * 100
    local width  = height * 0.45
    local sx, sy = sp.X, sp.Y
    local x1, y1 = sx - width,  sy - height
    local x2, y2 = sx + width,  sy + height

    -- ── Box ────────────────────────────────────────────────────
    if showBox then
        if boxMode == "3D" then
            hideCornerBracket(d.box)
            -- project 8 world corners
            local pos  = hrp.Position
            local cf   = hrp.CFrame
            local hw   = width  / sp.Z * sp.Z   -- = width (already in screen units; convert back)
            -- use studs: width is ~0.45 * 5.5 = ~2.5 studs half-width
            local hsW  = 2.5
            local hsH  = 5.5 * 0.5
            local rV   = cf.RightVector
            local uV   = Vector3.new(0, 1, 0)
            local lV   = cf.LookVector
            local corners3d = {
                pos + rV*hsW + uV*hsH + lV*hsW,
                pos - rV*hsW + uV*hsH + lV*hsW,
                pos + rV*hsW - uV*hsH + lV*hsW,
                pos - rV*hsW - uV*hsH + lV*hsW,
                pos + rV*hsW + uV*hsH - lV*hsW,
                pos - rV*hsW + uV*hsH - lV*hsW,
                pos + rV*hsW - uV*hsH - lV*hsW,
                pos - rV*hsW - uV*hsH - lV*hsW,
            }
            local sc3 = {}
            for _, c in ipairs(corners3d) do
                local s, vis = cam:WorldToViewportPoint(c)
                table.insert(sc3, { x = s.X, y = s.Y, ok = vis and s.Z > 0 })
            end
            local edges = {
                {1,2},{3,4},{1,3},{2,4},
                {5,6},{7,8},{5,7},{6,8},
                {1,5},{2,6},{3,7},{4,8},
            }
            for i, e in ipairs(edges) do
                local a, b = sc3[e[1]], sc3[e[2]]
                if a.ok and b.ok then
                    d.box3d[i].From    = Vector2.new(a.x, a.y)
                    d.box3d[i].To      = Vector2.new(b.x, b.y)
                    d.box3d[i].Visible = true
                else
                    d.box3d[i].Visible = false
                end
            end
        else
            hide3DBox(d.box3d)
            if boxMode == "2D" then
                update2DBox(d.box, x1, y1, x2, y2)
            else
                -- "Corner" (default)
                updateCornerBracket(d.box, x1, y1, x2, y2, math.max(6, width * 0.35))
            end
        end
    else
        hideCornerBracket(d.box)
        hide3DBox(d.box3d)
    end

    -- ── Tracer ─────────────────────────────────────────────────
    if showLine then
        local vp = cam.ViewportSize
        local fromY
        if tracerPos == "Top" then
            fromY = 0
        elseif tracerPos == "Middle" then
            fromY = vp.Y * 0.5
        else
            fromY = vp.Y   -- "Bottom"
        end
        d.tracer.From    = Vector2.new(vp.X * 0.5, fromY)
        d.tracer.To      = Vector2.new(sx, tracerPos == "Top" and y1 or y2)
        d.tracer.Visible = true
    else
        d.tracer.Visible = false
    end

    -- ── Health ─────────────────────────────────────────────────
    if showHealth then
        local hp    = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
        local healthColor = Color3.fromRGB(
            math.floor(255 * (1 - hp)),
            math.floor(255 * hp),
            60
        )
        local showBar  = healthMode == "Bar"  or healthMode == "Both"
        local showText = healthMode == "Text" or healthMode == "Both"

        if showBar then
            local barW  = 3
            local barX  = x1 - barW - 2
            local barH  = y2 - y1
            local fillH = barH * hp
            d.healthBG.Position  = Vector2.new(barX, y1)
            d.healthBG.Size      = Vector2.new(barW, barH)
            d.healthBG.Visible   = true
            d.healthFill.Color    = healthColor
            d.healthFill.Position = Vector2.new(barX, y2 - fillH)
            d.healthFill.Size     = Vector2.new(barW, fillH)
            d.healthFill.Visible  = true
        else
            d.healthBG.Visible   = false
            d.healthFill.Visible = false
        end

        if showText then
            local hp100 = math.floor(hp * hum.MaxHealth)
            -- position: right of the box, vertically centred; or below bar if Both
            local textX = showBar and (x2 + 5) or (x1 - 5)
            local textY = (y1 + y2) * 0.5 - 5
            d.healthLabel.Text     = tostring(hp100) .. " HP"
            d.healthLabel.Color    = healthColor
            d.healthLabel.Position = Vector2.new(textX, textY)
            d.healthLabel.Center   = not showBar  -- centre only when bar is hidden
            d.healthLabel.Visible  = true
        else
            d.healthLabel.Visible = false
        end
    else
        d.healthBG.Visible    = false
        d.healthFill.Visible  = false
        d.healthLabel.Visible = false
    end

    -- ── Details ────────────────────────────────────────────────
    if showDetails then
        local showName = detailsMode == "All" or detailsMode == "Name"
        local showDist = detailsMode == "All" or detailsMode == "Distance"
        local showTool = detailsMode == "All" or detailsMode == "Tool"

        if showName then
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
        else
            d.nameLabel.Visible = false
        end

        if showDist then
            d.distLabel.Position = Vector2.new(sx, y2 + 2)
            d.distLabel.Text     = dist .. "m"
            d.distLabel.Visible  = true
        else
            d.distLabel.Visible = false
        end

        if showTool and d._isPlayer then
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then
                d.toolLabel.Position = Vector2.new(sx, y2 + 13)
                d.toolLabel.Text     = "[" .. tool.Name .. "]"
                d.toolLabel.Visible  = true
            else
                d.toolLabel.Visible = false
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
    hide3DBox(d.box3d)
    d.tracer.Visible      = false
    d.healthBG.Visible    = false
    d.healthFill.Visible  = false
    d.healthLabel.Visible = false
    d.nameLabel.Visible   = false
    d.distLabel.Visible   = false
    d.toolLabel.Visible   = false
end

function AorusUI.removeESP(d)
    removeCornerBracket(d.box)
    remove3DBox(d.box3d)
    d.tracer:Remove()
    d.healthBG:Remove()
    d.healthFill:Remove()
    d.healthLabel:Remove()
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
    -- opts.version  : string shown top-right of screen (default "v3")

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

    -- Version label — top-right of screen, always visible
    make("TextLabel", {
        Size            = UDim2.fromOffset(80, 20),
        Position        = UDim2.new(1, -88, 0, 8),
        AnchorPoint     = Vector2.new(0, 0),
        BackgroundTransparency = 1,
        Text            = opts.version or "v3",
        TextColor3      = C.textDim,
        Font            = Enum.Font.GothamBold,
        TextSize        = 11,
        TextXAlignment  = Enum.TextXAlignment.Right,
        ZIndex          = 20,
    }, sg)

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

    -- Close button (top-right of header)
    local closeBtn = make("TextButton", {
        Size            = UDim2.fromOffset(28, 28),
        Position        = UDim2.new(1, -8, 0.5, 0),
        AnchorPoint     = Vector2.new(1, 0.5),
        BackgroundColor3 = Color3.fromRGB(60, 20, 20),
        BorderSizePixel = 0,
        Text            = "✕",
        TextColor3      = Color3.fromRGB(220, 100, 100),
        Font            = Enum.Font.GothamBold,
        TextSize        = 13,
        AutoButtonColor = false,
        ZIndex          = 5,
    }, header)
    make("UICorner", { CornerRadius = UDim.new(0, 6) }, closeBtn)

    closeBtn.MouseEnter:Connect(function()
        tween(closeBtn, { BackgroundColor3 = Color3.fromRGB(90, 25, 25) }, 0.1)
    end)
    closeBtn.MouseLeave:Connect(function()
        tween(closeBtn, { BackgroundColor3 = Color3.fromRGB(60, 20, 20) }, 0.1)
    end)

    -- Floating reopen button (hidden until window is closed)
    local reopenBtn = make("TextButton", {
        Size            = UDim2.fromOffset(36, 36),
        Position        = UDim2.fromOffset(12, 60),
        BackgroundColor3 = C.panel,
        BorderSizePixel = 0,
        Text            = "◈",
        TextColor3      = C.accent,
        Font            = Enum.Font.GothamBold,
        TextSize        = 16,
        AutoButtonColor = false,
        Visible         = false,
        ZIndex          = 10,
    }, sg)
    make("UICorner", { CornerRadius = UDim.new(0, 8) }, reopenBtn)
    make("UIStroke", { Color = C.accent, Thickness = 1 }, reopenBtn)
    makeDraggable(reopenBtn)

    reopenBtn.MouseEnter:Connect(function()
        tween(reopenBtn, { BackgroundColor3 = C.card }, 0.1)
    end)
    reopenBtn.MouseLeave:Connect(function()
        tween(reopenBtn, { BackgroundColor3 = C.panel }, 0.1)
    end)

    closeBtn.MouseButton1Click:Connect(function()
        tween(win, { Size = UDim2.fromOffset(WIN_W, 0) }, 0.18)
        task.delay(0.2, function()
            win.Visible    = false
            win.Size       = UDim2.fromOffset(WIN_W, WIN_H)
            reopenBtn.Visible = true
        end)
    end)

    reopenBtn.MouseButton1Click:Connect(function()
        reopenBtn.Visible = false
        win.Visible       = true
        win.Size          = UDim2.fromOffset(WIN_W, 0)
        tween(win, { Size = UDim2.fromOffset(WIN_W, WIN_H) }, 0.18)
    end)

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
        ScrollingEnabled = true,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.Always,
    }, content)
    make("UIPadding", {
        PaddingLeft   = UDim.new(0,12),
        PaddingRight  = UDim.new(0,10),
        PaddingTop    = UDim.new(0,8),
        PaddingBottom = UDim.new(0,14),
    }, scroll)
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        Padding       = UDim.new(0, 5),
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

    -- ── Emoji icon map ─────────────────────────────────────
    local TAB_ICONS = {
        -- ESP / vision
        eye        = "👁",
        esp        = "👁",
        -- Aimbot
        aim        = "🎯",
        aimbot     = "🎯",
        crosshair  = "🎯",
        -- Radar / map
        radar      = "🗺",
        map        = "🗺",
        compass    = "🧭",
        -- Memory / tools
        memory     = "🔧",
        wrench     = "🔧",
        tool       = "🔧",
        -- Loot / items
        loot       = "🎒",
        bag        = "🎒",
        chest      = "📦",
        -- Settings / config
        settings   = "⚙️",
        config     = "⚙️",
        gear       = "⚙️",
        -- Silent aim
        silent     = "🤫",
        -- Extraction
        extract    = "🚁",
        helicopter = "🚁",
        -- Home / info
        home       = "🏠",
        info       = "ℹ️",
        -- WIP / dev
        wip        = "🚧",
        dev        = "🚧",
        -- Log / debug
        log        = "📋",
        debug      = "🐛",
        -- Default
        block      = "■",
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
        -- Resolve icon: accept a name key ("eye", "aim" etc),
        -- a raw emoji string, or nil/empty → default "■"
        local emoji
        if not icon or icon == "" then
            emoji = TAB_ICONS.block
        elseif TAB_ICONS[icon:lower()] then
            emoji = TAB_ICONS[icon:lower()]
        else
            -- treat as a raw emoji passed directly
            emoji = icon
        end

        -- Sidebar tab button (TextButton so emoji renders natively)
        local btn = make("TextButton", {
            Size             = UDim2.fromOffset(SIDEBAR_W, SIDEBAR_W),
            BackgroundColor3 = C.panel,
            BackgroundTransparency = 0.5,
            BorderSizePixel  = 0,
            Text             = emoji,
            TextColor3       = C.textDim,
            Font             = Enum.Font.Gotham,
            TextSize         = 20,
            AutoButtonColor  = false,
            LayoutOrder      = order or #self._tabs + 1,
        }, self.sidebar)
        make("UICorner", { CornerRadius = UDim.new(0,6) }, btn)

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
            local stripFrame = b:FindFirstChildOfClass("Frame")
            if active then
                tween(b, { BackgroundTransparency = 0, BackgroundColor3 = C.card }, 0.15)
                tween(b, { TextColor3 = C.accent }, 0.15)
                if stripFrame then tween(stripFrame, { BackgroundTransparency = 0 }, 0.15) end
            else
                tween(b, { BackgroundTransparency = 0.5, BackgroundColor3 = C.panel }, 0.15)
                tween(b, { TextColor3 = C.textDim }, 0.15)
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
function AorusUI.addToggle(page, label, default, onChange, order, opts)
    local state = default or false
    local ROW_H = 40

    -- opts.modes    : array of option strings, e.g. { "Players", "Bots", "All" }
    -- opts.colors   : map of option → Color3, falls back to defaults for missing keys
    -- opts.defaultMode : which option is selected initially (defaults to last entry)
    opts = opts or {}
    local defaultModeColors = {
        Player = C.espGreen,
        Bot    = Color3.fromRGB(255, 160, 40),
        Both   = C.accent,
    }
    local modeOptions = opts.modes or { "Player", "Bot", "Both" }
    local modeColors  = opts.colors or defaultModeColors
    -- fill in any missing colors with the accent color
    for _, opt in ipairs(modeOptions) do
        if not modeColors[opt] then
            modeColors[opt] = C.accent
        end
    end
    local defaultMode = opts.defaultMode or modeOptions[#modeOptions]
    local targetMode  = defaultMode

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

    -- ⚙ Settings button — opens a small target mode picker
    local configBtn = make("TextButton", {
        Size = UDim2.fromOffset(70, ROW_H),
        Position = UDim2.new(1,-70,0,0),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
        Text = "⚙  " .. targetMode,
        TextColor3 = modeColors[targetMode] or C.textDim,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        AutoButtonColor = false,
    }, row)
    make("UICorner", { CornerRadius = UDim.new(0,8) }, configBtn)

    -- Dropdown popup (parented to row so it clips correctly)
    local dropdown = make("Frame", {
        Size            = UDim2.fromOffset(70, 0),
        Position        = UDim2.new(1,-70,1,2),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
        Visible         = false,
        ZIndex          = 20,
        ClipsDescendants = false,
    }, row)
    make("UICorner",  { CornerRadius = UDim.new(0,8) },     dropdown)
    make("UIStroke",  { Color = C.border, Thickness = 1 },  dropdown)
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        Padding       = UDim.new(0,1),
        SortOrder     = Enum.SortOrder.LayoutOrder,
    }, dropdown)

    local dropdownOpen = false

    for i, opt in ipairs(modeOptions) do
        local optBtn = make("TextButton", {
            Size            = UDim2.new(1,0,0,28),
            BackgroundColor3 = C.panel,
            BorderSizePixel  = 0,
            Text             = opt,
            TextColor3       = modeColors[opt] or C.text,
            Font             = Enum.Font.Gotham,
            TextSize         = 11,
            AutoButtonColor  = false,
            LayoutOrder      = i,
            ZIndex           = 21,
        }, dropdown)
        if i == 1 then
            make("UICorner", { CornerRadius = UDim.new(0,8) }, optBtn)
        elseif i == #modeOptions then
            make("UICorner", { CornerRadius = UDim.new(0,8) }, optBtn)
        end

        optBtn.MouseEnter:Connect(function()
            tween(optBtn, { BackgroundColor3 = C.card }, 0.08)
        end)
        optBtn.MouseLeave:Connect(function()
            tween(optBtn, { BackgroundColor3 = C.panel }, 0.08)
        end)

        optBtn.MouseButton1Click:Connect(function()
            targetMode = opt
            configBtn.Text = "⚙  " .. opt
            tween(configBtn, { TextColor3 = modeColors[opt] or C.textDim }, 0.1)
            dropdownOpen = false
            dropdown.Visible = false
        end)
    end

    -- auto-size dropdown width to fit the longest option label
    local maxOptLen = 0
    for _, opt in ipairs(modeOptions) do
        if #opt > maxOptLen then maxOptLen = #opt end
    end
    local dropW = math.max(70, maxOptLen * 7 + 20)
    dropdown.Size     = UDim2.fromOffset(dropW, #modeOptions * 29)
    dropdown.Position = UDim2.new(1, -dropW, 1, 2)
    configBtn.Size    = UDim2.fromOffset(dropW, ROW_H)
    configBtn.Position = UDim2.new(1, -dropW, 0, 0)

    configBtn.MouseButton1Click:Connect(function()
        dropdownOpen = not dropdownOpen
        dropdown.Visible = dropdownOpen
    end)

    -- Click area (whole row left-side toggles)
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
        frame      = row,
        dot        = dot,
        configBtn  = configBtn,
        get        = function() return state end,
        set        = setState,
        getMode    = function() return targetMode end,
        getOptions = function() return modeOptions end,
        setMode    = function(m)
            -- accept any option that exists in the current modeOptions list
            local valid = false
            for _, opt in ipairs(modeOptions) do
                if opt == m then valid = true break end
            end
            if valid then
                targetMode = m
                configBtn.Text = "⚙  " .. m
                tween(configBtn, { TextColor3 = modeColors[m] or C.textDim }, 0.1)
            end
        end,
    }

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
--   DEMO UI
--   Call AorusUI.demoUI() to open a fully-populated window
--   that showcases every component the library has.
--   Closes itself cleanly; safe to call multiple times.
-- ════════════════════════════════════════════════════════════
function AorusUI.demoUI()
    -- ── 1. Login demo ───────────────────────────────────────
    -- Show the login screen first; correct key is "demo"
    AorusUI.createLogin({
        logoText = "AORUS",
        subtitle = "demo",
        keyFromExternal = "https://discord.gg/demo",
        onLogin = function(key)
            if key ~= "demo" then return false end

            -- ── 2. Main window ──────────────────────────────
            local win = AorusUI.createWindow({ subtitle = "demo" })

            -- ── 3. Tabs ─────────────────────────────────────
            local espPage     = win:addTab("eye",      "ESP",      1)
            local aimPage     = win:addTab("aim",      "Aimbot",   2)
            local radarPage   = win:addTab("radar",    "Radar",    3)
            local memPage     = win:addTab("memory",   "Memory",   4)
            local settPage    = win:addTab("settings", "Settings", 5)

            -- ── 4. ESP tab ──────────────────────────────────
            local targetOpts = {
                modes  = { "Player", "Bot", "Both" },
                colors = {
                    Player = Color3.fromRGB(100, 220, 120),
                    Bot    = Color3.fromRGB(255, 160,  40),
                    Both   = Color3.fromRGB(100, 160, 255),
                },
                defaultMode = "Both",
            }

            AorusUI.addSection(espPage, "Players", 1)
            local pBox     = AorusUI.addToggle(espPage, "Box",         true,  nil, 2,  targetOpts)
            local pLine    = AorusUI.addToggle(espPage, "Tracer",      false, nil, 3,  targetOpts)
            local pHealth  = AorusUI.addToggle(espPage, "Health Bar",  true,  nil, 4,  targetOpts)
            local pDetails = AorusUI.addToggle(espPage, "Name / Info", true,  nil, 5,  targetOpts)
            local pBones   = AorusUI.addToggle(espPage, "Bones",       false, nil, 6,  targetOpts)
            local pLook    = AorusUI.addToggle(espPage, "Look Lines",  false, nil, 7,  targetOpts)
            local pChams   = AorusUI.addToggle(espPage, "Chams",       false, nil, 8,  targetOpts)

            local pBoxMode = AorusUI.addToggle(espPage, "Box Style", true, nil, 9, {
                modes  = { "Corner", "2D", "3D" },
                colors = {
                    Corner = Color3.fromRGB(100, 160, 255),
                    ["2D"] = Color3.fromRGB(100, 220, 120),
                    ["3D"] = Color3.fromRGB(255, 160,  40),
                },
                defaultMode = "Corner",
            })
            local pTracerFrom = AorusUI.addToggle(espPage, "Tracer From", false, nil, 10, {
                modes  = { "Bottom", "Top", "Middle" },
                colors = {
                    Bottom = Color3.fromRGB(100, 220, 120),
                    Top    = Color3.fromRGB(255, 160,  40),
                    Middle = Color3.fromRGB(100, 160, 255),
                },
                defaultMode = "Bottom",
            })

            AorusUI.addSection(espPage, "Colors", 11)
            AorusUI.addColorRow(espPage, "Player Color",  Color3.fromRGB(0, 245, 135), nil, 12)
            AorusUI.addColorRow(espPage, "Bot Color",     Color3.fromRGB(255, 160, 40), nil, 13)
            AorusUI.addColorRow(espPage, "Chams Color",   Color3.fromRGB(160, 80, 255), nil, 14)
            AorusUI.addColorRow(espPage, "Tracer Color",  Color3.fromRGB(255, 80, 80),  nil, 15)
            AorusUI.addColorRow(espPage, "Bone Color",    Color3.fromRGB(230, 235, 245), nil, 16)

            -- ── 5. Aimbot tab ───────────────────────────────
            AorusUI.addSection(aimPage, "Aimbot", 1)
            local aimEnabled = AorusUI.addToggle(aimPage, "Enable Aimbot", false, nil, 2)
            local aimSmooth  = AorusUI.addToggle(aimPage, "Smoothing",     true,  nil, 3)
            local aimWall    = AorusUI.addToggle(aimPage, "Wall Check",    true,  nil, 4)
            local aimTeam    = AorusUI.addToggle(aimPage, "Team Check",    true,  nil, 5)
            local aimPOV     = AorusUI.addToggle(aimPage, "FOV Circle",    true,  nil, 6)

            AorusUI.addSection(aimPage, "Target", 7)
            local aimPart = AorusUI.addToggle(aimPage, "Aim Part", true, nil, 8, {
                modes  = { "Head", "HRP", "Torso" },
                colors = {
                    Head  = Color3.fromRGB(255, 80,  80),
                    HRP   = Color3.fromRGB(100, 220, 120),
                    Torso = Color3.fromRGB(100, 160, 255),
                },
                defaultMode = "Head",
            })
            local aimType = AorusUI.addToggle(aimPage, "Target Type", true, nil, 9, {
                modes  = { "Nearest", "Lowest HP", "Highest HP", "First Seen" },
                colors = {
                    Nearest      = Color3.fromRGB(100, 220, 120),
                    ["Lowest HP"]  = Color3.fromRGB(255,  80,  80),
                    ["Highest HP"] = Color3.fromRGB(100, 160, 255),
                    ["First Seen"] = Color3.fromRGB(255, 210,  75),
                },
                defaultMode = "Nearest",
            })
            local aimMode = AorusUI.addToggle(aimPage, "Target Mode", true, nil, 10, {
                modes  = { "Player", "Npc", "Both" },
                colors = {
                    Player = Color3.fromRGB(100, 220, 120),
                    Npc    = Color3.fromRGB(255, 160,  40),
                    Both   = Color3.fromRGB(100, 160, 255),
                },
                defaultMode = "Both",
            })

            AorusUI.addSection(aimPage, "Aim Tracer", 11)
            local aimTracer = AorusUI.addToggle(aimPage, "Aim Tracer", false, nil, 12)
            AorusUI.addColorRow(aimPage, "Tracer Color", Color3.fromRGB(255, 80, 80), nil, 13)

            -- ── 6. Radar tab ────────────────────────────────
            AorusUI.addSection(radarPage, "Radar", 1)
            local radarOn   = AorusUI.addToggle(radarPage, "Enable Radar", false, nil, 2)
            local radarFOV  = AorusUI.addToggle(radarPage, "FOV Cone",     true,  nil, 3)
            local radarLook = AorusUI.addToggle(radarPage, "Look Lines",   true,  nil, 4)
            local radarSelf = AorusUI.addToggle(radarPage, "Self Dot",     true,  nil, 5)
            local radarTeam = AorusUI.addToggle(radarPage, "Team Check",   true,  nil, 6)

            local radarMode = AorusUI.addToggle(radarPage, "Target Mode", true, nil, 7, {
                modes  = { "Player", "Npc", "Both" },
                colors = {
                    Player = Color3.fromRGB(100, 220, 120),
                    Npc    = Color3.fromRGB(255, 160,  40),
                    Both   = Color3.fromRGB(100, 160, 255),
                },
                defaultMode = "Both",
            })

            AorusUI.addSection(radarPage, "Colors", 8)
            AorusUI.addColorRow(radarPage, "Player Blip",  Color3.fromRGB(255,  80,  80), nil, 9)
            AorusUI.addColorRow(radarPage, "Bot Blip",     Color3.fromRGB(255, 160,  40), nil, 10)
            AorusUI.addColorRow(radarPage, "Self Dot",     Color3.fromRGB(100, 200, 255), nil, 11)
            AorusUI.addColorRow(radarPage, "FOV Cone",     Color3.fromRGB(255, 255, 255), nil, 12)
            AorusUI.addColorRow(radarPage, "Look Lines",   Color3.fromRGB(200, 220, 255), nil, 13)

            -- ── 7. Memory tab ───────────────────────────────
            AorusUI.addSection(memPage, "Movement", 1)
            local noclip = AorusUI.addToggle(memPage, "Noclip",       false, nil, 2)
            local bhop   = AorusUI.addToggle(memPage, "Bunny Hop",    false, nil, 3)
            local infJmp = AorusUI.addToggle(memPage, "Infinite Jump", false, nil, 4)
            local flyOn  = AorusUI.addToggle(memPage, "Fly",          false, nil, 5)

            AorusUI.addSection(memPage, "Hitbox", 6)
            local hbOn   = AorusUI.addToggle(memPage, "Hitbox Expander", false, nil, 7)
            local hbVis  = AorusUI.addToggle(memPage, "Visualizer",      true,  nil, 8)
            local hbPart = AorusUI.addToggle(memPage, "Target Part", true, nil, 9, {
                modes  = { "HumanoidRootPart", "UpperTorso", "Head" },
                colors = {
                    HumanoidRootPart = Color3.fromRGB(100, 220, 120),
                    UpperTorso       = Color3.fromRGB(100, 160, 255),
                    Head             = Color3.fromRGB(255,  80,  80),
                },
                defaultMode = "HumanoidRootPart",
            })
            local hbMode = AorusUI.addToggle(memPage, "Target Mode", true, nil, 10, {
                modes  = { "Player", "Npc", "Both" },
                colors = {
                    Player = Color3.fromRGB(100, 220, 120),
                    Npc    = Color3.fromRGB(255, 160,  40),
                    Both   = Color3.fromRGB(100, 160, 255),
                },
                defaultMode = "Both",
            })
            AorusUI.addColorRow(memPage, "Visualizer Color", Color3.fromRGB(255, 80, 80), nil, 11)

            AorusUI.addSection(memPage, "Silent Aim", 12)
            local saOn   = AorusUI.addToggle(memPage, "Enable Silent", false, nil, 13)
            local saWall = AorusUI.addToggle(memPage, "Wall Check",    true,  nil, 14)
            local saTeam = AorusUI.addToggle(memPage, "Team Check",    true,  nil, 15)
            local saType = AorusUI.addToggle(memPage, "Target Type", true, nil, 16, {
                modes  = { "Nearest", "Lowest Health", "Highest Health", "First Seen" },
                colors = {
                    Nearest          = Color3.fromRGB(100, 220, 120),
                    ["Lowest Health"]  = Color3.fromRGB(255,  80,  80),
                    ["Highest Health"] = Color3.fromRGB(100, 160, 255),
                    ["First Seen"]     = Color3.fromRGB(255, 210,  75),
                },
                defaultMode = "Nearest",
            })
            local saMode = AorusUI.addToggle(memPage, "Target Mode", true, nil, 17, {
                modes  = { "Player", "Npc", "Both" },
                colors = {
                    Player = Color3.fromRGB(100, 220, 120),
                    Npc    = Color3.fromRGB(255, 160,  40),
                    Both   = Color3.fromRGB(100, 160, 255),
                },
                defaultMode = "Both",
            })

            -- ── 8. Settings tab ─────────────────────────────
            AorusUI.addSection(settPage, "Display", 1)
            local fullbright = AorusUI.addToggle(settPage, "Fullbright",    false, nil, 2)
            local noFog      = AorusUI.addToggle(settPage, "No Fog",        false, nil, 3)
            local hideUI     = AorusUI.addToggle(settPage, "Hide ESP",      false, nil, 4)
            local showFPS    = AorusUI.addToggle(settPage, "FPS Counter",   true,  nil, 5)

            AorusUI.addSection(settPage, "Keybinds", 6)
            local kbAim    = AorusUI.addToggle(settPage, "Aimbot Key",    true, nil, 7)
            local kbSilent = AorusUI.addToggle(settPage, "Silent Key",    true, nil, 8)
            local kbHide   = AorusUI.addToggle(settPage, "Hide UI Key",   true, nil, 9)

            AorusUI.addSection(settPage, "About", 10)
            AorusUI.addToggle(settPage, "Version  —  AorusUI v3", false, nil, 11)
            AorusUI.addToggle(settPage, "Mode  —  Demo",          false, nil, 12)

            return true
        end,
    })
end

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
