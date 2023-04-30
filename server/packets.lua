local packets = {}

function packets.joinsuccess(id, x, y, z) return ("[type=joinsuccess;x=%d;y=%d;z=%d;id=%s;]"):format(x, y, z, id) end

function packets.joinfailure(cause) return ("[type=joinfailure;cause=%s;]"):format(cause) end

function packets.chunkadd(tiles, cx, cy, cz)
  return table.concat { ("[type=chunkadd;cx=%d;cy=%d;cz=%d;]"):format(cx, cy, cz), tiles }
end

function packets.chunkremove(cx, cy, cz) return ("[type=chunkremove;cx=%d;cy=%d;cz=%d;]"):format(cx, cy, cz) end

function packets.placed(x, y, z, t) return ("[type=placed;x=%d;y=%d;z=%d;t=%d;]"):format(x, y, z, t) end

function packets.broken(x, y, z) return ("[type=broken;x=%d;y=%d;z=%d;]"):format(x, y, z) end

function packets.entityadd(id, x, y, z) return ("[type=entityadd;x=%f;y=%f;z=%f;id=%s;]"):format(x, y, z, id) end

function packets.entityremove(id) return ("[type=entityremove;id=%s;]"):format(id) end

-- function packets.entitymove(id, x, y, z)
--     return ("[type=entitymove;x=%f;y=%f;z=%f;id=%s;]"):format(x, y, z, id)
-- end

function packets.entityremoteset(id, k, v)
  return ("[type=entityremoteset;id=%s;property=%s;value=%f;]"):format(id, k, v)
end

return packets
