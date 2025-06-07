package.path = package.path .. ";?/init.lua"
require("common")
inspect = require("common.lib.inspect")

CHANNEL_ONE = 0
CHANNEL_CHUNKS = 1
CHANNEL_EVENTS = 3
CHANNEL_UPDATES = 4

local state = {}
local impl = {}
local game = {}

local ch1, ch2


local commands = {}

-- function tolist(node)
--    if type(node) == "function" then
--       return { type="function", args={} }

--    elseif type(node) == "table" then
--       local ret = {}
--       for _, n in ipair(node) do
-- 	 table.push
-- 	 end
--    else

--    end
-- end

function build_arglist(args)
   if #args == 0 then
      return ""
   else
      return "local "..table.concat(args, ", ").." = ..."
   end
end

function rebuildfunction(name)
   local f = state[name]
   local newf, err = loadstring(build_arglist(f.args).."\n"..f.body)
   if err then error(err) end
   impl[name] = newf

   if game[name] == nil then
      game[name] = function(...) return impl[name](...) end
   end
end

function commands.list(path)
   return state
end

function commands.addfunction(name)
   state[name] = { type="function", args={}, body="" }
   rebuildfunction(name)
   return true
end

function commands.editfunction(name, args, body)
   state[name].args = args
   state[name].body = body
   rebuildfunction(name)
   return true
end


function commands.getfunction(name)
   return state[name]
end

function love.load(args)
  local tinsp = love.thread.newThread("insp.lua")
  ch1 = love.thread.newChannel()
  ch2 = love.thread.newChannel()
  tinsp:start(ch1, ch2)

  debug.sethook(function()
	if ch1:getCount() == 0 then return end
	local command = ch1:pop()
	local response = commands[command.method](unpack(command.params))
	print(inspect(command), inspect(response))
	ch2:push(response)
  end, "l")
end

function love.update(dt)
   if game.sayhi then
      game.sayhi(1, 3, 2)
   end
end

function love.quit() end
