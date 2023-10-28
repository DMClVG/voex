local signal = {}
signal.__index = signal

local signal_handle = {}
signal_handle.__index = signal_handle

function signal_handle:destroy() self.signal.subs[self.id] = nil end

function signal.new()
  local new = {}
  new.subs = {}
  new.idc = 0
  setmetatable(new, signal)
  return new
end

function signal:catch(f, ...)
  assert(f)
  local handle = { signal = self, id = self.idc }
  setmetatable(handle, signal_handle)
  self.idc = self.idc + 1

  self.subs[handle.id] = { f = f, opt = { ... } }
  return handle
end

function signal:emit(...)
  for id, sub in pairs(self.subs) do
    if #sub.opt ~= 0 then
      local args = { ... }
      for n = #sub.opt, 1, -1 do
        table.insert(args, 1, sub.opt[n])
      end

      sub.f(unpack(args))
    else
      sub.f(...)
    end
  end
end

return signal
