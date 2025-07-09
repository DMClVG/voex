local errorscreen = {}
local lg = love.graphics

function errorscreen.init(g, cause)
  g.errorscreen = {}
  g.errorscreen.cause = cause
  g.ondraw:catch(errorscreen.draw)
end

function errorscreen.draw(g)
  lg.clear(1, 0, 0)
  local w, h = lg.getWidth(), lg.getHeight()

  local cause = g.errorscreen.cause
  w = w - lg.getFont():getWidth(cause)
  h = h - lg.getFont():getHeight()

  lg.print(cause, w / 2, h / 2)
end

return errorscreen
