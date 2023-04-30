if arg[#arg] == "vsc_debug" then require("lldebugger").start() end
package.path = package.path .. ";?/init.lua"

IS_SERVER = true

CHANNEL_ONE = 0
CHANNEL_CHUNKS = 1
CHANNEL_EVENTS = 3
CHANNEL_UPDATES = 4

common = require("common")
packets = require("packets")
remote = require("remote")

banlist = {}
takenusernames = {}

local socket
local world

local tiles = loex.tiles
local size = loex.chunk.size

local function genchunk(c)
  c:init()
  local grass = tiles.air.id
  local dirt = tiles.dirt.id
  local stone = tiles.stone.id
  local ptr = c.ptr
  local x, y, z = c.x * size, c.y * size, c.z * size
  local f = 0.125 / 10
  for i = 0, size - 1 do
    for j = 0, size - 1 do
      local h = math.floor(love.math.noise((x + i) * f, (y + j) * f) * 17)
      for k = 0, math.min(h - z, size - 1) do
        if z + k == h then
          ptr[i + j * size + k * size * size] = grass
        elseif z + k > h - 5 then
          ptr[i + j * size + k * size * size] = dirt
        else
          ptr[i + j * size + k * size * size] = stone
        end
      end
    end
  end
  return c
end

function love.load(args)
  if #args < 1 then
    print("please supply port number to start server on")
    return love.event.quit(-1)
  end

  port = tonumber(args[1])
  print("starting server on port " .. tostring(port) .. "...")

  socket = loex.socket.host(port, 64)
  socket.onconnect:catch(onconnect)
  socket.ondisconnect:catch(ondisconnect)
  socket.onreceive:catch(onreceive)

  world = loex.world.new()
  world.onentityadded:catch(world_onentityadded)
  world.onentityremoved:catch(world_onentityremoved)

  for i = -2, 2 do
    for j = -2, 2 do
      for k = -2, 2 do
        world:chunk(i, j, k, genchunk(loex.chunk.new(i, j, k)))
      end
    end
  end

  -- world:chunk(0, 0, 0, loex.chunk.new(0, 0, 0))
  -- world:chunk(0, 0, 0, loex.chunk.new(0, 0, 0))
  -- world:chunk(0, 0, 0, loex.chunk.new(0, 0, 0))
  -- world:chunk(0, 0, 0, loex.chunk.new(0, 0, 0))
end

function world_onentityadded(e)
  print(e.id .. " added")
  local packet = packets.entityadd(e.id, e.x, e.y, e.z)
  for _, e in pairs(world.entities) do
    if e:has("player") then e.master:send(packet) end
  end
end

function world_onentityremoved(e)
  print(e.id .. " removed")
  local packet = packets.entityremove(e.id)
  for _, e in pairs(world.entities) do
    if e:has("player") then e.master:send(packet) end
  end
end

function onconnect(peer) print("Connected!") end

function ondisconnect(peer)
  local peerdata = socket:peerdata(peer)
  if peerdata.playerentity then
    print(peerdata.playerentity.username .. " left the game :<")
    world:remove(peerdata.playerentity)
    takenusernames[peerdata.playerentity.username] = nil
  end
end

function handle_player_packet(player, packet)
  local handles = {
    ["move"] = function(p, d)
      local x, y, z = tonumber(d.x), tonumber(d.y), tonumber(d.z)
      p.x = x
      p.y = y
      p.z = z
    end,
    ["place"] = function(p, d)
      local x, y, z, t = tonumber(d.x), tonumber(d.y), tonumber(d.z), tonumber(d.t)
      world:tile(x, y, z, t)
      broadcast(packets.placed(x, y, z, t))
    end,
    ["breaktile"] = function(p, d)
      local x, y, z = tonumber(d.x), tonumber(d.y), tonumber(d.z)
      world:tile(x, y, z, tiles.air.id)
      broadcast(packets.broken(x, y, z))
    end,
  }
  handles[packet.type](player, packet)
end

function sendworld(peer)
  for _, chunk in pairs(world.chunks) do
    peer:send(packets.chunkadd(chunk:dump(true), chunk.x, chunk.y, chunk.z))
  end
  for _, e in pairs(world.entities) do
    peer:send(packets.entityadd(e.id, e.x, e.y, e.z))
  end
end
function broadcast(packet)
  for _, e in pairs(world.entities) do
    if e:has("player") then e.master:send(packet) end
  end
end

function broadcast_remoteset(remote, property, value)
  -- print(e.id .. " set")
  local packet = packets.entityremoteset(remote.id, property, value)
  broadcast(packet)
end

function onreceive(peer, packet)
  print("Received " .. packet.type)
  local peerdata = socket:peerdata(peer)

  if peerdata.playerentity == nil then
    if packet.type == "join" then
      local err = verify(packet.username)
      if err then
        peer:send(packets.joinfailure(err), CHANNEL_ONE)
        peer:disconnect_later()
        return
      end
      local player = player(0, 0, 50, nil, packet.username, peer)

      peer:send(packets.joinsuccess(player.id, player.x, player.y, player.z), CHANNEL_ONE)

      world:insert(player)
      peerdata.playerentity = player

      takenusernames[player.username] = true

      print(player.username .. " joined the game :>")

      sendworld(peer)
    else
      error("invalid packet for ghost peer")
    end
  else
    handle_player_packet(peerdata.playerentity, packet)
  end
end

function love.update(dt)
  socket:service()

  for _, e in pairs(world.entities) do
    if e:has("remote") then
      e.remote.x = e.x
      e.remote.y = e.y
      e.remote.z = e.z
    end
  end

  for _, e in pairs(world.entities) do
    if e:has("remote") then
      for property, _ in pairs(e.remote.edits) do
        broadcast_remoteset(e, property, e.remote[property])
        e.remote.edits[property] = nil
      end
    end
  end
end

function love.quit() socket:disconnect() end

function player(x, y, z, id, username, master)
  local player = remote(x, y, z, id)
  player:tag("player")
  player.username = username
  player.master = master
  return player
end

function verify(username)
  local validUsername = "^[a-zA-Z_]+$"

  if banlist[username] then return "You're banned from this server. Cry about it :-(" end

  if #username < 3 then return "Username too short" end

  if #username > 15 then return "Username too long" end

  if not username:match(validUsername) then return "Invalid username (It has to be good)" end

  if takenusernames[username] then return "Username already taken. Try again :)" end
end
