local love = love
local lg = love.graphics

--local colors = require "colors"

local baseButton = {}
baseButton.__index = baseButton

function baseButton.new(x, y, w, h, onClick)
  local obj = setmetatable({x = x, y = y, w = w, h = h, over = false, down = false, focused = false, onClick = onClick}, baseButton)
  return obj
end

function baseButton:isOver(mx, my)
  return mx >= self.x and mx <= self.x + self.w and my >= self.y and my <= self.y + self.h
end

function baseButton:mousemoved(x, y, dx, dy)
  local pover = self.over
  self.over = self:isOver(x, y)
  if self.over ~= pover then
    if self.over and self.onOver then
      self:onOver()
    elseif not self.over and not self.down and self.onOut then
      self:onOut()
    end
  end
  if self.onMove then self:onMove(x, y, dx, dy) end
end

function baseButton:mousepressed(x, y, b)
  if b == 1 and self:isOver(x, y) then
    self.down = true
    if self.onDown then self:onDown(x, y, b) end
    return self
  end
end

function baseButton:mousereleased(x, y, b)
  if b == 1 and self.down and self:isOver(x, y) then
    if self.onClick then self:onClick(x, y, b) end
  elseif b == 2 and self.onRightClick and self:isOver(x, y) then
    self:onRightClick(x, y)
  end
  self.down = false
  if self.onRelease then self:onRelease(x, y, b) end
end

function baseButton:getRoot()
  if self.parent then
    return self.parent:getRoot()
  else
    return self
  end
end

function baseButton:inTree(element) -- if the object is anywhere in `element's` hierarchy
  if self == element then
    return true
  elseif self.parent then
    return self.parent:inTree(element)
  end
  return false
end

function baseButton:getGlobalOffset(orig)
  orig = orig or self
  local x, y = self.x, self.y
  if self.parent then
    local ox, oy = self.parent:getGlobalOffset(orig)
    x, y = x + ox, y + oy
  end
  return x, y
end

function baseButton:resize(w, h)
  self.w, self.h = w, h
  if self.onResize then self:onResize(w, h) end
end

--[[function baseButton:setFillColor()
  if self.down and self.over then
    lg.setColor(colors.down)
  elseif self.over or self.down then
    lg.setColor(colors.over)
  else
    lg.setColor(colors.bg)
  end
end]]

return baseButton