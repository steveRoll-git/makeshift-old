local textEditor = require "ui.textEditor"
local window     = require "ui.window"

local font = love.graphics.newFont("fonts/source-code-pro.regular.ttf", 16)

local codeEditor = {}
codeEditor.__index = codeEditor

function codeEditor.new(text)
  local self = setmetatable({}, codeEditor)
  self:init(text)
  return self
end

function codeEditor:init(text)
  self.text = text
  self.editor = textEditor.new(0, 0, 100, 100, font, true)
end

function codeEditor:resize(width, height, prevWidth, prevHeight)
  self.editor:resize(width, height)
end

function codeEditor:mousepressed(x, y, b)
  self.editor:mousepressed(x, y, b)
end

function codeEditor:mousereleased(x, y, b)
  self.editor:mousereleased(x, y, b)
end

function codeEditor:mousemoved(x, y, dx, dy)
  self.editor:mousemoved(x, y, dx, dy)
end

function codeEditor:keypressed(key)
  self.editor:keypressed(key)
end

function codeEditor:textinput(t)
  self.editor:textinput(t)
end

function codeEditor:draw()
  self.editor:draw()
end

function codeEditor:window(x, y)
  local w = window.new(self, "Code Editor", 400, 300, x, y)
  w.buttons = window.allButtons
  w.resizable = true
  return w
end

return codeEditor
