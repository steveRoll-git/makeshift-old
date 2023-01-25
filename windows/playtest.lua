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

local events = {
  "update", "mousepressed", "mousereleased", "mousemoved", "keypressed"
}

-- the maximum amount of times to `yield` inside a loop before moving on.
local maxLoopYields = 1000
local loopStuckMessage = "Your code may be stuck in an infinite loop."
-- how long to wait in a loop before showing the loop stuck message.
local loopStuckWaitTime = 5

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

  -- a separate coroutine is created for every event.
  -- this is for when a user-code function is stuck in an infinite loop,
  -- the `yield`s at the end of each loop can give control back to the playtest,
  -- preventing the whole program from being stuck.
  self.coroutines = {}
  for _, event in ipairs(events) do
    self.coroutines[event] = coroutine.create(function(...)
      while true do
        for _, obj in ipairs(self.objects) do
          local f = obj.events[event]
          if f then
            self:objectPcall(f, obj, ...)
          end
        end
        coroutine.yield("eventEnd")
      end
    end)
  end

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

function playtest:callEvent(event, ...)
  local co = self.coroutines[event]

  if self.loopStuckCoroutine and self.loopStuckCoroutine ~= co then
    return
  end

  local stillInLoop = true
  for i = 1, maxLoopYields do
    local success, result = coroutine.resume(co, ...)
    if success then
      if result ~= "loop" then
        stillInLoop = false
        break
      end
    else
      error(result)
    end
  end

  if stillInLoop then
    self.loopStuckCoroutine = co
    self.loopStuckTime = self.loopStuckTime or love.timer.getTime()
  else
    self.loopStuckCoroutine = nil
    self.showLoopMessage = false
  end
end

function playtest:mousepressed(x, y, b)
  if self.error then
    self.openCodeButton:mousepressed(x, y, b)
    return
  end
end

function playtest:mousereleased(x, y, b)
  if self.error then
    self.openCodeButton:mousereleased(x, y, b)
    return
  end
end

function playtest:mousemoved(x, y, dx, dy)
  if self.error then
    self.openCodeButton:mousemoved(x, y, dx, dy)
    return
  end
end

function playtest:keypressed(key)

end

function playtest:update(dt)
  if not self.running then return end

  self:callEvent("update", dt)

  if self.loopStuckCoroutine and not self.showLoopMessage and love.timer.getTime() - self.loopStuckTime >= loopStuckWaitTime then
    self.showLoopMessage = true
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

  if self.showLoopMessage then
    lg.setColor(0, 0, 0, 0.8)
    lg.rectangle("fill", 0, 0, errorFont:getWidth(loopStuckMessage), errorFont:getHeight())
    lg.setColor(1, 1, 1)
    lg.setFont(errorFont)
    lg.print(loopStuckMessage, 0, 0)
  end

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
