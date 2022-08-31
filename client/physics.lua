local cube = {w=0.5,h=0.5,d=0.5,x=0,y=0,z=0}
local epsilonx, epsilony, epsilonz = 0.0045, 0.002, 0.005
local size = loex.Chunk.size

Physics = {
    WORLD_G = 42
}

function advanceBoxInWorld(world, box, v, dt)
    local newv = lume.clone(v)

    local dx, dy, dz = v.x * dt, v.y * dt, v.z * dt
    local x, y, z = box.x, box.y, box.z
    local w, h, d = box.w, box.h, box.d

    local getChunk = world.getChunkFromWorld
    
    local touchedGround = false
    
    local boxz = loex.Utils.expand(lume.clone(box), 0, 0, dz)
    for i, j, k in loex.Utils.iterBoxFloored(boxz) do
        local chunk = getChunk(world, i, j, k)
        if chunk then
            cube.x = i+0.5
            cube.y = j+0.5
            cube.z = k+0.5
            if chunk:getBlock(i%size,j%size,k%size) ~= 0 and loex.Utils.intersectBoxAndBox(cube, boxz) then
                if dz < 0 then
                    dz = math.min(math.max(dz, (k+1+epsilonz)-(z-h)),0)
                    touchedGround = true
                else
                    dz = math.max(math.min(dz, (k-epsilonz)-(z+h)),0)
                end
                newv.z = 0
            end
        end
    end

    local boxx = loex.Utils.expand(lume.clone(box), dx, 0, dz)
    for i, j, k in loex.Utils.iterBoxFloored(boxx) do
        local chunk = getChunk(world, i, j, k)
        if chunk then
            cube.x = i+0.5
            cube.y = j+0.5
            cube.z = k+0.5
            if chunk:getBlock(i%size,j%size,k%size) ~= 0 and loex.Utils.intersectBoxAndBox(cube, boxx) then
                if dx < 0 then
                    dx = math.min(math.max(dx, (i+1+epsilonx)-(x-w)),0)
                else
                    dx = math.max(math.min(dx, (i-epsilonx)-(x+w)),0)
                end
                newv.x = 0
            end
        end
    end

    local boxy = loex.Utils.expand(lume.clone(box), dx, dy, dz)
    for i, j, k in loex.Utils.iterBoxFloored(boxy) do
        local chunk = getChunk(world, i, j, k)
        if chunk then
            cube.x = i+0.5
            cube.y = j+0.5
            cube.z = k+0.5
            if chunk:getBlock(i%size,j%size,k%size) ~= 0 and loex.Utils.intersectBoxAndBox(cube, boxy) then
                if dy < 0 then
                    dy = math.min(math.max(dy, (j+1+epsilony)-(y-d)),0)
                else
                    dy = math.max(math.min(dy, (j-epsilony)-(y+d)),0)
                end
                newv.y = 0
            end
        end
    end

    box.x = box.x + dx
    box.y = box.y + dy
    box.z = box.z + dz

    return newv, touchedGround
end