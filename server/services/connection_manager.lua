local player = require("services.player") 
local packets = require("packets")

local connection_manager = {}

function connection_manager.verify_username(g, username)
  local validUsername = "^[a-zA-Z_]+$"

  if g.banlist[username] then return "You're banned from this server. Cry about it :-(" end

  if #username < 3 then return "Username too short" end

  if #username > 15 then return "Username too long" end

  if not username:match(validUsername) then return "Invalid username (It has to be good)" end

  if g.taken_usernames[username] then return "Username already taken. Try again :)" end
end

function connection_manager.init(g) 
	g.banlist = {} -- TODO: load from list
	g.taken_usernames = {}

	g.socket.onconnect:catch(connection_manager.socket_onconnect, g)
	g.socket.ondisconnect:catch(connection_manager.socket_ondisconnect, g)
	g.socket.onreceive:catch(connection_manager.socket_onreceive, g)
end

function connection_manager.socket_onconnect(g, peer)
	print("new connection!") 
end

function connection_manager.socket_ondisconnect(g, peer)
	local socket = g.socket

  local peerdata = socket:peerdata(peer)
  if peerdata.playerentity then
    print(peerdata.playerentity.username .. " left the game :<")
		g.world:tag(peerdata.playerentity, "destroyed")
    g.taken_usernames[peerdata.playerentity.username] = nil
  end
end

function connection_manager.socket_onreceive(g, peer, packet)
  print("received " .. packet.type)

	local socket = g.socket
	local world = g.world

  local peerdata = socket:peerdata(peer)

  if peerdata.playerentity == nil then
    if packet.type == "join" then
      local err = connection_manager.verify_username(g, packet.username)
      if err then
        peer:send(packets.joinfailure(err), CHANNEL_ONE)
        peer:disconnect_later()
        return
      end

			-- spawn player
      local p = player.entity(g, world, lume.uuid(), 0, 0, 180, packet.username, peer)

      peer:send(packets.joinsuccess(p.id, p.x, p.y, p.z), CHANNEL_ONE)

      peerdata.playerentity = p

      g.taken_usernames[p.username] = true

      print(p.username .. " joined the game :>")
    else
      error("invalid packet for ghost peer")
    end
  end
end

return connection_manager
