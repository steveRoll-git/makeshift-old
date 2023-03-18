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
local loopStuckWaitTime = 3

local topBarHeight = errorFont:getHeight() * 2

local playtest = {}
playtest.__index = playtest

function playtest.new(game)
  local self = setmetatable({}, playtest)
  self:init(game)
  return self
end

function playtest:init(game)
  self.environment = self:createEnvironment()

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
      id = obj.id,
    }
    for _, func in pairs(actual.events) do
      setfenv(func, self.environment)
    end
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

  self.topBarHeight = errorFont:getHeight() * 2

  -- this coroutine is responsible for running user code, which yields in loops.
  -- this is needed in order to give back control to makeshift in case user code
  -- runs in a loop and doesn't exit from it.
  self.codeRunner = coroutine.create(function(...)
    while true do
      local object, event, p1, p2, p3, p4 = coroutine.yield("eventEnd")
      local f = object.events[event]
      if f then
        self:objectPcall(f, object, p1, p2, p3, p4)
      end
    end
  end)
  coroutine.resume(self.codeRunner)

  -- if an event fires while there's a stuck loop, it will be stored here and be run after the loop exits
  self.pendingEvents = {}

  self.openErrorCodeButton = button.new(50, self.windowHeight - 100, 130, 35, "Go to code", function()
    local w = OpenObjectCodeEditor(GetObjectById(self.errorSource))
    w.content.editor.cursor.line = self.errorLine
    w.content.editor.cursor.col = 1
    w.content.editor:scrollIntoView()
    w.content:updateScrollbars()
  end, errorFont)

  local h = errorFont:getHeight() * 1.5
  self.openLoopCodeButton = button.new(self.windowWidth - 140, topBarHeight / 2 - h / 2, 130, h, "Go to code", function()
    local w = OpenObjectCodeEditor(GetObjectById(self.runningObject.id))
    w.content.editor.cursor.line = self.loopStuckLine
    w.content.editor.cursor.col = 1
    w.content.editor:scrollIntoView()
    w.content:updateScrollbars()
  end, errorFont)

  self.loopStuckText = lg.newText(errorFont)
  self.loopStuckText:addf(loopStuckMessage, self.windowWidth - self.openLoopCodeButton.w - 5, "left")
end

function playtest:createEnvironment()
  return {
    _yield = coroutine.yield,
    keyDown = function(key)
      local success, result = pcall(love.keyboard.isDown, key)
      if not success then
        error(("%q is not a valid key"):format(key), 2)
      end
      return result
    end
  }
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
]]):format(actualLine, message)
    self.errorSource = source
    self.errorLine = actualLine
  end
end

-- runs the event runner either until it finishes the current event, or
-- it runs a loop for more than a specified amount.
--
-- if parameters are given, it starts the runner with those parameters.
function playtest:tryContinueRunner(object, event, p1, p2, p3, p4)
  self.runningObject = object or self.runningObject

  local stillInLoop = true

  -- whether the initial call to `resume` was already done for this event
  local ranInitial = not object

  -- TODO make this code differentiate nested loops
  for i = 1, maxLoopYields do
    local success, result
    if not ranInitial then
      ranInitial = true
      success, result = coroutine.resume(self.codeRunner, object, event, p1, p2, p3, p4)
    else
      success, result = coroutine.resume(self.codeRunner)
    end
    if success then
      local loopLine = result:match("loop (%d+)")
      if loopLine then
        self.loopStuckLine = tonumber(loopLine)
      elseif result == "eventEnd" then
        stillInLoop = false
        self.runningObject = nil
        break
      else
        error("unknown coroutine result? " .. result)
      end
    else
      error(result)
    end
  end

  if stillInLoop then
    self.loopStuckTime = self.loopStuckTime or love.timer.getTime()
    self.stuckInLoop = true
  else
    self.showLoopMessage = false
    self.loopStuckTime = nil
    self.stuckInLoop = false
  end
end

-- starts executing an object's method. it may finish running in the same call,
-- but it may also enter a stuck loop from here.
function playtest:callObjectEvent(object, event, p1, p2, p3, p4)
  if self.stuckInLoop then
    -- insert this event to be executed later, after the code exits the stuck loop
    table.insert(self.pendingEvents, { object, event, p1, p2, p3, p4 })
    return
  end

  self:tryContinueRunner(object, event, p1, p2, p3, p4)
end

function playtest:mousepressed(x, y, b)
  if self.error then
    self.openErrorCodeButton:mousepressed(x, y, b)
    return
  end

  if self.showLoopMessage then
    self.openLoopCodeButton:mousepressed(x, y, b)
    return
  end
end

function playtest:mousereleased(x, y, b)
  if self.error then
    self.openErrorCodeButton:mousereleased(x, y, b)
    return
  end

  if self.showLoopMessage then
    self.openLoopCodeButton:mousereleased(x, y, b)
    return
  end
end

function playtest:mousemoved(x, y, dx, dy)
  if self.error then
    self.openErrorCodeButton:mousemoved(x, y, dx, dy)
    return
  end

  if self.showLoopMessage then
    self.openLoopCodeButton:mousemoved(x, y, dx, dy)
    return
  end
end

function playtest:keypressed(key)

end

function playtest:update(dt)
  if not self.running then return end

  -- if the code is currently stuck in a loop, we only focus on trying to
  -- complete it (one batch of tries every frame), and only run updates after it's finished
  if self.stuckInLoop then
    self:tryContinueRunner()
  end
  while not self.stuckInLoop and #self.pendingEvents > 0 do
    self:callObjectEvent(unpack(table.remove(self.pendingEvents, 1)))
  end
  if not self.stuckInLoop then
    -- finally, if we're not stuck in a loop anymore, run the update event for all objects.
    for _, object in ipairs(self.objects) do
      -- TODO decide whether to include deltatime or not
      self:callObjectEvent(object, "update")
    end
  end

  -- if enough time has passed since we got stuck in a loop, show the message
  if self.stuckInLoop and not self.showLoopMessage and
      love.timer.getTime() - self.loopStuckTime >= loopStuckWaitTime then
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
    lg.rectangle("fill", 0, 0, self.windowWidth, self.topBarHeight)
    lg.setColor(1, 1, 1)
    lg.draw(self.loopStuckText, 0, self.topBarHeight / 2 - self.loopStuckText:getHeight() / 2)
    self.openLoopCodeButton:draw()
  end

  if self.error then
    lg.setColor(0, 0, 0, 0.8)
    lg.rectangle("fill", 0, 0, self.windowWidth, self.windowHeight)
    lg.setColor(1, 1, 1)
    lg.setFont(errorTitleFont)
    lg.print("Error:", 50, 50)
    lg.setFont(errorFont)
    lg.printf(self.error, 50, 60 + errorTitleFont:getHeight(), self.windowWidth - 80, "left")
    self.openErrorCodeButton:draw()
  end
end

function playtest:window(x, y)
  local w = window.new(self, "Playtest", self.windowWidth, self.windowHeight + window.titleBarHeight, x, y)
  w.buttons = window.onlyCloseButton
  return w
end

return playtest
