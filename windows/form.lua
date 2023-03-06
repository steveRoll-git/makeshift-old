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
  self.elements = orderedSet.new()
  for _, e in ipairs(elements) do
    self:addElement(e)
  end
  self.mouseButtonsDown = {}
end

function form:setFocusedElement(e)
  if self.currentKeyboardFocus then
    self.currentKeyboardFocus.focused = false
  end
  e.focused = true
  self.currentKeyboardFocus = e
  if e.onFocus then
    e:onFocus()
  end
end

function form:addElement(e)
  self.elements:add(e)
  if e.keyboardFocus and not self.currentKeyboardFocus then
    self:setFocusedElement(e)
  end
end

function form:mousepressed(x, y, b)
  for _, e in ipairs(self.elements.list) do
    if e:isOver(x, y) then
      e:mousepressed(x, y, b)
      self.elementDown = e
      self.mouseButtonsDown[b] = true
      if e.keyboardFocus then
        self:setFocusedElement(e)
      end
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

function form:keypressed(key)
  if key == "tab" then
    local i = self.currentKeyboardFocus and self.elements:getIndex(self.currentKeyboardFocus) or 1
    local start = i
    local direction = love.keyboard.isDown("lshift", "rshift") and -1 or 1
    repeat
      i = (i + direction - 1) % #self.elements.list + 1
      local e = self.elements.list[i]
      if e.keyboardFocus then
        self:setFocusedElement(e)
        break
      end
    until i == start
  else
    if self.currentKeyboardFocus then
      self.currentKeyboardFocus:keypressed(key)
    end
  end
end

function form:textinput(t)
  if self.currentKeyboardFocus then
    self.currentKeyboardFocus:textinput(t)
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
