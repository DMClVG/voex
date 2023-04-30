local errorscreen = {}
local lg = love.graphics

function errorscreen:init(cause)
    self.msg = cause
end

function errorscreen:draw()
    lg.clear(1, 0, 0)
    local w, h = lg.getWidth(), lg.getHeight()

    w = w - lg.getFont():getWidth(self.msg)
    h = h - lg.getFont():getHeight()

    lg.print(self.msg, w / 2, h / 2)
end

return errorscreen
