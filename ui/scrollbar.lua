local clamp = require "util.clamp"
local love = love
local lg = love.graphics

local size = 16
local padding = 3
local cornerRadius = (size - padding * 2) / 2

local scrollbar = {}
scrollbar.__index = scrollbar

function scrollbar.new(axis, onScroll)
  local self = setmetatable({axis = axis, onScroll = onScroll, scrollX = 0, scrollY = 0, scrollWidth = size, scrollHeight = size}, scrollbar)
  if axis == "x" then
    self.height = size
  else
    self.width = size
  end
  return self
end

function scrollbar:insideBar(x, y)
  return x >= self.x + self.scrollX and x <= self.x + self.scrollX + self.scrollWidth and
      y >= self.y + self.scrollY and y <= self.y + self.scrollY + self.scrollHeight
end

function scrollbar:mousemoved(x, y, dx, dy)
  self.overBar = self:insideBar(x, y)
  if self.movingBar then
    if self.axis == "x" then
      self.scrollX = clamp(x - self.x + self.dragX, 0, self.width - self.scrollWidth)
    else
      self.scrollY = clamp(y - self.y + self.dragY, 0, self.height - self.scrollHeight)
    end
    if self.onScroll then
      self.onScroll()
    end
  end
end

function scrollbar:mousepressed(x, y, b)
  if b == 1 and self:insideBar(x, y) then
    self.movingBar = true
    if self.axis == "x" then
      self.dragX = self.scrollX - (x - self.x)
    else
      self.dragY = self.scrollY - (y - self.y)
    end
  end
end

function scrollbar:mousereleased(x, y, b)
  if b == 1 then
    self.movingBar = false
  end
end

function scrollbar:draw()
  lg.push()
  lg.translate(self.x, self.y)
  lg.setColor(0.1, 0.1, 0.1)
  lg.rectangle("fill", 0, 0, self.width, self.height)
  local c = self.movingBar and 0.9 or (self.overBar and 0.8 or 0.7)
  lg.setColor(c, c, c)
  lg.rectangle("fill", self.scrollX + padding, self.scrollY + padding, self.scrollWidth - padding * 2, self.scrollHeight - padding * 2, cornerRadius)
  lg.pop()
end

return scrollbar
