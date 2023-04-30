local packets = {}

function packets.place(x, y, z, t)
    return ("[type=place;x=%d;y=%d;z=%d;t=%d;]"):format(x, y, z, t)
end

function packets.breaktile(x, y, z)
    return ("[type=breaktile;x=%d;y=%d;z=%d;]"):format(x, y, z)
end

function packets.join(username)
    return ("[type=join;username=%s;]"):format(username)
end

function packets.move(x, y, z)
    return ("[type=move;x=%f;y=%f;z=%f;]"):format(x, y, z)
end

return packets
