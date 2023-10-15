local packets = {}
local encode = loex.socket.encode

function packets.joinsuccess(id, x, y, z) 
	return encode {
		type="joinsuccess",
		x=x,
		y=y,
		z=z,
		id=id
	}
end

function packets.joinfailure(cause) 
	return encode {
		type="joinfailure",
		cause=cause
	}
end

function packets.chunkadd(tiles, cx, cy, cz)
  return encode { type="chunkadd", cx=cx, cy=cy, cz=cz, bin=tiles }
end

function packets.chunkremove(cx, cy, cz) 
	return encode { type="chunkremove", cx=cx,cy=cy,cz=cz }
end

function packets.placed(x, y, z, t) 
	return encode { type="placed",x=x,y=y,z=z,t=t }
end

function packets.broken(x, y, z) 
	return encode { type="broken", x=x,y=y,z=z} 
end

function packets.entityadd(id, x, y, z) 
	return encode {type="entityadd", x=x,y=y,z=z,id=id} 
end

function packets.entityremove(id) 
	return encode {type="entityremove", id=id} 
end

-- function packets.entitymove(id, x, y, z)
--     return ("[type=entitymove;x=%f;y=%f;z=%f;id=%s;]"):format(x, y, z, id)
-- end

function packets.entityremoteset(id, properties)
	return encode {
		type="entityremoteset",
		id=id,
		properties=properties
	}
end

return packets
