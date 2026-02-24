local format = string.format

local util = {}

function util.fprintf(file, ...)
    file:write(format(...))
end

function util.printf(...)
    io.write(format(...))
end

function util.append(t, v)
    t[#t + 1] = v
end

function util.addSet(t, v)
    assert(not t[v])
    t[v] = true
    t[#t + 1] = v
end
    
function util.addSetKey(t, k, v)
    assert(not t[k], k)
    assert(not t[v])
    t[k] = v
    t[v] = true
    t[#t + 1] = v
end

function util.addSetKey2(t, k1, k2, v)
    assert(not t[k1])
    assert(not t[k2])
    assert(not t[v])
    t[k1] = v
    t[k2] = v
    t[v] = true
    t[#t + 1] = v
end

function util.ListFromSet(t)
    local l = {}
    for i, e in ipairs(t) do
        l[i] = e
    end
    return l
end

function util.SortedListFromSet(t, ...)
    local l = util.ListFromSet(t)
    table.sort(l, ...)
    return l
end

function util.SetFromList(l)
    local s = {}
    for _, e in ipairs(l) do
        s[e] = true
    end
    return s
end

function util.ASSERT(cond, ...)
    if not cond then
        error(format("ASSERT failed: %s", require"inspect"{...}), 2)
    end
end

function util.PRINT(msg, ...)
    print(msg, require"inspect"{...})
end

return util
