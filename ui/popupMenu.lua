local love = love
local lg = love.graphics

local button = require "ui.button"

local itemHeight = button.font:getHeight() + 10

local separatorMargin = 5

local popupMenu = {}
popupMenu.__index = popupMenu

-- `items` is a list of {text = string, action = function} or {separator = true}
function popupMenu.new(items, x, y, width)
  local self = setmetatable({}, popupMenu)
  self:init(items, x, y, width)
  return self
end

function popupMenu:init(items, x, y, width)
  self.x = x
  self.y = y
  self.width = width
  self.buttons = {}
  self.separators = {}
  local buttonY = 0
  for i, item in ipairs(items) do
    if item.separator then
      table.insert(self.separators, {y = buttonY + separatorMargin})
      buttonY = buttonY + separatorMargin * 2
    else
      local function onClick()
        ClosePopupMenu()
        if item.action then item.action() end
      end
      local new = button.new(0, buttonY, width, itemHeight, item.text, onClick)
      new.textAlign = "left"
      new.outline = false
      table.insert(self.buttons, new)
      buttonY = buttonY + new.height
    end
  end
  self.height = buttonY
  self.scaleY = 1
end

function popupMenu:inside(x, y)
  return x >= self.x and x < self.x + self.width and y >= self.y and y < self.y + self.height
end

local mouseEvents = { "mousepressed", "mousereleased", "mousemoved" }
for _, e in ipairs(mouseEvents) do
  popupMenu[e] = function(self, x, y, ...)
    x = x - self.x
    y = y - self.y
    for _, btn in ipairs(self.buttons) do
      btn[e](btn, x, y, ...)
    end
  end
end

function popupMenu:draw()
  lg.push()
  lg.translate(self.x, self.y)
  lg.scale(1, self.scaleY)

  lg.setColor(0, 0, 0, 0.9)
  lg.rectangle("fill", 0, 0, self.width, self.height, button.cornerSize)

  for _, b in ipairs(self.buttons) do
    b:draw()
  end

  lg.setColor(1, 1, 1)
  lg.setLineWidth(1)
  for _, s in ipairs(self.separators) do
    lg.line(separatorMargin, s.y, self.width - separatorMargin, s.y)
  end

  lg.setColor(1, 1, 1)
  lg.setLineWidth(1)
  lg.rectangle("line", 0, 0, self.width, self.height, button.cornerSize)

  lg.pop()
end

return popupMenu
