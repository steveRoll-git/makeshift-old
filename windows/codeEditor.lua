local love = love
local lg = love.graphics

local textEditor = require "ui.textEditor"
local window     = require "ui.window"
local scrollbar  = require "ui.scrollbar"
local clamp      = require "util.clamp"
local parser     = require "lang.parser"
local inspect    = require "lib.inspect"

local font = love.graphics.newFont("fonts/source-code-pro.regular.ttf", 16)

local function parseObjectCode(code)
  local theParser = parser.new(code)
  return theParser:parseObjectCode()
end

local codeEditor = {}
codeEditor.__index = codeEditor

function codeEditor.new(targetObject)
  local self = setmetatable({}, codeEditor)
  self:init(targetObject)
  return self
end

function codeEditor:init(targetObject)
  self.targetObject = targetObject
  self.text = targetObject.code or ""
  self.editor = textEditor.new(0, 0, 100, 100, font, true, self.text)
  self.scrollbarY = scrollbar.new("y", function()
    self.editor.textY = textEditor.textPadding -
        self.scrollbarY.scrollY / (self.scrollbarY.height - self.scrollbarY.scrollHeight) *
        (self:totalTextHeight() - self:clientHeight())
  end)
  self.scrollbarX = scrollbar.new("x", function()
    self.editor.textX = textEditor.textPadding -
        self.scrollbarX.scrollX / self.scrollbarX.width * self.totalTextWidth
  end)
  self.scrollY = 0
  self.scrollX = 0
  -- how long to wait after no input before doing a syntax check
  self.inactivityInterval = 0.5
  self.lastActivityTime = love.timer.getTime()
end

function codeEditor:totalTextHeight()
  return #self.editor.lines * self.editor.font:getHeight() + textEditor.textPadding * 2
end

function codeEditor:updateScrollY()
  self.scrollbarY.scrollY = -(self.editor.textY - textEditor.textPadding) / self:totalTextHeight() *
      self.scrollbarY.height
end

function codeEditor:updateScrollX()
  self.scrollbarX.scrollX = -(self.editor.textX - textEditor.textPadding) / self.totalTextWidth *
      self.scrollbarX.width
end

function codeEditor:clientWidth()
  return self.windowWidth - self.scrollbarY.width
end

function codeEditor:clientHeight()
  return self.windowHeight - self.scrollbarX.height
end

function codeEditor:updateScrollbars()
  local totalHeight = self:totalTextHeight()
  if totalHeight > self:clientHeight() then
    self.yScrollEnabled = true
    self.editor.textY = math.max(self.editor.textY, self:clientHeight() - totalHeight + textEditor.textPadding)
    self.scrollbarY.scrollHeight = self:clientHeight() / totalHeight * self.scrollbarY.height
    self:updateScrollY()
  else
    self.yScrollEnabled = false
    self.editor.textY = textEditor.textPadding
  end
  local maxWidth = 0
  for _, l in ipairs(self.editor.lines) do
    maxWidth = math.max(maxWidth, l.totalWidth)
  end
  self.totalTextWidth = maxWidth + textEditor.textPadding * 2
  if self.totalTextWidth > self:clientWidth() then
    self.xScrollEnabled = true
    self.editor.textX = math.max(self.editor.textX, self:clientWidth() - self.totalTextWidth + textEditor.textPadding)
    self.scrollbarX.scrollWidth = self:clientWidth() / self.totalTextWidth * self:clientWidth()
    self:updateScrollX()
  else
    self.xScrollEnabled = false
  end
end

function codeEditor:activity()
  self.lastActivityTime = love.timer.getTime()
  if self.syntaxUnderline then
    self.editor.underlines:remove(self.syntaxUnderline)
    self.syntaxUnderline = nil
  end
  self.didCheck = false
end

function codeEditor:checkSyntax()
  self:flushCode()
  local success, result = pcall(parseObjectCode, self.targetObject.code)
  if not success then
    self.syntaxUnderline = {
      fromLine = result.fromLine,
      fromColumn = result.fromColumn,
      toLine = result.toLine,
      toColumn = result.toColumn,
      color = { 1, 0, 0 },
    }
    self.editor.underlines:add(self.syntaxUnderline)
  end
end

function codeEditor:resize(width, height, prevWidth, prevHeight)
  self.editor:resize(width - self.scrollbarY.width, height - self.scrollbarX.height)
  self.scrollbarY.x = width - self.scrollbarY.width
  self.scrollbarY.y = 0
  self.scrollbarY.height = height - self.scrollbarX.height
  self.scrollbarX.x = 0
  self.scrollbarX.y = height - self.scrollbarX.height
  self.scrollbarX.width = self:clientWidth()
  self:updateScrollbars()
end

function codeEditor:mousepressed(x, y, b)
  self.editor:mousepressed(x, y, b)
  if self.yScrollEnabled then
    self.scrollbarY:mousepressed(x, y, b)
  end
  if self.xScrollEnabled then
    self.scrollbarX:mousepressed(x, y, b)
  end
end

function codeEditor:mousereleased(x, y, b)
  self.editor:mousereleased(x, y, b)
  if self.yScrollEnabled then
    self.scrollbarY:mousereleased(x, y, b)
  end
  if self.xScrollEnabled then
    self.scrollbarX:mousereleased(x, y, b)
  end
end

function codeEditor:mousemoved(x, y, dx, dy)
  if not self.scrollbarY.movingBar and not self.scrollbarX.movingBar then
    self.editor:mousemoved(x, y, dx, dy)
  end
  if self.yScrollEnabled then
    self.scrollbarY:mousemoved(x, y, dx, dy)
  end
  if self.xScrollEnabled then
    self.scrollbarX:mousemoved(x, y, dx, dy)
  end
end

function codeEditor:wheelmoved(x, y)
  if self.yScrollEnabled then
    self.editor.textY = clamp(
      self.editor.textY + y * self.editor.font:getHeight() * 3,
      -self:totalTextHeight() + self.windowHeight + textEditor.textPadding - self.scrollbarX.height,
      textEditor.textPadding)
    self:updateScrollY()
  end
end

function codeEditor:keypressed(key)
  self.editor:keypressed(key)
  self:updateScrollbars()
  self:activity()
end

function codeEditor:textinput(t)
  self.editor:textinput(t)
  self:updateScrollbars()
  self:activity()
end

function codeEditor:update(dt)
  if not self.didCheck and love.timer.getTime() >= self.lastActivityTime + self.inactivityInterval then
    self.didCheck = true

    self:checkSyntax()
  end
end

function codeEditor:flushCode()
  self.targetObject.code = self.editor:getString()
end

function codeEditor:close()
  self:flushCode()
end

function codeEditor:beforePlaytest()
  self:flushCode()
end

function codeEditor:draw()
  lg.setColor(0, 0, 0, 0.8)
  lg.rectangle("fill", 0, 0, self.windowWidth, self.windowHeight)
  self.editor:draw()
  if self.yScrollEnabled then
    self.scrollbarY:draw()
  end
  if self.xScrollEnabled then
    self.scrollbarX:draw()
  end

  lg.setColor(0.3, 0.3, 0.3)
  lg.setLineWidth(1)
  lg.line(self.windowWidth - self.scrollbarY.width, 0, self.windowWidth - self.scrollbarY.width,
    self.windowHeight - self.scrollbarX.height)
  lg.line(0, self.windowHeight - self.scrollbarX.height, self.windowWidth - self.scrollbarY.width,
    self.windowHeight - self.scrollbarX.height)
end

function codeEditor:window(x, y)
  local w = window.new(self, "Code Editor", 400, 300, x, y)
  w.buttons = window.allButtons
  w.resizable = true
  return w
end

return codeEditor
