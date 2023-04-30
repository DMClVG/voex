local signal = {}
signal.__index = signal

function signal.new()
  local new = {}
  new.subs = {}
  setmetatable(new, signal)
  return new
end

function signal:catch(handle, ...) table.insert(self.subs, { handle = handle, opt = { ... } }) end

function signal:emit(...)
  for i = 1, #self.subs do
    local sub = self.subs[i]
    if #sub.opt ~= 0 then
      sub.handle(unpack(sub.opt), ...)
    else
      sub.handle(...)
    end
  end
end

return signal
