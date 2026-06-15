local searchers = package.searchers or package.loaders

local function hasLoader(name)
    for i = 1, #searchers do
        local loader = searchers[i](name)
        if type(loader) == "function" then
            return true
        end
    end
    return false
end

local function tryrequire(name)
    if hasLoader(name) then
        return require(name)
    end
end

return tryrequire
