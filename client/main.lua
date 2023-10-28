if arg[#arg] == "vsc_debug" then require("lldebugger").start() end
package.path = package.path .. ";?/init.lua"

---@diagnostic disable-next-line: missing-parameter
love.graphics.setDefaultFilter("nearest")

io.stdout:setvbuf("no")

g3d = require("lib/g3d")
require("common")

CHANNEL_ONE = 0
CHANNEL_EVENTS = 1
CHANNEL_UPDATES = 2

local game

function love.load(args)
  if #args < 3 then
    print("Usage: client [address] [port] [username]")
    love.event.quit(-1)
    return
  end
  local address = args[1] .. ":" .. args[2]
  local username = args[3]

  local socket = loex.socket.connect(address)
	assert(socket)

  local font = love.graphics.newFont(23)
  love.graphics.setFont(font)

	game = {}
	game.gravity = 42 -- TODO

	game.socket = socket
	game.username = username

	game.ondraw = loex.signal.new()
	game.onupdate = loex.signal.new()
	game.onmousemoved = loex.signal.new()
	game.onmousepressed = loex.signal.new()
	game.onkeypressed = loex.signal.new()
	game.onresize = loex.signal.new()
	game.onquit = loex.signal.new()

	require("screens.joinscreen").init(game)
end

function love.update(dt)
	game.onupdate:emit(game, dt)
end

function love.draw()
	game.ondraw:emit(game)
end

function love.mousepressed(x,y,button,istouch,presses)
	game.onmousepressed:emit(game,x,y,button,istouch,presses)
end

function love.mousemoved(x, y, dx, dy,istouch)
	game.onmousemoved:emit(game,x,y,dx,dy,istouch)
end

function love.keypressed(k,scancode,isrepeat)
	game.onkeypressed:emit(game, k, scancode, isrepeat)
end

function love.resize(w, h)
	game.onresize:emit(game,w,h)
end

function love.quit()
	game.onquit:emit(game)
end
