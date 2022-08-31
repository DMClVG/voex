local packets = {}

function packets.JoinSucceeded(id, x, y, z)
    return ("[type=JoinSucceeded;x=%d;y=%d;z=%d;id=%s;]"):format(x, y, z, id)
end

function packets.JoinFailed(cause)
    return ("[type=JoinFailed;cause=%s;]"):format(cause)
end

function packets.Chunk(tiles, cx, cy, cz)
    return table.concat({ ("[type=Chunk;cx=%d;cy=%d;cz=%d;]"):format(cx, cy, cz), tiles:getString() })
end

function packets.Placed(x, y, z, t)
    return ("[type=Placed;x=%d;y=%d;z=%d;t=%d;]"):format(x, y, z, t)
end

function packets.Broken(x, y, z)
    return ("[type=Broken;x=%d;y=%d;z=%d;]"):format(x, y, z)
end

function packets.EntityAdded(id, type, x, y, z, extra)
    local packet = ("type=EntityAdded;eType=%s;x=%f;y=%f;z=%f;id=%s;"):format(type, x, y, z, id)

    local extrapacket = {}
    if extra then
        for k, v in pairs(extra) do
            table.insert(extrapacket, k)
            table.insert(extrapacket, "=")
            table.insert(extrapacket, tostring(v))
            table.insert(extrapacket, ";")
        end
    end
    local extrapacket = table.concat(extrapacket)

    return table.concat({"[", packet, extrapacket, "]"})
end

function packets.EntityRemoved(id)
    return ("[type=EntityRemoved;id=%s;]"):format(id)
end

function packets.EntityMoved(id, x, y, z)
    return ("[type=EntityMoved;x=%f;y=%f;z=%f;id=%s;]"):format(x, y, z, id)
end


return packets