local player = {}
local lg = love.graphics

function player.init(g)
  g.socket.onreceive:catch(player.onreceive, g)

  g.onupdate:catch(player.onupdate)
  g.ondraw:catch(player.ondraw)
end

function player.onreceive(g, _, packet)
  if packet.type == "entityadd" and packet.entity_type == "player" then
    local e = { id = packet.id, x = packet.x, y = packet.y, z = packet.z, username = packet.username }
    g.world:insert(e)
    g.world:tag(e, "player")
  end
end

function player.onupdate(g) end

function player.ondraw(g)
  local player_model = g.gamescreen.player_model
  local camera = g3d.camera.position

  lg.setMeshCullMode("none")
  lg.setColor(1, 1, 1)

  for _, e in pairs(g.world:query("player")) do
    if e ~= g.gamescreen.player then
      player_model:setTranslation(e.x, e.y, e.z)
      player_model:setRotation(0, 0, math.atan2(e.y - camera[2], e.x - camera[1]))
      player_model:setScale(1, 0.6, 0.9)
      player_model:draw()
    end
  end
end

return player
