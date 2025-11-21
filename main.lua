local client = require("client")
local server = require("server")
local common = require("common")

local game = {
  ondraw = common.signal.new(),
  onupdate = common.signal.new(),
  onmousemoved = common.signal.new(),
  onmousepressed = common.signal.new(),
  onkeypressed = common.signal.new(),
  onresize = common.signal.new(),
  onquit = common.signal.new(),
}

function love.load(args)
   game.args = args

   local mocksocketA = {
      onconnect = common.signal.new(),
      ondisconnect = common.signal.new(),
      onreceive = common.signal.new(),
      peerdatas = {},
   }
   local mocksocketB = {
      onconnect = common.signal.new(),
      ondisconnect = common.signal.new(),
      onreceive = common.signal.new(),
      peerdatas = {},
   }

   function mocksocketA:peerdata(peer) return self.peerdatas[peer] end
   function mocksocketB:peerdata(peer) return self.peerdatas[peer] end

   local peerA, peerB = {}, {}
   function peerA:send(string)
      mocksocketB.onreceive:emit(peerB, string)
   end
   function peerB:send(string)
      mocksocketA.onreceive:emit(peerA, string)
   end
   function peerA:index() return 1 end
   function peerB:index() return 1 end

   client.init(game, mocksocketA, "Jenny")
   server.init(game, mocksocketB)

   mocksocketA.onconnect:emit(peerB)
   mocksocketB.onconnect:emit(peerA)
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
