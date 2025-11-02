local client = require("client")
local server = require("server")
local common = require("common")

local clientgame = {
  ondraw = common.signal.new(),
  onupdate = common.signal.new(),
  onmousemoved = common.signal.new(),
  onmousepressed = common.signal.new(),
  onkeypressed = common.signal.new(),
  onresize = common.signal.new(),
  onquit = common.signal.new(),
}
local servergame = {
  onupdate = common.signal.new(),
  onquit = common.signal.new(),
}

function love.load(args)
   clientgame.args = args
   servergame.args = args

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

   client.init(clientgame, mocksocketA, "Jenny")
   server.init(servergame, mocksocketB)

   mocksocketA.onconnect:emit(peerB)
   mocksocketB.onconnect:emit(peerA)
end

function love.update(dt)
   clientgame.onupdate:emit(clientgame, dt)
   servergame.onupdate:emit(servergame, dt)
end

function love.draw()
   clientgame.ondraw:emit(clientgame)
end

function love.mousepressed(x, y, button, istouch, presses)
   clientgame.onmousepressed:emit(clientgame, x, y, button, istouch, presses)
end

function love.mousemoved(x, y, dx, dy, istouch)
   clientgame.onmousemoved:emit(clientgame, x, y, dx, dy, istouch)
end

function love.keypressed(k, scancode, isrepeat)
   clientgame.onkeypressed:emit(clientgame, k, scancode, isrepeat)
end

function love.resize(w, h)
   clientgame.onresize:emit(clientgame, w, h)
end

function love.quit()
   clientgame.onquit:emit(clientgame)
   servergame.onquit:emit(servergame)
end
