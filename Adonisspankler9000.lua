-- ============================================================
--   AdonisKill v2.0.0
--   Custom bypass for updated Adonis anti.luau
--   Targets every detector in the new anti:
--     1. getgenv() detection (Detected function env check)
--     2. Metamethod integrity checks (index/newindex/namecall on Instance + Enum)
--     3. Call stack fingerprinting (checkStack)
--     4. debug.info() tamper check on Detected itself
--     5. TableCheck coroutine integrity loop
--     6. Kick function hook detectors (0x3, 0x4, 0x6)
--     7. GetLogHistory hook detector
--     8. FireServer / InvokeServer hook detectors
--     9. Proxy metaMethod trap (proxyDetector)
--    10. FPS detection hook check
-- ============================================================

-- ── Fallbacks for executors that lack some functions ─────────
local newcclosure       = newcclosure       or function(f) return f end
local hookfunction      = hookfunction      or function(_, new) return new end
local getrawmetatable   = getrawmetatable   or function() return nil end
local setreadonly       = setreadonly       or function() end
local checkcaller       = checkcaller       or function() return false end
local getnamecallmethod = getnamecallmethod or function() return "" end
local clonefunction     = clonefunction     or function(f) return f end

-- ── Step 1: Wipe getgenv from every env layer ─────────────────
-- The Detected() function calls getfenv() on the running coroutine.
-- If getgenv exists in that env it immediately crashes the game.
-- We nuke it from the global table AND freeze getfenv to return a
-- sanitised env for any future call.
do
    local realGetfenv = getfenv
    local keysToHide = {
        "getgenv", "getgc", "getrenv", "hookfunction", "newcclosure",
        "checkcaller", "cloneref", "getrawmetatable", "setreadonly",
        "isreadonly", "setstackhidden", "clonefunction", "getnamecallmethod",
        "loadstring",
    }

    -- Wipe from the current global env
    local env = realGetfenv()
    for _, k in ipairs(keysToHide) do
        pcall(rawset, env, k, nil)
    end

    -- Replace getfenv so any future call (including Detected's own check)
    -- returns an env that looks like a clean Roblox LocalScript env
    local fakeGetfenv = newcclosure(function(level)
        local result = realGetfenv(level)
        if type(result) == "table" then
            for _, k in ipairs(keysToHide) do
                if rawget(result, k) then
                    pcall(rawset, result, k, nil)
                end
            end
            -- Ensure _G, shared, game are present so the second branch
            -- of Detected (the else-if) doesn't trigger either
            if not rawget(result, "_G")     then pcall(rawset, result, "_G",     _G)     end
            if not rawget(result, "shared") then pcall(rawset, result, "shared", shared) end
            if not rawget(result, "game")   then pcall(rawset, result, "game",   game)   end
        end
        return result
    end)
    pcall(rawset, env, "getfenv", fakeGetfenv)
end

-- ── Step 2: Protect game/__namecall/__index/__newindex metamethods ─
-- The new anti calls isMethamethodValid() on every captured metamethod,
-- checking: type=="function", source=="[C]", line==-1, name=="", argN==0
-- It also calls checkStack() which fingerprints debug.info frames 3 & 4.
-- Our hookmetamethod hooks change those properties → detected.
--
-- Solution: hook BEFORE Adonis captures the first callstack snapshot.
-- We wrap the metamethods so they:
--   a) pass the isMethamethodValid checks (we return the original C func)
--   b) intercept only FireServer / InvokeServer calls we care about,
--      and let everything else through untouched via the original.
do
    local mt = getrawmetatable(game)
    if mt then
        pcall(setreadonly, mt, false)

        local originalNamecall = rawget(mt, "__namecall")

        -- Whitelist of method names we want to silently swallow
        local BLOCKED_METHODS = {
            ["Detected"]  = true,  -- just in case
        }

        -- Methods on specific remotes we want to block
        local function shouldBlock(self, method)
            -- Block ExecutorDetection FireServer (from our own scripts)
            if method == "FireServer" then
                local ok, name = pcall(function() return self.Name end)
                if ok and name == "ExecutorDetection" then return true end
            end
            return false
        end

        if originalNamecall then
            rawset(mt, "__namecall", newcclosure(function(self, ...)
                local method = getnamecallmethod()
                if not checkcaller() and shouldBlock(self, method) then
                    return nil
                end
                return originalNamecall(self, ...)
            end))
        end

        pcall(setreadonly, mt, true)
    end
end

-- ── Step 3: Spoof debug.info on the Detected function ──────────
-- The anti runs a persistent loop:
--   source, line, argN, isVararg, name, closure = debug.info(Detected, "slanf")
-- If any of those values change (because we hooked Detected) it infinite-loops.
-- We don't hook Detected at all — we leave it completely untouched.
-- Instead we ensure none of our hooks alter it indirectly.
-- (No action needed here — the key is NOT to hook Detected itself.)

-- ── Step 4: FireServer / InvokeServer spoof-check bypass ───────
-- Adonis checks three call patterns for each remote method and validates
-- the exact error messages returned. If we've hooked FireServer the errors
-- change and it detects us.
-- The check creates its OWN fresh RemoteEvent/RemoteFunction instances via
-- service.UnWrap(Instance.new(...)) — so we can't pre-hook a known remote.
-- 
-- Solution: hook at the __namecall level (done in Step 2) with checkcaller()
-- guard, so only game-originated calls get intercepted, not Adonis's own
-- internal spoof-check calls which come from a trusted coroutine.
-- This means the Adonis spoof-check sees the real error messages and passes,
-- while our ExecutorDetection block still works.

-- ── Step 5: GetLogHistory spoof-check bypass ───────────────────
-- Same pattern as FireServer — Adonis calls getlogHistory (lowercase) and
-- validates the error message contains the LogService's full name.
-- We don't hook LogService at all, so these checks pass naturally.

-- ── Step 6: Kick function hook detectors ───────────────────────
-- Adonis tests three kick patterns:
--   0x3: Player.Kick(workspace, ...) → expects specific error
--   0x4: Player:KicK(...) → expects member-not-found error
--   0x6: LocalPlayer.Kick(otherPlayer, ...) → expects "non-local Player" error
-- If we've hooked Kick these error messages change.
-- We do NOT hook Kick — we only block the server-side Detected remote.

-- ── Step 7: TableCheck coroutine integrity loop ────────────────
-- Runs every 1s, compares client.Core/Remote/Functions/Anti/etc references.
-- These are Adonis's own internal tables. We never touch them → passes.

-- ── Step 8: Block the Detected remote from reaching server ─────
-- Even after all the above, if somehow Detected() gets called and
-- NetworkClient is present, it fires a "Detected" RemoteEvent to the server.
-- We intercept that via the __namecall hook in Step 2 by blocking
-- any FireServer call where self.Name == "ExecutorDetection".
-- Additionally we hook ReplicatedStorage for the named remote:
do
    local RS = game:GetService("ReplicatedStorage")

    local function hookDetectedRemote(re)
        if not re or typeof(re) ~= "Instance" or not re:IsA("RemoteEvent") then return end
        -- Wrap FireServer on this specific instance to be a no-op
        local imt = getrawmetatable(re)
        if imt then
            -- Already handled by global __namecall hook — this is a belt-and-suspenders
            -- fallback using hookfunction on the bound method if available
            pcall(function()
                local orig = re.FireServer
                hookfunction(orig, newcclosure(function() end))
            end)
        end
    end

    -- Hook any remote named "Detected" or known Adonis report names
    local BLOCKED_REMOTE_NAMES = {
        ["ExecutorDetection"] = true,
        ["Detected"]          = true,
    }

    for _, child in ipairs(RS:GetChildren()) do
        if child:IsA("RemoteEvent") and BLOCKED_REMOTE_NAMES[child.Name] then
            hookDetectedRemote(child)
        end
    end

    RS.ChildAdded:Connect(function(child)
        if child:IsA("RemoteEvent") and BLOCKED_REMOTE_NAMES[child.Name] then
            task.wait(0.05)
            hookDetectedRemote(child)
        end
    end)
end

-- ── Step 9: proxyDetector trap ─────────────────────────────────
-- Adonis creates a newproxy with metamethods that call Detected().
-- It then calls pcall(metamethod, proxyDetector, ...) on its own proxy.
-- If we interact with the proxy we get kicked.
-- We never touch the proxy — it's an internal Adonis object that nothing
-- in our scripts references.

-- ── Step 10: GC scan for report() hooks ────────────────────────
-- The original adoniscries walked getgc() to hook report() functions.
-- The new anti walks getgc() in its own bypass-check (4b in our main script).
-- We don't use getgc() to hook anything — we rely on __namecall instead.

-- ── Step 11: LogService.MessageOut scan bypass ─────────────────
-- Anti_Cheat.luau hooks LogService.MessageOut and scans every console
-- message against ~80 exploit strings including "hookmetamethod",
-- "HttpGet", "newcclosure", "getgenv", "cloneref", etc.
-- It also runs GetLogHistory() every 15s and re-scans all past logs.
-- Fix: hook MessageOut's Connect so the Adonis listener never fires,
-- and wrap GetLogHistory to return a filtered copy without flagged lines.
do
    local LogService = game:GetService("LogService")

    -- Keywords that Adonis scans for (lowercased for matching)
    local FLAGGED_PATTERNS = {
        "hookmetamethod", "hookfunction", "newcclosure", "getrawmetatable",
        "getnamecallmethod", "checkcaller", "cloneref", "getgenv", "getrenv",
        "setreadonly", "isreadonly", "getsenv", "identifyexecutor",
        "getconnections", "getloadedmodules", "getconstants", "getupvalues",
        "getscriptclosure", "getscripthash", "islclosure", "writefile",
        "readfile", "loadfile", "isfile", "makefolder", "listfiles",
        "saveinstance", "queue_on_teleport", "firesignal", "gethui",
        "secure_call", "getsynasset", "getcustomasset", "rconsoleprint",
        "protect_gui", "unprotect_gui", "httpget", "setnamecallmethod",
        "unc environment check", "hookmt",
    }

    local function isFlagged(msg)
        if type(msg) ~= "string" then return false end
        local lower = string.lower(msg)
        for _, pat in ipairs(FLAGGED_PATTERNS) do
            if string.find(lower, pat, 1, true) then return true end
        end
        return false
    end

    -- Wrap GetLogHistory to strip flagged entries before returning
    local lmt = getrawmetatable(LogService)
    if lmt then
        pcall(setreadonly, lmt, false)
        local originalNamecall = rawget(lmt, "__namecall")
        if originalNamecall then
            rawset(lmt, "__namecall", newcclosure(function(self, ...)
                local method = getnamecallmethod()
                if (self == LogService or typeof(self) == "Instance")
                    and (method == "GetLogHistory" or method == "getlogHistory") then
                    local ok, result = pcall(originalNamecall, self, ...)
                    if ok and type(result) == "table" then
                        local filtered = {}
                        for _, entry in ipairs(result) do
                            if not isFlagged(entry.message) then
                                table.insert(filtered, entry)
                            end
                        end
                        return filtered
                    end
                    return ok and result or {}
                end
                return originalNamecall(self, ...)
            end))
        end
        pcall(setreadonly, lmt, true)
    end

    -- Also suppress MessageOut from firing for flagged messages
    -- by hooking the signal's Connect method so Adonis's listener
    -- receives a wrapped callback that silently skips flagged output
    pcall(function()
        local msgOut = LogService.MessageOut
        local msgMt  = getrawmetatable(msgOut)
        if msgMt then
            pcall(setreadonly, msgMt, false)
            local origConnect = rawget(msgMt, "__namecall")
            if origConnect then
                rawset(msgMt, "__namecall", newcclosure(function(self, ...)
                    local method = getnamecallmethod()
                    if method == "Connect" and self == msgOut then
                        local userCallback = select(1, ...)
                        if type(userCallback) == "function" and not checkcaller() then
                            -- Wrap the callback to silently drop flagged messages
                            local wrappedCallback = newcclosure(function(msg, msgType)
                                if not isFlagged(msg) then
                                    userCallback(msg, msgType)
                                end
                            end)
                            return origConnect(self, wrappedCallback)
                        end
                    end
                    return origConnect(self, ...)
                end))
            end
            pcall(setreadonly, msgMt, true)
        end
    end)
end

-- ── Step 12: loadstring usability check bypass ─────────────────
-- Every 15s Anti_Cheat.luau calls loadstring("print(...)") and if it
-- SUCCEEDS (no error) it crashes you — because in vanilla Roblox
-- loadstring is disabled. Executors re-enable it, which flags you.
-- Fix: temporarily make loadstring return nil + error when called
-- from a non-executor context (checkcaller() == false).
do
    local realLoadstring = loadstring
    if realLoadstring and hookfunction then
        hookfunction(realLoadstring, newcclosure(function(src, ...)
            if checkcaller() then
                -- Executor code calling loadstring — allow it
                return realLoadstring(src, ...)
            else
                -- Game code calling loadstring — return vanilla behavior (fail)
                return nil, "loadstring is not available"
            end
        end))
    end
end

-- ── Done ───────────────────────────────────────────────────────
print("[AdonisKill v2] Bypass installed.")
