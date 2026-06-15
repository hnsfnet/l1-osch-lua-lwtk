-- lwtk.tryrequire
--
-- Behaves like require(name), but tolerates a *missing* module: if the module
-- cannot be located at all, tryrequire returns nil instead of raising an error.
--
-- Crucially, a module that *does* exist but fails while it is being loaded or
-- executed is NOT silenced -- that error is propagated to the caller, so genuine
-- bugs (and the difference between "no dependency installed" and "dependency is
-- broken") stay visible.
--
-- To tell "module not found" apart from "module found but failed" reliably, we
-- deliberately do NOT parse require()'s human-readable error text: that wording
-- differs between Lua 5.1 / 5.2 / 5.3 / 5.4 and LuaJIT, and could even clash
-- with a message a broken module raises itself. Instead we ask Lua's own module
-- searchers whether the module can be located:
--   * package.searchers exists on Lua 5.2+,
--   * package.loaders is the same list on Lua 5.1 / LuaJIT.
--
-- Each searcher, given a module name, returns one of:
--   * a loader (a function)  -> it located the module; it has NOT run any of the
--                               module's code yet, so this is purely a lookup;
--   * a string / nil         -> it could not find the module in its domain
--                               (e.g. no matching file on package.path);
--   * (it may also raise)    -> it located the module but the module is broken
--                               in a way detected at lookup time, e.g. a Lua file
--                               with a syntax error, or a C library missing its
--                               luaopen_* entry point.
--
-- So: if some searcher returns a loader, the module exists and we hand off to the
-- real require() (leaving load/execution errors free to propagate). If every
-- searcher merely declines (string/nil), the module genuinely does not exist and
-- we return nil. If a searcher raises, that is a real "found but broken" error
-- and we let it propagate, exactly as plain require() would.

local searchers = package.searchers or package.loaders

local function moduleExists(name)
    if not searchers then
        return false
    end
    for i = 1, #searchers do
        -- Not wrapped in pcall on purpose: a searcher that raises has found the
        -- module but cannot load it (e.g. syntax error), and that error must
        -- surface rather than be mistaken for "module not found".
        local loader = searchers[i](name)
        if type(loader) == "function" then
            return true
        end
    end
    return false
end

local function tryrequire(name)
    -- Fast path: an already-loaded module is handed back from require()'s cache,
    -- and stays available even if its source file was removed after loading.
    if package.loaded[name] ~= nil then
        return require(name)
    end
    if not moduleExists(name) then
        return nil
    end
    -- The module is locatable: load it for real. This call is intentionally left
    -- unprotected so any error raised while loading or executing the module
    -- propagates to the caller. Returning the call directly also preserves every
    -- value require() yields (e.g. the optional loader data as a second result).
    return require(name)
end

return tryrequire
