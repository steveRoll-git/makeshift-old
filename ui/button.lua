local love = love
local lg = love.graphics

local font = love.graphics.newFont(FontName, 14)

local button = {}
button.__index = button

button.font = font
button.cornerSize = 4

function button.new(x, y, width, height, text, onClick)
  local self = setmetatable({}, button)
  self:init(x, y, width, height, text, onClick)
  return self
end

function button:init(x, y, width, height, text, onClick)
  self.x = x
  self.y = y
  self.width = width
  self.height = height
  self.text = text
  self.onClick = onClick
  self.enabled = true
end

function button:inside(x, y)
  return x >= self.x and x < self.x + self.width and y >= self.y and y < self.y + self.height
end

function button:mousemoved(x, y, dx, dy)
  self.over = self:inside(x, y)
end

function button:mousepressed(x, y, b)
  if b == 1 and self:inside(x, y) then
    self.down = true
  end
end

function button:mousereleased(x, y, b)
  if b == 1 then
    if self.down and self:inside(x, y) then
      if self.enabled and self.onClick then self.onClick() end
    end
    self.down = false
  end
end

function button:draw()
  lg.push()
  lg.translate(self.x, self.y)
  if self.outline ~= false then
    lg.setLineWidth(1)
    lg.setColor(1, 1, 1)
    lg.rectangle("line", 0, 0, self.width, self.height, 4)
  end
  if self.down and self.enabled then
    lg.setColor(1, 1, 1, 0.4)
    lg.rectangle("fill", 0, 0, self.width, self.height, button.cornerSize)
  elseif self.over then
    lg.setColor(1, 1, 1, self.enabled and 0.2 or 0.1)
    lg.rectangle("fill", 0, 0, self.width, self.height, button.cornerSize)
  end
  lg.setFont(font)
  local c = self.enabled and 1 or 0.4
  lg.setColor(c, c, c, 1)
  lg.printf(self.text, button.cornerSize, self.height / 2 - font:getHeight() / 2, self.width - button.cornerSize * 2,
    self.textAlign or "center")
  lg.pop()
end

return button
