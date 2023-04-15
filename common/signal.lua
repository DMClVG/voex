local signal = {}
signal.__index = signal

function signal.new()
    local new = {}
    new.subs = {}
    setmetatable(new, signal)
    return new
end

function signal:catch(handle)
    table.insert(self.subs, handle)
end

function signal:emit(...)
    for i = 0, #self.subs do
        self.subs[i](...)
    end
end

return signal
