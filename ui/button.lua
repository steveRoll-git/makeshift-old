local love = love
local lg = love.graphics

local baseButton = require "ui.baseButton"

local defaultFont = love.graphics.newFont(FontName, 14)

local button = setmetatable({}, baseButton)
button.__index = button

button.cornerSize = 4

function button.new(x, y, width, height, text, onClick, font)
  local self = setmetatable(baseButton.new(x, y, width, height, onClick), button)
  self:init(text, font)
  return self
end

function button:init(text, font)
  self.text = text
  self.font = font or defaultFont
end

function button:draw()
  lg.push()
  lg.translate(self.x, self.y)
  if self.outline ~= false then
    lg.setLineWidth(1)
    lg.setColor(1, 1, 1)
    lg.rectangle("line", 0, 0, self.w, self.h, 4)
  end
  if self.down and self.enabled then
    lg.setColor(1, 1, 1, 0.4)
    lg.rectangle("fill", 0, 0, self.w, self.h, button.cornerSize)
  elseif self.over then
    lg.setColor(1, 1, 1, self.enabled and 0.2 or 0.1)
    lg.rectangle("fill", 0, 0, self.w, self.h, button.cornerSize)
  end
  lg.setFont(self.font)
  local c = self.enabled and 1 or 0.4
  lg.setColor(c, c, c, 1)
  lg.printf(self.text, button.cornerSize, self.h / 2 - self.font:getHeight() / 2, self.w - button.cornerSize * 2,
    self.textAlign or "center")
  lg.pop()
end

return button
