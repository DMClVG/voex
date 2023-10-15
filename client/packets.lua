local packets = {}
local encode = loex.socket.encode

function packets.place(x, y, z, t) 
	return encode {type="place",x=x,y=y,z=z,t=t} 
end

function packets.breaktile(x, y, z) 
	return encode {type="breaktile",x=x,y=y,z=z}
end

function packets.join(username) 
	return encode {type="join", username=username}
end

function packets.move(x, y, z) 
	return encode {type="move", x=x,y=y,z=z}
end

return packets
