local love = love
local lg = love.graphics

FontName = "fonts/PT Root UI_Regular.ttf"

local flux = require "lib.flux"
local imageEditor = require "windows.imageEditor"
local colorPicker = require "windows.colorPicker"
local window = require "ui.window"
local popupMenu = require "ui.popupMenu"
local orderedSet = require "util.orderedSet"
local clamp = require "util.clamp"
local guid = require "util.guid"

function TODO(msg)
  error("todo: " .. msg, 1)
end

love.window.maximize()

local prevWidth, prevHeight = love.graphics.getDimensions()

local resizeMargin = 12

local windows = orderedSet.new()
local windowsById = {}

local draggingWindow
local dragX, dragY

local resizingWindow
local resizeX, resizeY

local windowContentDown
local windowControlButtonDown

local activePopup

local drawingObject = false
local drawingObjectX, drawingObjectY

local objects = orderedSet.new()

local selectedObject
local draggingObject = false

local backgroundColor = { 0.7, 0.7, 0.7 }

local tweens = flux.group()

local function bringWindowToTop(w)
  windows:remove(w)
  windows:add(w)
end

local function closeWindow(which)
  if which.id then
    windowsById[which.id] = nil
  end
  windows:remove(which)
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
  windows:add(w)
  if w.id then
    windowsById[w.id] = w
  end
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
  activePopup.scaleY = 0.9
  tweens:to(activePopup, 0.2, { scaleY = 1 }):ease("quintout")
end

function ClosePopupMenu()
  activePopup = nil
end

local function openObjectImageEditor(object)
  local windowId = "image " .. object.id
  local theWindow = windowsById[windowId]
  if not theWindow then
    local editor = imageEditor.new(object.imageData)
    editor.onPaint = function(data)
      object.imageData = data
      object.image:replacePixels(data)
    end
    theWindow = editor:window(0, 0)
    theWindow.id = windowId
    AddWindow(theWindow)
  end
  theWindow.x = clamp(object.x + object.width + 20, 0, lg.getWidth() - theWindow.width)
  theWindow.y = clamp(object.y, 0, lg.getHeight() - theWindow.height)
  bringWindowToTop(theWindow)
end

love.graphics.setBackgroundColor(backgroundColor)

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
    resizingWindow:resize(
      math.max(x - resizeX, resizingWindow.minWidth or 100),
      math.max(y - resizeY, resizingWindow.minHeight or (window.titleBarHeight + 50)))
    resizingWindow.maximized = false
  elseif windowContentDown then
    windowContentDown.content:mousemoved(x - windowContentDown.x, y - windowContentDown.y - window.titleBarHeight, dx, dy)
  elseif selectedObject and draggingObject and love.mouse.isDown(1) then
    selectedObject.x = selectedObject.x + dx
    selectedObject.y = selectedObject.y + dy
  else
    for i = #windows.list, 1, -1 do
      local w = windows.list[i]
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
          windows.list[j].buttonOver = nil
        end
        goto anyOver
      end
    end
    if drawingObject then
      love.mouse.setCursor(love.mouse.getSystemCursor("crosshair"))
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
  for i = #windows.list, 1, -1 do
    local w = windows.list[i]
    if not w.closeAnim and w:inside(x, y) then
      bringWindowToTop(w)
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
  if b == 1 and drawingObject then
    -- TODO adjust for camera position
    drawingObjectX, drawingObjectY = x, y
    return
  end
  if b == 1 or b == 2 then
    selectedObject = nil
    for i = #objects.list, 1, -1 do
      local obj = objects.list[i]
      if x >= obj.x and x < obj.x + obj.width and y >= obj.y and y < obj.y + obj.height then
        selectedObject = obj
        draggingObject = true
        break
      end
    end
  end
  if b == 2 then
    if selectedObject then
      OpenPopupMenu {
        { text = "Paint", action = function()
          openObjectImageEditor(selectedObject)
        end },
        { separator = true },
        { text = "Bring to top", action = function()
          objects:remove(selectedObject)
          objects:add(selectedObject)
        end },
        { text = "Bring to bottom", action = function()
          objects:remove(selectedObject)
          objects:insertAt(1, selectedObject)
        end },
        { separator = true },
        { text = "Remove", action = function()
          objects:remove(selectedObject)
          selectedObject = nil
        end },
      }
    else
      OpenPopupMenu {
        { text = "New object", action = function()
          drawingObject = true
          love.mouse.setCursor(love.mouse.getSystemCursor("crosshair"))
        end },
        { separator = true },
        { text = "Background color", action = function()
          AddWindow(colorPicker.new(backgroundColor, function(color)
            backgroundColor = color
            lg.setBackgroundColor(backgroundColor)
          end):window(lg.getWidth() / 2 - 200, lg.getHeight() / 2 - 150, "Choose Background Color"))
        end }
      }
    end
  end
end

function love.mousereleased(x, y, b)
  if draggingObject then
    draggingObject = false
  elseif drawingObject and drawingObjectX then
    -- TODO input object name before adding
    if drawingObjectX ~= x and drawingObjectY ~= y then
      local new = {
        x = math.min(x, drawingObjectX),
        y = math.min(y, drawingObjectY),
        width = math.abs(x - drawingObjectX),
        height = math.abs(y - drawingObjectY),
        id = guid(),
      }
      new.imageData = love.image.newImageData(new.width, new.height)
      new.image = love.graphics.newImage(new.imageData)
      objects:add(new)
      selectedObject = new

      openObjectImageEditor(new)
    end

    drawingObject = false
    drawingObjectX = nil
    drawingObjectY = nil
    love.mouse.setCursor()
  elseif activePopup then
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
  for i = #windows.list, 1, -1 do
    local w = windows.list[i]
    if w:inside(love.mouse.getPosition()) then
      w.content:wheelmoved(x, y)
      break
    end
  end
end

function love.keypressed(k)
  local last = windows.list[windows.count].content
  if last.keypressed then
    last:keypressed(k)
  end
end

function love.update(dt)
  tweens:update(dt)
end

function love.resize(width, height)
  for _, w in ipairs(windows.list) do
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
  for _, obj in ipairs(objects.list) do
    lg.setColor(1, 1, 1)
    lg.draw(obj.image, obj.x, obj.y)
    lg.setColor(1, 1, 1, obj == selectedObject and 1 or 0.3)
    lg.setLineWidth(1)
    lg.rectangle("line", obj.x, obj.y, obj.width, obj.height)
  end
  if selectedObject then
    lg.setColor(1, 1, 1)
    lg.setLineWidth(1)
    lg.rectangle("line", selectedObject.x - 5, selectedObject.y - 5, selectedObject.width + 10,
      selectedObject.height + 10)
  end
  if drawingObject and drawingObjectX then
    lg.setColor(1, 1, 1)
    lg.setLineWidth(1)
    -- TODO adjust for camera position
    lg.rectangle("line", drawingObjectX, drawingObjectY, love.mouse.getX() - drawingObjectX,
      love.mouse.getY() - drawingObjectY)
  end
  for _, w in ipairs(windows.list) do
    lg.push()
    lg.translate(w.x, w.y)
    w:draw()
    lg.pop()
  end
  if activePopup then
    activePopup:draw()
  end
end
