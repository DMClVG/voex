local Player = loex.Entity:extend()
Player.type = "Player"

local obj
if not IS_SERVER then
    obj = g3d.newModel("assets/player.obj")
end

function Player:update()
    
end

function Player:getBox()
    return {x=self.x,y=self.y,z=self.z, w=0.3,h=0.9,d=0.3}
end

function Player:draw()
    obj:setTranslation(self.x, self.y, self.z-0.9)
    obj:draw()
end

return Player