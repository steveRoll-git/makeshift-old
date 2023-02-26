local love = love
local lg = love.graphics

local font = love.graphics.newFont(FontName, 14)
local margin = 4

local height = font:getHeight() + margin * 2

local button = require "ui.button"

local menuStrip = {}
menuStrip.__index = menuStrip

-- `buttons` is a list of {title = string, items = table}
function menuStrip.new(buttons)
  local self = setmetatable({}, menuStrip)
  self:init(buttons)
  return self
end

function menuStrip:init(buttons)
  self.buttons = {}
  local lastX = 0
  for _, b in ipairs(buttons) do
    assert(b.title, "menu strip button must have a title")
    assert(b.items, "menu strip button must have items")
    local theButton = button.new(
      lastX, 0,
      font:getWidth(b.title) + margin * 2, height,
      b.title
    )
    theButton.outline = false
    theButton.openMyMenu = function()
      OpenPopupMenu(b.items, self.window.x + theButton.x - 3, self.window.y + self.window.titleBarHeight + theButton.h)
      SetActiveMenuStrip(self)
    end
    theButton.onClick = function()
      if GetActiveMenuStrip() ~= self then
        theButton.openMyMenu()
      else
        ClosePopupMenu()
        SetActiveMenuStrip()
      end
    end
    theButton.onOver = function()
      if GetActiveMenuStrip() == self then
        theButton.openMyMenu()
      end
    end
    lastX = lastX + theButton.w
    table.insert(self.buttons, theButton)
  end
  self.height = height
end

function menuStrip:inside(x, y)
  return x >= self.window.x and x < self.window.x + self.window.width and
      y >= self.window.y + self.window.titleBarHeight and y < self.window.y + self.window.titleBarHeight + self.height
end

local mouseEvents = { "mousepressed", "mousereleased", "mousemoved" }
for _, e in ipairs(mouseEvents) do
  menuStrip[e] = function(self, x, y, ...)
    x = x - self.window.x
    y = y - self.window.y - self.window.titleBarHeight
    for _, btn in ipairs(self.buttons) do
      btn[e](btn, x, y, ...)
    end
  end
end

function menuStrip:draw()
  lg.setColor(0.1, 0.1, 0.1, 0.9)
  lg.rectangle("fill", 0, 0, self.window.width, height)
  for _, b in ipairs(self.buttons) do
    b:draw()
  end
end

return menuStrip
