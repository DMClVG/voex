local packets = {}

function packets.Place(x, y, z, t)
    return ("[type=place;x=%d;y=%d;z=%d;t=%d;]"):format(x,y,z,t)
end

function packets.Break(x, y, z)
    return ("[type=break;x=%d;y=%d;z=%d;]"):format(x,y,z)
end

function packets.Join(username)
    return ("[type=join;username=%s;]"):format(username)
end

function packets.Move(x, y, z)
    return ("[type=move;x=%f;y=%f;z=%f;]"):format(x, y, z)
end

return packets