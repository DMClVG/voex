local packets = require("packets")
local quad = require("quad")

local physics = loex.physics
local socket = loex.socket
local size = loex.chunk.size
local lg = love.graphics

local floor = math.floor
local min = math.min

local CEILING = 10

local gamescreen = {}

function gamescreen.init(g, player)
  g.gamescreen = {
    cursor = {},
    cursormodel = require("screens.cursormodel"),
    texturepack = lg.newImage("assets/texturepack.png"),
    threadpool = {},
    threadusage = 0,
    mouse = {},
    placequeue = {},
    breakqueue = {},
    remeshqueue = {},
    remeshchannel = love.thread.newChannel(),
    frameremeshes = 0,
    synctimer = 0,
    player = player,
  }

  player.box = {
    x = 0,
    y = 0,
    z = 0,
    w = 0.3,
    d = 0.3,
    h = 0.9,
  }

  -- load up some threads so that chunk meshing won't block the main thread
  for i = 1, 8 do
    g.gamescreen.threadpool[i] = love.thread.newThread("screens/chunkremesh.lua")
  end

  g.gamescreen.player_model = quad(lg.newImage("assets/saul.png"))
  g.gamescreen.snowball_model = quad(lg.newImage("assets/snowball.png"))
  g.gamescreen.place_sound = love.sound.newSoundData("assets/audio/place.wav")
  g.gamescreen.footstep_sounds = {
    love.sound.newSoundData("assets/audio/footsteps/footstep-01.wav"),
    love.sound.newSoundData("assets/audio/footsteps/footstep-02.wav"),
    love.sound.newSoundData("assets/audio/footsteps/footstep-03.wav"),
    love.sound.newSoundData("assets/audio/footsteps/footstep-04.wav"),
    love.sound.newSoundData("assets/audio/footsteps/footstep-05.wav"),
    love.sound.newSoundData("assets/audio/footsteps/footstep-06.wav"),
    love.sound.newSoundData("assets/audio/footsteps/footstep-07.wav"),
    love.sound.newSoundData("assets/audio/footsteps/footstep-08.wav"),
    love.sound.newSoundData("assets/audio/footsteps/footstep-09.wav"),
  }

  g.gamescreen.gravity = 42

  lg.setMeshCullMode("back")
  love.audio.setDistanceModel("inverseclamped")

  g.ondraw:catch(gamescreen.draw)
  g.onupdate:catch(gamescreen.update)
  g.onmousemoved:catch(gamescreen.onmousemoved)
  --g.onmousepressed:catch(gamescreen.onmousepressed)
  g.onkeypressed:catch(gamescreen.onkeypressed)
  g.world.ontilemodified:catch(gamescreen.ontilemodified, g)
  g.world.onentityinserted:catch(gamescreen.onentityinserted, g)
  g.world.onentityremoved:catch(gamescreen.onentityremoved, g)
  g.world.onchunkinserted:catch(gamescreen.onchunkinserted, g)
  g.world.onchunkremoved:catch(gamescreen.onchunkremoved, g)

  require("services.nethandler").init(g)
  require("services.player").init(g)
  require("common.services.snowball").init(g)
end

function gamescreen.onchunkinserted(g, chunk)
  local x, y, z = chunk.x, chunk.y, chunk.z
  gamescreen.requestremesh(g, chunk)
end

function gamescreen.onchunkremoved(g, chunk) end

function gamescreen.onentityinserted(g, entity) print(entity.id .. " added") end

function gamescreen.onentityremoved(g, entity) print(entity.id .. " removed") end

function gamescreen.onresize(g, w, h)
  g3d.camera.aspectRatio = w / h
  g3d.camera.updateProjectionMatrix()
end

function gamescreen.update(g, dt)
  local self = g.gamescreen
  local mouse = self.mouse
  local threadpool = self.threadpool

  -- collect mouse inputs
  mouse.wasleft, mouse.wasright = mouse.left, mouse.right
  mouse.left, mouse.right = love.mouse.isDown(1), love.mouse.isDown(2)
  mouse.leftclick, mouse.rightclick = mouse.left and not mouse.wasleft, mouse.right and not mouse.wasright

  local lagdelay = 0.5
  -- handle place and break timeouts
  for key, places in pairs(self.placequeue) do
    if love.timer.getTime() - places.timestamp > lagdelay then
      g.world:tile(places.x, places.y, places.z, loex.tiles.air.id)
      self.placequeue[key] = nil
    end
  end

  for key, breaks in pairs(self.breakqueue) do
    if love.timer.getTime() - breaks.timestamp > lagdelay then
      g.world:tile(breaks.x, breaks.y, breaks.z, breaks.prev)
      self.breakqueue[key] = nil
    end
  end

  -- count how many threads are being used right now
  for _, thread in ipairs(threadpool) do
    local err = thread:getError()
    assert(not err, err)
  end

  -- listen for finished meshes on the thread channels
  while self.remeshchannel:peek() do
    local data = self.remeshchannel:pop()
    if not data then break end
    local c = g.world:chunk(loex.hash.spatial(data.cx, data.cy, data.cz))
    if c.model then c.model.mesh:release() end
    c.model = nil
    c.inremesh = false
    if data.count > 0 then
      c.model = g3d.newModel(data.count, self.texturepack)
      c.model.mesh:setVertices(data.data)
      c.model:setTranslation(data.cx * size, data.cy * size, data.cz * size)
    end
    self.threadusage = self.threadusage - 1 -- free up thread
  end

  -- remesh the chunks in the queue
  local remeshesquota = #self.remeshqueue
  local remeshes = 0
  local offi = 0

  while self.threadusage < #threadpool and #self.remeshqueue > 0 and remeshes < remeshesquota do
    local c = self.remeshqueue[1 + offi]
    remeshes = remeshes + 1

    for _, thread in ipairs(threadpool) do
      if not thread:isRunning() then
        -- send over the neighboring chunks to the thread
        -- so that voxels on the edges can face themselves properly
        local n1, n2, n3, n4, n5, n6 = g.world:neighbourhood(c.x, c.y, c.z)
        if
          not (n1 and n2 and n3 and n4 and n5 and n6) or not g.world:chunk(loex.hash.spatial(c.x, c.y, CEILING - 1))
        then
          offi = offi + 1
          break
        end

        c1, c2, c3, c4, c5, c6 = n1.cdata, n2.cdata, n3.cdata, n4.cdata, n5.cdata, n6.cdata
        n1, n2, n3, n4, n5, n6 = n1.data, n2.data, n3.data, n4.data, n5.data, n6.data
        thread:start(
          self.remeshchannel,
          c.x,
          c.y,
          c.z,
          c.data,
          size,
          loex.tiles.id,
          n1,
          n2,
          n3,
          n4,
          n5,
          n6,
          c.cdata,
          c1,
          c2,
          c3,
          c4,
          c5,
          c6
        )
        table.remove(self.remeshqueue, 1 + offi)
        self.threadusage = self.threadusage + 1 -- use up thread
        break
      end
    end
  end

  -- player movement
  local keyboard = love.keyboard
  local speed, jumpforce = 5, 12
  local dirx, diry, dirz = g3d.camera.getLookVector()
  local move = { x = 0, y = 0, z = 0 }
  local p = self.player

  if keyboard.isDown("w") then
    move.x = move.x + dirx
    move.y = move.y + diry
  end
  if keyboard.isDown("s") then
    move.x = move.x - dirx
    move.y = move.y - diry
  end

  if keyboard.isDown("a") then
    move.x = move.x - diry
    move.y = move.y + dirx
  end
  if keyboard.isDown("d") then
    move.x = move.x + diry
    move.y = move.y - dirx
  end

  p.vx, p.vy, _ = g3d.vectors.scalarMultiply(speed, g3d.vectors.normalize(move.x, move.y, move.z))
  p.vz = p.vz - self.gravity * dt

  local onground = physics.moveandcollide(g.world, p, p.box, dt)
  if onground and (move.x ~= 0 or move.y ~= 0) then
    if not p.ssfootsteps:isPlaying() then
      p.ssfootsteps:queue(self.footstep_sounds[math.random(1, #self.footstep_sounds)])
      assert(p.ssfootsteps:play())
    end
  end

  g3d.camera.position[1] = p.x
  g3d.camera.position[2] = p.y
  g3d.camera.position[3] = p.z + 0.7
  g3d.camera.lookInDirection()

  -- player jump
  if onground and keyboard.isDown("space") then p.vz = jumpforce end

  do
    local dx, dy, dz = g3d.camera.getLookVector()
    local x, y, z = g3d.camera.position[1], g3d.camera.position[2], g3d.camera.position[3]
    love.audio.setPosition(x, y, z)
    love.audio.setOrientation(dx, dy, dz, 0, 0, 1)
  end

  local syncinterval = 1 / 20
  self.synctimer = self.synctimer + dt
  if self.synctimer >= syncinterval then
    g.master:send(packets.move(p.x, p.y, p.z), CHANNEL_UPDATES, "unreliable")
    self.synctimer = 0
  end

  -- casts a ray from the camera five blocks in the look vector
  -- finds the first intersecting block
  self.cursor = nil
  do
    local dx, dy, dz = g3d.camera.getLookVector()
    local x, y, z = g3d.camera.position[1], g3d.camera.position[2], g3d.camera.position[3]
    local ox, oy, oz = x, y, z

    local inf = 99999999
    local clipdistance = 10
    local epsilon = 0.00001

    while true do
      local maxx, maxy, maxz = inf, inf, inf
      if dx > 0 then
        maxx = (floor(x) + 1 - x) / dx
      elseif dx < 0 then
        maxx = (floor(x) - x) / dx
      end
      if dy > 0 then
        maxy = (floor(y) + 1 - y) / dy
      elseif dy < 0 then
        maxy = (floor(y) - y) / dy
      end
      if dz > 0 then
        maxz = (floor(z) + 1 - z) / dz
      elseif dz < 0 then
        maxz = (floor(z) - z) / dz
      end

      local step = min(maxx, min(maxy, maxz))
      x = x + dx * step * (1 + epsilon)
      y = y + dy * step * (1 + epsilon)
      z = z + dz * step * (1 + epsilon)

      if loex.utils.distance3d(ox, oy, oz, x, y, z, true) > clipdistance * clipdistance or step == 0 then break end

      local tx, ty, tz = floor(x), floor(y), floor(z)
      local tile = g.world:tile(tx, ty, tz)
      if tile == -1 then break end
      if tile > 0 then
        self.cursor = {}
        self.cursor.placex, self.cursor.placey, self.cursor.placez =
          floor(x - dx * step), floor(y - dy * step), floor(z - dz * step)
        self.cursor.x, self.cursor.y, self.cursor.z = tx, ty, tz
        break
      end
    end
  end

  local placetile = loex.tiles.slime.id

  -- left click to break block
  if mouse.leftclick and self.cursor then
    local x, y, z = self.cursor.x, self.cursor.y, self.cursor.z
    self.breakqueue[("%d/%d/%d"):format(x, y, z)] = {
      x = x,
      y = y,
      z = z,
      timestamp = love.timer.getTime(),
      prev = g.world:tile(x, y, z),
    }
    g.master:send(packets.breaktile(x, y, z), CHANNEL_EVENTS, "reliable")
    g.world:tile(x, y, z, loex.tiles.air.id)
  end

  -- right click to place block
  if mouse.rightclick and self.cursor then
    local x, y, z = self.cursor.placex, self.cursor.placey, self.cursor.placez
    local cube = { x = x + 0.5, y = y + 0.5, z = z + 0.5, w = 0.5, h = 0.5, d = 0.5 }
    local translatedplayerbox = lume.clone(p.box)
    translatedplayerbox.x = translatedplayerbox.x + p.x
    translatedplayerbox.y = translatedplayerbox.y + p.y
    translatedplayerbox.z = translatedplayerbox.z + p.z
    if not loex.utils.intersectbb(cube, translatedplayerbox) then
      self.placequeue[("%d/%d/%d"):format(x, y, z)] = {
        x = x,
        y = y,
        z = z,
        timestamp = love.timer.getTime(),
        t = placetile,
      }
      g.master:send(packets.place(x, y, z, placetile), CHANNEL_EVENTS, "reliable")
      g.world:tile(x, y, z, placetile)
      gamescreen.play_place_sound(g, x, y, z)
    end
  end
end

function gamescreen.play_place_sound(g, x, y, z)
  local self = g.gamescreen
  local source = love.audio.newSource(self.place_sound)
  source:setPosition(x, y, z)
  source:setAttenuationDistances(0.5, 2000000)
  source:setRolloff(0.3)
  source:play()
end

function gamescreen.draw(g)
  local self = g.gamescreen
  lg.clear(lume.color("#4488ff"))

  lg.setColor(1, 1, 1)
  for _, chunk in pairs(g.world.chunks) do
    if chunk.model then chunk.model:draw() end
  end

  lg.setMeshCullMode("none")
  if self.cursor then
    lg.setColor(0, 0, 0)
    lg.setWireframe(true)
    self.cursormodel:setTranslation(self.cursor.x, self.cursor.y, self.cursor.z)
    self.cursormodel:draw()
    lg.setWireframe(false)
  end
  lg.setMeshCullMode("back")

  -- draw crosshair
  local cross = 4
  lg.setColor(1, 1, 1)
  lg.rectangle("fill", (lg.getWidth() - cross) / 2, (lg.getHeight() - cross) / 2, cross, cross)
end

function gamescreen.throw_snowball(g)
  local x, y, z = g3d.camera.position[1], g3d.camera.position[2], g3d.camera.position[3]
  local dx, dy, dz = g3d.camera.getLookVector()
  local force = 30
  g.master:send(socket.encode {
    type = "snowball_throw",
    x = x,
    y = y,
    z = z,
    vx = dx * force,
    vy = dy * force,
    vz = dz * force,
  })
  g.gamescreen.player.sssnowball_throw:play()
end

function gamescreen.onmousemoved(g, x, y, dx, dy, istouch) g3d.camera.firstPersonLook(dx, dy) end

function gamescreen.onkeypressed(g, k)
  if k == "q" then
    print("thrown snowball")
    gamescreen.throw_snowball(g)
  end
end

function gamescreen.ontilemodified(g, x, y, z, _)
  local spatial = loex.hash.spatial
  local chunk = g.world:chunk(spatial(floor(x / size), floor(y / size), floor(z / size)))
  assert(chunk)

  local tx, ty, tz = x % size, y % size, z % size
  local cx, cy, cz = chunk.x, chunk.y, chunk.z
  local world = g.world

  if tx >= size - 1 then gamescreen.requestremesh(g, world:chunk(spatial(cx + 1, cy, cz)), true) end
  if tx <= 0 then gamescreen.requestremesh(g, world:chunk(spatial(cx - 1, cy, cz)), true) end
  if ty >= size - 1 then gamescreen.requestremesh(g, world:chunk(spatial(cx, cy + 1, cz)), true) end
  if ty <= 0 then gamescreen.requestremesh(g, world:chunk(spatial(cx, cy - 1, cz)), true) end
  if tz >= size - 1 then gamescreen.requestremesh(g, world:chunk(spatial(cx, cy, cz + 1)), true) end
  if tz <= 0 then gamescreen.requestremesh(g, world:chunk(spatial(cx, cy, cz - 1)), true) end

  gamescreen.requestremesh(g, chunk, true)
end

function gamescreen.requestremesh(g, c, priority)
  local self = g.gamescreen
  -- don't add a nil chunk or a chunk that's already in the queue
  local world = g.world
  if not c or c.inremesh or not c.data then return end
  if not c.cdata then c.cdata = love.data.newByteData(size ^ 3) end

  c.inremesh = true
  if priority then
    table.insert(self.remeshqueue, 1, c)
  else
    table.insert(self.remeshqueue, c)
  end
end

return gamescreen
