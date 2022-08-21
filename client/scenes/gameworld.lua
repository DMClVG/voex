GameWorld = loex.World:extend()
local Chunk = loex.Chunk
local size = Chunk.size
local threadpool = {}
-- load up some threads so that chunk meshing won't block the main thread
for i=1, 8 do
    threadpool[i] = love.thread.newThread "scenes/chunkremesh.lua"
end
local threadchannels = {}
local texturepack = lg.newImage "assets/texturepack.png"
local wasLeftDown, wasRightDown, rightDown, leftDown

local renderDistance = 5

-- create the mesh for the block cursor
local blockCursor, blockCursorVisible
do
    local a = -0.005
    local b = 1.005
    blockCursor = g3d.newModel{
        {a,a,a}, {b,a,a}, {b,a,a},
        {a,a,a}, {a,a,b}, {a,a,b},
        {b,a,b}, {a,a,b}, {a,a,b},
        {b,a,b}, {b,a,a}, {b,a,a},

        {a,b,a}, {b,b,a}, {b,b,a},
        {a,b,a}, {a,b,b}, {a,b,b},
        {b,b,b}, {a,b,b}, {a,b,b},
        {b,b,b}, {b,b,a}, {b,b,a},

        {a,a,a}, {a,b,a}, {a,b,a},
        {b,a,a}, {b,b,a}, {b,b,a},
        {a,a,b}, {a,b,b}, {a,b,b},
        {b,a,b}, {b,b,b}, {b,b,b},
    }
end

function GameWorld:new(playerEntity)
    GameWorld.super.new(self)

    self.remeshQueue = {}
    self.chunkCreationsThisFrame = 0
    self.updatedThisFrame = false

    self.player = playerEntity

    self:addEntity(playerEntity)

    lg.setMeshCullMode("back")
end

local function updateChunk(self, x, y, z)
    x = x + math.floor(g3d.camera.position[1]/size)
    y = y + math.floor(g3d.camera.position[2]/size)
    z = z + math.floor(g3d.camera.position[3]/size)
    local chunk = self:getChunk(x, y, z)
    if chunk then
        chunk.frames = 0
    end
end

function GameWorld:onChunkAdded(chunk)
    local x, y, z = chunk.cx, chunk.cy, chunk.cz
    self.chunkCreationsThisFrame = self.chunkCreationsThisFrame + 1

    self:requestRemesh(chunk)

    -- this chunk was just created, so update all the chunks around it
    self:requestRemesh(self:getChunk(x+1,y,z))
    self:requestRemesh(self:getChunk(x-1,y,z))
    self:requestRemesh(self:getChunk(x,y+1,z))
    self:requestRemesh(self:getChunk(x,y-1,z))
    self:requestRemesh(self:getChunk(x,y,z+1))
    self:requestRemesh(self:getChunk(x,y,z-1))
end

function GameWorld:onEntityAdded(entity)
    print(entity.type .. " ".. entity.id .. " added")
end

function GameWorld:onEntityRemoved(entity)
    print(entity.type .. " ".. entity.id .. " removed")
end


local netTimer = 0
function GameWorld:onUpdated(dt)

    -- collect mouse inputs
    wasLeftDown, wasRightDown = leftDown, rightDown
    leftDown, rightDown = love.mouse.isDown(1), love.mouse.isDown(2)
    leftClick, rightClick = leftDown and not wasLeftDown, rightDown and not wasRightDown

    self.updatedThisFrame = true

    -- -- generate a "bubble" of loaded chunks around the camera
    -- local bubbleWidth = renderDistance
    -- local bubbleHeight = math.floor(renderDistance * 0.75)
    -- local creationLimit = 1
    -- self.chunkCreationsThisFrame = 0
    -- for r=0, bubbleWidth do
    --     for a=0, math.pi*2, math.pi*2/(8*r) do
    --         local h = math.floor(math.cos(r*(math.pi/2)/bubbleWidth)*bubbleHeight + 0.5)
    --         for y=0, h do
    --             local x, z = math.floor(math.cos(a)*r + 0.5), math.floor(math.sin(a)*r + 0.5)
    --             if y ~= 0 then
    --                 updateChunk(self, x, -y, z)
    --             end
    --             updateChunk(self, x, y, z)
    --             if self.chunkCreationsThisFrame >= creationLimit then break end
    --         end
    --     end
    -- end

    -- count how many threads are being used right now
    local threadusage = 0
    for _, thread in ipairs(threadpool) do
        if thread:isRunning() then
            threadusage = threadusage + 1
        end

        local err = thread:getError()
        assert(not err, err)
    end

    -- listen for finished meshes on the thread channels
    for channel, chunk in pairs(threadchannels) do
        local data = love.thread.getChannel(channel):pop()
        if data then
            threadchannels[channel] = nil
            if chunk.model then chunk.model.mesh:release() end
            chunk.model = nil
            if data.count > 0 then
                chunk.model = g3d.newModel(data.count, texturepack)
                chunk.model.mesh:setVertices(data.data)
                chunk.model:setTranslation(chunk.x, chunk.y, chunk.z)
                chunk.inRemeshQueue = false
                break
            end
        end
    end

    -- remesh the chunks in the queue
    -- NOTE: if this happens multiple times in a frame, weird things can happen? idk why
    if threadusage < #threadpool and #self.remeshQueue > 0 then
        local chunk
        local ok = false
        repeat
            chunk = table.remove(self.remeshQueue, 1)
        until not chunk or self.chunks[chunk.hash]

        if chunk and not chunk.dead then
            for _, thread in ipairs(threadpool) do
                if not thread:isRunning() then
                    -- send over the neighboring chunks to the thread
                    -- so that voxels on the edges can face themselves properly
                    local x, y, z = chunk.cx, chunk.cy, chunk.cz
                    local neighbor, n1, n2, n3, n4, n5, n6
                    neighbor = self:getChunk(x+1,y,z)
                    if neighbor and not neighbor.dead then n1 = neighbor.data end
                    neighbor = self:getChunk(x-1,y,z)
                    if neighbor and not neighbor.dead then n2 = neighbor.data end
                    neighbor = self:getChunk(x,y+1,z)
                    if neighbor and not neighbor.dead then n3 = neighbor.data end
                    neighbor = self:getChunk(x,y-1,z)
                    if neighbor and not neighbor.dead then n4 = neighbor.data end
                    neighbor = self:getChunk(x,y,z+1)
                    if neighbor and not neighbor.dead then n5 = neighbor.data end
                    neighbor = self:getChunk(x,y,z-1)
                    if neighbor and not neighbor.dead then n6 = neighbor.data end

                    thread:start(chunk.hash, chunk.data, chunk.size, common.Tiles.tiles, common.Tiles.tids, n1, n2, n3, n4, n5, n6)
                    threadchannels[chunk.hash] = chunk
                    break
                end
            end
        end
    end

    -- left click to destroy blocks
    -- casts a ray from the camera five blocks in the look vector
    -- finds the first intersecting block
    local vx, vy, vz = g3d.camera.getLookVector()
    local x, y, z = g3d.camera.position[1], g3d.camera.position[2], g3d.camera.position[3]
    local step = 0.1
    local floor = math.floor
    local buildx, buildy, buildz
    blockCursorVisible = false
    for i=step, 5, step do
        local bx, by, bz = floor(x + vx*i), floor(y + vy*i), floor(z + vz*i)
        local chunk = self:getChunkFromWorld(bx, by, bz)
        if chunk then
            local lx, ly, lz = bx%size, by%size, bz%size
            if chunk:getBlock(lx,ly,lz) ~= 0 then
                blockCursor:setTranslation(bx, by, bz)
                blockCursorVisible = true

                -- store the last position the ray was at
                -- as the position for building a block
                local li = i - step
                buildx, buildy, buildz = floor(x + vx*li), floor(y + vy*li), floor(z + vz*li)

                if leftClick then
                    net.master:send(packets.Break(bx, by, bz))
                end

                break
            end
        end
    end

    local p = self.player
    local pbox = p:getBox()
    local placedBlock = 1

    -- right click to place blocks
    if rightClick and buildx and not boxIntersectBox({x=buildx+0.5, y=buildy+0.5, z=buildz+0.5, w=0.5, h=0.5, d=0.5}, pbox) then
        local chunk = self:getChunkFromWorld(buildx, buildy, buildz)
        if chunk then
            net.master:send(packets.Place(buildx, buildy, buildz, placedBlock))
        end
    end


    local speed, jumpForce = 5, 12
    local dirx, diry, dirz = g3d.camera.getLookVector()
    local move = {x=0,y=0,z=0}

    if love.keyboard.isDown("w") then
        move.x = dirx
        move.y = diry
    elseif love.keyboard.isDown("s") then
        move.x = -dirx
        move.y = -diry
    end
    
    if love.keyboard.isDown("a") then
        move.x = -diry
        move.y = dirx
    elseif love.keyboard.isDown("d") then
        move.x = diry
        move.y = -dirx
    end
    

    local mvx, mvy, _ = g3d.vectors.scalarMultiply(speed, g3d.vectors.normalize(move.x, move.y, move.z))
    p.vx = mvx
    p.vy = mvy
    p.vz = p.vz - Physics.WORLD_G * dt

    local nv, touchedGround = advanceBoxInWorld(self, pbox, {x=p.vx,y=p.vy,z=p.vz}, dt)
    p.vx = nv.x
    p.vy = nv.y
    p.vz = nv.z
    p.x = pbox.x
    p.y = pbox.y
    p.z = pbox.z

    g3d.camera.position[1] = p.x
    g3d.camera.position[2] = p.y
    g3d.camera.position[3] = p.z + 0.7
    g3d.camera.lookInDirection()

    if touchedGround and love.keyboard.isDown("space") then
        p.vz = p.vz + jumpForce
    end

    local netInterval = 1/20
    if netTimer >= netInterval then
        net.master:send(packets.Move(p.x, p.y, p.z))
        netTimer = 0
    end
    netTimer = netTimer + dt
end

function GameWorld:mousemoved(x, y, dx, dy)
    g3d.camera.firstPersonLook(dx, dy)
end

function GameWorld:draw()
    lg.clear(lume.color "#4488ff")

    lg.setColor(1,1,1)
    for _, chunk in pairs(self.chunks) do
        chunk:draw()

        if self.updatedThisFrame then
            chunk.frames = chunk.frames + 1
            -- if chunk.frames > 100 then chunk:destroy() end
        end
    end

    self.updatedThisFrame = false

    lg.setMeshCullMode("none")
    if blockCursorVisible then
        lg.setColor(0,0,0)
        lg.setWireframe(true)
        blockCursor:draw()
        lg.setWireframe(false)
    end
    lg.setMeshCullMode("back")

    for _, entity in pairs(self.entities) do
        entity:draw()
    end
end

function GameWorld:requestRemesh(chunk, first)
    -- don't add a nil chunk or a chunk that's already in the queue
    if not chunk or chunk.inRemeshQueue then return end
    local x, y, z = chunk.cx, chunk.cy, chunk.cz

    -- check if has neighboring chunks
    if not self:getChunk(x+1,y,z) then return end
    if not self:getChunk(x-1,y,z) then return end
    if not self:getChunk(x,y+1,z) then return end
    if not self:getChunk(x,y-1,z) then return end
    if not self:getChunk(x,y,z+1) then return end
    if not self:getChunk(x,y,z-1) then return end

    chunk.inRemeshQueue = true
    if first then
        table.insert(self.remeshQueue, 1, chunk)
    else
        table.insert(self.remeshQueue, chunk)
    end
end