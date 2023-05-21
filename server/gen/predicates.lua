local predicates = {}
local floor = math.floor
local random, noise = love.math.random, love.math.noise

function predicates.always(_, _) return true end
function predicates.never(_, _) return false end
function predicates.checker(i, j) return (i + j) % 2 == 0 end

function predicates.noise(f, threshold)
  return function(i, j) return noise(i * f, j * f) > threshold end
end

return predicates
