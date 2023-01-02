local random = love.math.random

local function hexChar(c)
  local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
  return string.format('%x', v)
end

return function()
  local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
  return string.gsub(template, '[xy]', hexChar)
end
