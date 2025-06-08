package.path = package.path .. ";?/init.lua"
require("common")
inspect = require("common.lib.inspect")

local luaparser = require("common.lib.lua-parser.lua-parser.parser")
local luaparserpp = require("common.lib.lua-parser.lua-parser.pp")

CHANNEL_ONE = 0
CHANNEL_CHUNKS = 1
CHANNEL_EVENTS = 3
CHANNEL_UPDATES = 4

local state = {}
local impl = {}
voex = {}

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

function trim(s)
  return s:match("^%s*(.-)%s*$")
end

function rebuildfunction(name, isnew)
   local global = state[name]
   if not isnew and trim(global.body) == "" then
      state[name] = nil
      voex[name] = nil
      return
   end

   local body, err = loadstring("return "..global.body)
   if err then
      io.stderr:write(err.."\n")
      return
   end

   voex[name] = body()
end

function initfunction(name)
   if state[name] == nil then
      state[name] = { type="function", args={}, body="" }
      rebuildfunction(name, true)
   end
end

function commands.list(path)
   return state
end

function commands.addfunction(name)
   initfunction(name)
   return true
end

function commands.editfunction(name, args, body)
   initfunction(name)
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
   if voex.sayhi then
      voex.sayhi(1, 3, 2)
   end
end

function love.quit() end
