local a = -1.0
local b = 1.0
return function(texture)
  return g3d.newModel({
    { 0, a, a, 1, 1 },
    { 0, b, b, 0, 0 },
    { 0, b, a, 0, 1 },

    { 0, a, a, 1, 1 },
    { 0, a, b, 1, 0 },
    { 0, b, b, 0, 0 },
  }, texture)
end
