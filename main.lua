--- @module main

local client = require("client")
local signal = require("common.signal")


local game = {
  ondraw = signal.new(),
  onupdate = signal.new(),
  onmousemoved = signal.new(),
  onmousepressed = signal.new(),
  onkeypressed = signal.new(),
  onresize = signal.new(),
  onquit = signal.new(),
  version = "dev",
}

inspect = require("inspect")

function love.load(args)
   game.args = args

   client.init(game)
end

function love.update(dt)
   game.onupdate:emit(game, dt)
end

function love.draw()
   game.ondraw:emit(game)
end

function love.mousepressed(x, y, button, istouch, presses)
   game.onmousepressed:emit(game, x, y, button, istouch, presses)
end

function love.mousemoved(x, y, dx, dy, istouch)
   game.onmousemoved:emit(game, x, y, dx, dy, istouch)
end

function love.keypressed(k, scancode, isrepeat)
   game.onkeypressed:emit(game, k, scancode, isrepeat)
end

function love.resize(w, h)
   game.onresize:emit(game, w, h)
end

function love.quit()
   game.onquit:emit(game)
end
