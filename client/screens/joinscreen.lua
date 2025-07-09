local errorscreen = require("screens.errorscreen")
local gamescreen = require("screens.gamescreen")
local packets = require("packets")

local lg = love.graphics

local joinscreen = {}

function joinscreen.init(g)
  local signals = {
    g.ondraw:catch(joinscreen.draw),
    g.socket.onconnect:catch(joinscreen.socket_onconnect, g),
    g.socket.onreceive:catch(joinscreen.socket_onreceive, g),
    g.socket.ondisconnect:catch(joinscreen.socket_ondisconnect, g),
  }
  g.joinscreen = { signals = signals }

  -- base functions
  g.onupdate:catch(function(g) g.socket:service() end)
  g.onquit:catch(function(g) g.socket:disconnect() end)
end

function joinscreen.cleanup(g)
  for _, signal in ipairs(g.joinscreen.signals) do
    signal:destroy()
  end
  g.joinscreen = nil
end

function joinscreen.error(g, cause)
  joinscreen.cleanup(g)
  errorscreen.init(g, cause)
end

function joinscreen.socket_onreceive(g, peer, d)
  print("received " .. d.type)
  if d.type == "joinsuccess" then
    local spawnx, spawny, spawnz = d.x, d.y, d.z
    assert(d.id)

    g.world = loex.world.new()

    local player = { id = d.id }
    player.x, player.y, player.z = spawnx, spawny, spawnz
    player.vx, player.vy, player.vz = 0, 0, 0
    player.username = g.username

    player.ssfootsteps = love.audio.newQueueableSource(48000, 16, 1)
    player.ssfootsteps:setAttenuationDistances(1, 1)
    player.sssnowball_throw = love.audio.newSource("assets/audio/snowball_throw.wav", "static")

    g.world:insert(player)
    g.world:tag(player, "player")

    print(
      ("Joined under username " .. player.username .. " (ID: " .. player.id .. ") at spawn point %d, %d, %d"):format(
        spawnx,
        spawny,
        spawnz
      )
    )
    joinscreen.cleanup(g)
    gamescreen.init(g, player)
  elseif d.type == "joinfailure" then
    joinscreen.error(g, d.cause)
  else
    joinscreen.error(g, "unexpected packet type " .. d.typed)
  end
end

function joinscreen.socket_onconnect(g, peer)
  print("connected!")

  -- set master peer
  g.master = peer

  -- send join
  local join_packet = packets.join(g.username)
  g.master:send(join_packet)
end

function joinscreen.socket_ondisconnect(g) joinscreen.error(g, "connection closed") end

function joinscreen.update(g) g.socket:service() end

function joinscreen.draw()
  local w, h = lg.getWidth(), lg.getHeight()

  local l = 3
  local s = ""
  local k = math.floor(love.timer.getTime()) % l
  for i = 0, l - 1 do
    if i == k then
      s = s .. "O"
    else
      s = s .. "o"
    end
  end

  w = w - lg.getFont():getWidth(s)
  h = h - lg.getFont():getHeight()

  lg.print(s, w / 2, h / 2)
end

return joinscreen
