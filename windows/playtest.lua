local love = love
local lg = love.graphics

local window = require "ui.window"
local strongType = require "lang.strongType"
local button = require "ui.button"

local errorTitleFont = lg.newFont(FontName, 42)
local errorFont = lg.newFont(FontName, 24)

local objectType = strongType.new("object", {
  x = { type = "number" },
  y = { type = "number" },
})

local playtest = {}
playtest.__index = playtest

function playtest.new(game)
  local self = setmetatable({}, playtest)
  self:init(game)
  return self
end

function playtest:init(game)
  self.objects = {}
  for _, obj in ipairs(game.objects) do
    local actual = {
      x = obj.x,
      y = obj.y,
      width = obj.width,
      height = obj.height,
      image = obj.image,
      events = obj.events,
      sourceMap = obj.sourceMap,
    }
    local instance = objectType:instance(actual)
    actual._instance = instance
    table.insert(self.objects, actual)
  end
  self.cameraX = 0
  self.cameraY = 0
  self.windowWidth = game.windowWidth
  self.windowHeight = game.windowHeight
  self.backgroundColor = game.backgroundColor
  self.running = true

  self.openCodeButton = button.new(50, self.windowHeight - 100, 130, 35, "Go to code", function()
    local w = OpenObjectCodeEditor(GetObjectById(self.errorSource))
    w.content.editor.cursor.line = self.errorLine
    w.content.editor.cursor.col = 1
    w.content.editor:scrollIntoView()
    w.content:updateScrollbars()
  end, errorFont)
end

function playtest:objectPcall(func, obj, ...)
  local success, result = pcall(func, obj._instance, ...)
  if not success then
    self.running = false
    local source, line, message = result:match('%[string "(.*)"%]:(%d*): (.*)')
    local actualLine
    for i = tonumber(line), 1, -1 do
      if obj.sourceMap[i] then
        actualLine = obj.sourceMap[i]
        break
      end
    end
    -- TODO show object name here
    self.error = ([[
[unnamed object]
Line %d:
%s
]]   ):format(actualLine, message)
    self.errorSource = source
    self.errorLine = actualLine
  end
end

function playtest:mousepressed(x, y, b)
  if self.error then
    self.openCodeButton:mousepressed(x, y, b)
  end
end

function playtest:mousereleased(x, y, b)
  if self.error then
    self.openCodeButton:mousereleased(x, y, b)
  end
end

function playtest:mousemoved(x, y, dx, dy)
  if self.error then
    self.openCodeButton:mousemoved(x, y, dx, dy)
  end
end

function playtest:keypressed(key)

end

function playtest:update(dt)
  if not self.running then return end

  for _, obj in ipairs(self.objects) do
    local f = obj.events["update"]
    if f then
      self:objectPcall(f, obj)
    end
  end
end

function playtest:draw()
  lg.setColor(self.backgroundColor)
  lg.rectangle("fill", 0, 0, self.windowWidth, self.windowHeight)
  lg.push()
  lg.translate(-self.cameraX, -self.cameraY)
  for _, obj in ipairs(self.objects) do
    lg.setColor(1, 1, 1)
    lg.draw(obj.image, obj.x, obj.y)
  end
  lg.pop()

  if self.error then
    lg.setColor(0, 0, 0, 0.8)
    lg.rectangle("fill", 0, 0, self.windowWidth, self.windowHeight)
    lg.setColor(1, 1, 1)
    lg.setFont(errorTitleFont)
    lg.print("Error:", 50, 50)
    lg.setFont(errorFont)
    lg.printf(self.error, 50, 60 + errorTitleFont:getHeight(), self.windowWidth - 80, "left")
    self.openCodeButton:draw()
  end
end

function playtest:window(x, y)
  local w = window.new(self, "Playtest", self.windowWidth, self.windowHeight + window.titleBarHeight, x, y)
  w.buttons = window.onlyCloseButton
  return w
end

return playtest
