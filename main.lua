local love = love
local lg = love.graphics

FontName = "fonts/PT Root UI_Regular.ttf"

function TODO(msg)
  error("todo: " .. msg, 1)
end

local flux = require "lib.flux"
local imageEditor = require "windows.imageEditor"
local window = require "ui.window"

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

local tweens = flux.group()

local function bringToTop(i)
  table.insert(windows, table.remove(windows, i))
end

local function closeWindow(which)
  for i, w in ipairs(windows) do
    if w == which then
      table.remove(windows, i)
      return
    end
  end
end

love.graphics.setBackgroundColor(0.5, 0.5, 0.5)

function love.mousemoved(x, y, dx, dy)
  if draggingWindow then
    if draggingWindow.maximized then
      draggingWindow:resize(draggingWindow.originalWidth, draggingWindow.originalHeight)
      draggingWindow.maximized = false
      dragX = math.min(dragX, draggingWindow.width - window.titleBarHeight * #window.buttons)
    end
    draggingWindow.x = x - dragX
    draggingWindow.y = y - dragY
  elseif resizingWindow then
    resizingWindow:resize(math.max(x - resizeX, 100), math.max(y - resizeY, window.titleBarHeight + 50))
    resizingWindow.maximized = false
  elseif windowContentDown then
    windowContentDown.content:mousemoved(x - windowContentDown.x, y - windowContentDown.y - window.titleBarHeight, dx, dy)
  else
    for i = #windows, 1, -1 do
      local w = windows[i]
      w.buttonOver = nil
      if w:inside(x, y) then
        if not w.maximized and x >= w.x + w.width - resizeMargin and y >= w.y + w.height - resizeMargin then
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
    if not w.closeAnim and w:inside(x, y) then
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
        if not w.maximized and x >= right - resizeMargin and x <= right and y >= bottom - resizeMargin and y <= bottom then
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
      local theWindow = windowControlButtonDown
      local action = window.buttons[theWindow.buttonDown].action
      if action == "close" then
        theWindow.canvas = lg.newCanvas(theWindow.width, theWindow.height)
        lg.setCanvas({theWindow.canvas, stencil = true})
        theWindow:draw()
        lg.setCanvas()
        theWindow.closeAnim = 0
        tweens:to(theWindow, 0.1, { closeAnim = 1 })
            :oncomplete(function()
              closeWindow(theWindow)
            end)
      elseif action == "maximize" then
        theWindow.buttonOver = nil
        if not theWindow.maximized then
          theWindow.originalX = theWindow.x
          theWindow.originalY = theWindow.y
          theWindow.originalWidth = theWindow.width
          theWindow.originalHeight = theWindow.height
          theWindow.maximizeAnim = 0
          tweens:to(theWindow, 0.3,
            {
              width = love.graphics.getWidth(),
              height = love.graphics.getHeight(),
              x = 0, y = 0,
              maximizeAnim = 1
            })
              :onupdate(function()
                theWindow:resize(theWindow.width, theWindow.height)
              end)
              :oncomplete(function()
                theWindow.maximized = true
                theWindow.maximizeAnim = nil
              end)
              :ease("quintout")
        else
          theWindow.maximized = false
          theWindow.maximizeAnim = 1
          tweens:to(theWindow, 0.3,
            {
              width = theWindow.originalWidth,
              height = theWindow.originalHeight,
              x = theWindow.originalX, y = theWindow.originalY,
              maximizeAnim = 0,
            })
              :onupdate(function()
                theWindow:resize(theWindow.width, theWindow.height)
              end)
              :oncomplete(function()
                theWindow.maximizeAnim = nil
              end)
              :ease("quintout")
        end
      end
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

function love.update(dt)
  tweens:update(dt)
end

function love.draw()
  for _, w in ipairs(windows) do
    lg.push()
    lg.translate(w.x, w.y)
    w:draw()
    lg.pop()
  end
end
