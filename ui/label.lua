local love = love
local lg = love.graphics

local baseButton = require "ui.baseButton"

local defaultFont = love.graphics.newFont(FontName, 14)

local label = setmetatable({}, baseButton)
label.__index = label

function label.new(text, x, y, font, limitWidth, align)
  local self = setmetatable(baseButton.new(x, y, 0, 0), label)
  self:init(text, x, y, font, limitWidth, align)
  return self
end

function label:init(text, x, y, font, limitWidth, align)
  font = font or defaultFont
  self.text = lg.newText(font)
  if limitWidth then
    self.text:setf(text, limitWidth, align)
  else
    self.text:set(text)
  end
  self.x = x
  self.y = y
  self.w = self.text:getWidth()
  self.h = self.text:getHeight()
end

function label:draw()
  lg.draw(self.text, self.x, self.y)
end

return label
