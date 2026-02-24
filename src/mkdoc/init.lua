local mkdoc = {}

setmetatable(mkdoc, {
    __index = function(t,k)
        local m = require("mkdoc."..k)
        t[k] = m
        return m
    end
})

return mkdoc
