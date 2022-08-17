local Player = loex.Entity:extend()

function Player:update()
    
end

function Player:getBox()
    return {x=self.x,y=self.y,z=self.z, w=0.3,h=0.9,d=0.3}
end

return Player