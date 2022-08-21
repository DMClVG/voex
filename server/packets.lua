local packets = {}

function packets.JoinSuccess(id, x, y, z)
    return ("[type=joinSuccess;x=%d;y=%d;z=%d;id=%s;]"):format(x, y, z, id)
end

function packets.Chunk(tiles, cx, cy, cz)
    return table.concat({ ("[type=chunk;cx=%d;cy=%d;cz=%d;]"):format(cx, cy, cz), tiles:getString() })
end

function packets.Placed(x, y, z, t)
    return ("[type=placed;x=%d;y=%d;z=%d;t=%d;]"):format(x, y, z, t)
end

function packets.Broken(x, y, z)
    return ("[type=broken;x=%d;y=%d;z=%d;]"):format(x, y, z)
end

function packets.EntityAdd(id, type, x, y, z)
    return ("[type=entityAdd;eType=%s;x=%f;y=%f;z=%f;id=%s;]"):format(type, x, y, z, id)
end

function packets.EntityRemove(id)
    return ("[type=entityRemove;id=%s;]"):format(id)
end

function packets.EntityMoved(id, x, y, z)
    return ("[type=entityMoved;x=%f;y=%f;z=%f;id=%s;]"):format(x, y, z, id)
end

return packets