local love = love
local lg = love.graphics

FontName = "fonts/PT Root UI_Regular.ttf"

function TODO(msg)
  error("todo: " .. msg, 1)
end

love.window.maximize()

local prevWidth, prevHeight = love.graphics.getDimensions()

local flux = require "lib.flux"
local imageEditor = require "windows.imageEditor"
local window = require "ui.window"
local popupMenu = require "ui.popupMenu"

local resizeMargin = 12

local test = imageEditor.new(300, 200):window(100, 10)
local test2 = imageEditor.new(200, 200):window(450, 100)

local windows = { test, test2 }

local draggingWindow
local dragX, dragY

local resizingWindow
local resizeX, resizeY

local windowContentDown
local windowControlButtonDown

local activePopup

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

function AddWindow(w)
  w.canvas = lg.newCanvas(w.width, w.height)
  lg.setCanvas({ w.canvas, stencil = true })
  w:draw()
  lg.setCanvas()
  w.closeAnim = 1
  tweens:to(w, 0.1, { closeAnim = 0 })
      :oncomplete(function()
        w.closeAnim = nil
      end)
  table.insert(windows, w)
end

function StartClosingWindow(w)
  w.canvas = lg.newCanvas(w.width, w.height)
  lg.setCanvas({ w.canvas, stencil = true })
  w:draw()
  lg.setCanvas()
  w.closeAnim = 0
  tweens:to(w, 0.1, { closeAnim = 1 })
      :oncomplete(function()
        closeWindow(w)
      end)
end

function OpenPopupMenu(items, x, y)
  if not x then
    x, y = love.mouse.getPosition()
  end
  activePopup = popupMenu.new(items, x, y, 140)
end

function ClosePopupMenu()
  activePopup = nil
end

love.graphics.setBackgroundColor(0.5, 0.5, 0.5)

function love.mousemoved(x, y, dx, dy)
  if not love.mouse.isDown(1) then
    love.mouse.setCursor()
  end
  if activePopup then
    activePopup:mousemoved(x, y, dx, dy)
  elseif draggingWindow then
    if draggingWindow.maximized then
      draggingWindow:resize(draggingWindow.originalWidth, draggingWindow.originalHeight)
      draggingWindow.maximized = false
      dragX = math.min(dragX, draggingWindow.width - window.titleBarHeight * #draggingWindow.buttons)
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
        if w.resizable and not w.maximized and x >= w.x + w.width - resizeMargin and y >= w.y + w.height - resizeMargin then
          love.mouse.setCursor(love.mouse.getSystemCursor("sizenwse"))
        elseif y > w.y + window.titleBarHeight then
          w.content:mousemoved(x - w.x, y - w.y - window.titleBarHeight, dx, dy)
        else
          w.buttonOver = w:getTitleButtonOver(x, y)
        end
        for j = i - 1, 1, -1 do
          windows[j].buttonOver = nil
        end
        goto anyOver
      end
    end
    ::anyOver::
  end
end

function love.mousepressed(x, y, b)
  if activePopup then
    if activePopup:inside(x, y) then
      activePopup:mousepressed(x, y, b)
      return
    else
      activePopup = nil
    end
  end
  for i = #windows, 1, -1 do
    local w = windows[i]
    if not w.closeAnim and w:inside(x, y) then
      bringToTop(i)
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
        if w.resizable and not w.maximized and
            x >= right - resizeMargin and x <= right and y >= bottom - resizeMargin and y <= bottom then
          resizingWindow = w
          resizeX = x - w.width
          resizeY = y - w.height
        else
          w.content:mousepressed(x - w.x, y - w.y - window.titleBarHeight, b)
          windowContentDown = w
        end
      end
      return
    end
  end
  if b == 2 then
    OpenPopupMenu {
      { text = "New object" },
      { separator = true },
      { text = "Background color" }
    }
  end
end

function love.mousereleased(x, y, b)
  if activePopup then
    activePopup:mousereleased(x, y, b)
  elseif windowControlButtonDown then
    if windowControlButtonDown:getTitleButtonOver(x, y) == windowControlButtonDown.buttonDown then
      local theWindow = windowControlButtonDown
      local action = theWindow.buttons[theWindow.buttonDown].action
      if action == "close" then
        StartClosingWindow(theWindow)
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
  local last = windows[#windows].content
  if last.keypressed then
    last:keypressed(k)
  end
end

function love.update(dt)
  tweens:update(dt)
end

function love.resize(width, height)
  for _, w in ipairs(windows) do
    if w.maximized then
      w:resize(width, height)
    else
      w.x = (w.x / prevWidth) * width
      w.y = (w.y / prevHeight) * height
    end
  end
  prevWidth, prevHeight = width, height
end

function love.draw()
  for _, w in ipairs(windows) do
    lg.push()
    lg.translate(w.x, w.y)
    w:draw()
    lg.pop()
  end
  if activePopup then
    activePopup:draw()
  end
end
