local window = require "ui.window"
local orderedSet = require "util.orderedSet"

local form = {}
form.__index = form

function form.new(title, width, height, elements)
  local self = setmetatable({}, form)
  self:init(title, width, height, elements)
  return self
end

function form:init(title, width, height, elements)
  self.title = title
  self.width = width
  self.height = height
  self.elements = orderedSet.new(elements)
  self.mouseButtonsDown = {}
end

function form:mousepressed(x, y, b)
  for _, e in ipairs(self.elements.list) do
    if e:isOver(x, y) then
      e:mousepressed(x, y, b)
      self.elementDown = e
      self.mouseButtonsDown[b] = true
      break
    end
  end
end

function form:mousereleased(x, y, b)
  if self.elementDown and self.mouseButtonsDown[b] then
    self.mouseButtonsDown[b] = nil
    self.elementDown:mousereleased(x, y, b)
    if not next(self.mouseButtonsDown) then
      -- unset elementDown when all mouse buttons are released
      self.elementDown = nil
    end
  end
end

function form:mousemoved(x, y, dx, dy)
  if self.elementDown then
    self.elementDown:mousemoved(x, y, dx, dy)
    return
  end
  for _, e in ipairs(self.elements.list) do
    e:mousemoved(x, y, dx, dy)
  end
end

function form:draw()
  for _, e in ipairs(self.elements.list) do
    e:draw()
  end
end

function form:window(resizable, x, y)
  local w = window.new(self, self.title, self.width, self.height, x, y)
  if resizable then
    w.buttons = window.allButtons
    w.resizable = true
  else
    w.buttons = window.onlyCloseButton
  end
  return w
end

return form
