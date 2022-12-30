FontName = "fonts/PT Root UI_Regular.ttf"

local window = require "ui.window"
function TODO(msg)
  error("todo: " .. msg, 1)
end

local imageEditor = require "imageEditor"

local resizeMargin = 12

local test = window.new(
  imageEditor.new(300, 200, 200, 200), "editor wow", 300, 200)
test.x = 50
test.y = 10
local test2 = window.new(
  imageEditor.new(200, 200, 300, 400), "another one", 200, 200)
test2.x = 450
test2.y = 10

local windows = { test, test2 }

local draggingWindow
local dragX, dragY

local resizingWindow
local resizeX, resizeY

local windowContentDown
local windowControlButtonDown

local function bringToTop(i)
  table.insert(windows, table.remove(windows, i))
end

love.graphics.setBackgroundColor(0.5, 0.5, 0.5)

function love.mousemoved(x, y, dx, dy)
  if draggingWindow then
    draggingWindow.x = x - dragX
    draggingWindow.y = y - dragY
  elseif resizingWindow then
    resizingWindow:resize(math.max(x - resizeX, 100), math.max(y - resizeY, window.titleBarHeight + 50))
  elseif windowContentDown then
    windowContentDown.content:mousemoved(x - windowContentDown.x, y - windowContentDown.y - window.titleBarHeight, dx, dy)
  else
    for i = #windows, 1, -1 do
      local w = windows[i]
      w.buttonOver = nil
      if w:inside(x, y) then
        if x >= w.x + w.width - resizeMargin and y >= w.y + w.height - resizeMargin then
          love.mouse.setCursor(love.mouse.getSystemCursor("sizenwse"))
        elseif y > w.y + window.titleBarHeight then
          w.content:mousemoved(x - w.x, y - w.y - window.titleBarHeight, dx, dy)
        else
          w.buttonOver = w:getTitleButtonOver(x, y)
          love.mouse.setCursor()
        end
        for j = i - 1, 1, -1 do
          windows[j].buttonOver = nil
        end
        goto anyOver
      end
    end
    love.mouse.setCursor()
    ::anyOver::
  end
end

function love.mousepressed(x, y, b)
  for i = #windows, 1, -1 do
    local w = windows[i]
    if w:inside(x, y) then
      if y < w.y + window.titleBarHeight then
        local button = w:getTitleButtonOver(x, y)
        if button then
          w.buttonDown = button
          windowControlButtonDown = w
        else
          draggingWindow = w
          dragX = x - w.x
          dragY = y - w.y
        end
      else
        local right = w.x + w.width
        local bottom = w.y + w.height
        if x >= right - resizeMargin and x <= right and y >= bottom - resizeMargin and y <= bottom then
          resizingWindow = w
          resizeX = x - w.width
          resizeY = y - w.height
        else
          w.content:mousepressed(x - w.x, y - w.y - window.titleBarHeight, b)
          windowContentDown = w
        end
      end
      bringToTop(i)
      break
    end
  end
end

function love.mousereleased(x, y, b)
  if windowControlButtonDown then
    if windowControlButtonDown:getTitleButtonOver(x, y) == windowControlButtonDown.buttonDown then
      local action = window.buttons[windowControlButtonDown.buttonDown].action
      TODO(action)
    end
    windowControlButtonDown.buttonDown = nil
    windowControlButtonDown = nil
    return
  end
  if draggingWindow then
    draggingWindow = nil
  elseif resizingWindow then
    resizingWindow = nil
  elseif windowContentDown then
    windowContentDown.content:mousereleased(x - windowContentDown.x, y - windowContentDown.y - window.titleBarHeight, b)
    windowContentDown = nil
  end
end

function love.wheelmoved(x, y)
  for i = #windows, 1, -1 do
    local w = windows[i]
    if w:inside(love.mouse.getPosition()) then
      w.content:wheelmoved(x, y)
      break
    end
  end
end

function love.keypressed(k)
  windows[#windows]:keypressed(k)
end

function love.draw()
  for _, w in ipairs(windows) do
    w:draw()
  end
end
