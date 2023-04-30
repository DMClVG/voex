local remote_mt = {
    __index = function(t, k)
        return t.inner[k]
    end,
    __newindex = function(t, k, v)
        if t.inner[k] ~= v then
            t.inner[k] = v
            t.edits[k] = true
        end
    end
}

return function(x, y, z, id)
    local e = loex.entity.new(x, y, z, id)
    e:tag("remote")
    e.remote = { inner = {}, edits = {} }
    setmetatable(e.remote, remote_mt)
    return e
end
