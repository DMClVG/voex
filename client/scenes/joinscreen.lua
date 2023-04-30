local joinscreen = {}
local lg = love.graphics

function joinscreen:draw()
  local w, h = lg.getWidth(), lg.getHeight()

  local msg = "Joining"

  for _ = 1, math.floor(love.timer.getTime()) % 4 do
    msg = msg .. "."
  end

  w = w - lg.getFont():getWidth(msg)
  h = h - lg.getFont():getHeight()

  lg.print(msg, w / 2, h / 2)
end

return joinscreen
