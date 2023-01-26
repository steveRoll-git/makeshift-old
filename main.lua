io.output():setvbuf("no")

local love = love
local lg = love.graphics

love.keyboard.setKeyRepeat(true)

FontName = "fonts/PT Root UI_Regular.ttf"

local flux = require "lib.flux"
local inspect = require "lib.inspect"
local imageEditor = require "windows.imageEditor"
local colorPicker = require "windows.colorPicker"
local codeEditor = require "windows.codeEditor"
local playtest = require "windows.playtest"
local window = require "ui.window"
local popupMenu = require "ui.popupMenu"
local orderedSet = require "util.orderedSet"
local clamp = require "util.clamp"
local guid = require "util.guid"
local parser = require "lang.parser"
local outputLua = require "lang.outputLua"

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
local activeMenuStrip
local menuStripDown

local drawingObject = false
local drawingObjectX, drawingObjectY

local objects = orderedSet.new()
local objectsById = {}

local selectedObject
local draggingObject = false
local objectDragX, objectDragY
local copiedObject

local backgroundColor = { 0.7, 0.7, 0.7 }

local gameWindowWidth, gameWindowHeight = 600, 450

local cameraX = gameWindowWidth / 2 - lg.getWidth() / 2
local cameraY = gameWindowHeight / 2 - lg.getHeight() / 2
local panning = false

local gridSize = 100

local stencilLevel = 0

local nextCursor

local currentPlaytest

local dimColor = { 0, 0, 0, 0 }

local tweens = flux.group()

local function screenToWorld(x, y)
  return x + cameraX, y + cameraY
end

local function worldToScreen(x, y)
  return x - cameraX, y - cameraY
end

function PushStencil(func)
  stencilLevel = stencilLevel + 1
  lg.stencil(func, "increment", 1, true)
  lg.setStencilTest("equal", stencilLevel)
end

function PopStencil(func)
  lg.stencil(func, "decrement", 1, true)
  lg.setStencilTest("equal", stencilLevel)
  stencilLevel = stencilLevel - 1
  if stencilLevel == 0 then
    lg.setStencilTest()
  end
end

local function bringWindowToTop(w)
  windows:remove(w)
  windows:add(w)
  if w.modalChild then
    bringWindowToTop(w.modalChild)
  end
end

local function closeWindow(which)
  if which.id then
    windowsById[which.id] = nil
  end
  windows:remove(which)
  if which.content.close then
    which.content:close()
  end
  if which.modalParent then
    which.modalParent.modalChild = nil
  end
  if which.content == currentPlaytest then
    currentPlaytest = nil
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
  if w.modalParent then
    tweens:to(w.modalParent, 0.1, { modalOverlayAlpha = 0 })
  end
  if w.content == currentPlaytest then
    tweens:to(dimColor, 0.2, { [4] = 0.0 })
  end
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
  activeMenuStrip = nil
end

function SetActiveMenuStrip(strip)
  activeMenuStrip = strip
end

function GetActiveMenuStrip()
  return activeMenuStrip
end

function SetCursor(cursor)
  nextCursor = cursor
end

function AddTween(object, duration, keys)
  return tweens:to(object, duration, keys)
end

local function closeIfExists(windowId)
  if windowsById[windowId] then
    StartClosingWindow(windowsById[windowId])
  end
end

local function addObject(object)
  objects:add(object)
  objectsById[object.id] = object
end

local function removeObject(object)
  objects:remove(object)
  objectsById[object.id] = nil
  selectedObject = nil
  closeIfExists("image " .. object.id)
  closeIfExists("code " .. object.id)
end

function GetObjectById(id)
  return objectsById[id]
end

local function openObjectImageEditor(object)
  local windowId = "image " .. object.id
  local theWindow = windowsById[windowId]
  if not theWindow then
    local editor = imageEditor.new(object.imageData)
    editor.onPaint = function(data)
      object.imageData = data
      local prevW, prevH = object.image:getDimensions()
      if prevW ~= data:getWidth() or prevH ~= data:getHeight() then
        object.image = lg.newImage(data)
        object.width, object.height = data:getDimensions()
      else
        object.image:replacePixels(data)
      end
    end
    theWindow = editor:window(0, 0)
    theWindow.id = windowId
    AddWindow(theWindow)
  end
  local screenX, screenY = worldToScreen(object.x, object.y)
  theWindow.x = clamp(screenX + object.width + 20, 0, lg.getWidth() - theWindow.width)
  theWindow.y = clamp(screenY, 0, lg.getHeight() - theWindow.height)
  bringWindowToTop(theWindow)
end

function OpenObjectCodeEditor(object)
  local windowId = "code " .. object.id
  local theWindow = windowsById[windowId]
  if not theWindow then
    local editor = codeEditor.new(object)
    theWindow = editor:window(0, 0)
    theWindow.id = windowId
    AddWindow(theWindow)
  end
  local screenX, screenY = worldToScreen(object.x, object.y)
  theWindow.x = clamp(screenX + object.width + 20, 0, lg.getWidth() - theWindow.width)
  theWindow.y = clamp(screenY, 0, lg.getHeight() - theWindow.height)
  bringWindowToTop(theWindow)
  return theWindow
end

local function parseObjectCode(code)
  local theParser = parser.new(code)
  return theParser:parseObjectCode()
end

love.graphics.setBackgroundColor(backgroundColor)

function love.mousemoved(x, y, dx, dy)
  local worldX, worldY = screenToWorld(x, y)
  if not love.mouse.isDown(1) then
    nextCursor = nil
  end
  if activeMenuStrip then
    activeMenuStrip:mousemoved(x, y, dx, dy)
  end
  if panning then
    cameraX = cameraX - dx
    cameraY = cameraY - dy
  elseif activePopup then
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
    windowContentDown.content:mousemoved(x - windowContentDown.x,
      y - windowContentDown.y - windowContentDown:contentYOffset(), dx, dy)
  elseif selectedObject and draggingObject and love.mouse.isDown(1) then
    selectedObject.x = (worldX - objectDragX)
    selectedObject.y = (worldY - objectDragY)
  else
    for i = #windows.list, 1, -1 do
      local w = windows.list[i]
      w.buttonOver = nil
      if w:inside(x, y) then
        if w.resizable and not w.maximized and x >= w.x + w.width - resizeMargin and y >= w.y + w.height - resizeMargin then
          SetCursor(love.mouse.getSystemCursor("sizenwse"))
        elseif y < w.y + window.titleBarHeight then
          w.buttonOver = w:getTitleButtonOver(x, y)
        else
          w.content:mousemoved(x - w.x, y - w.y - w:contentYOffset(), dx, dy)
        end
        if w.menuStrip then
          w.menuStrip:mousemoved(x, y, dx, dy)
        end
        for j = i - 1, 1, -1 do
          windows.list[j].buttonOver = nil
        end
        goto anyOver
      end
    end
    if drawingObject then
      SetCursor(love.mouse.getSystemCursor("crosshair"))
    end
    ::anyOver::
  end
  love.mouse.setCursor(nextCursor)
end

function love.mousepressed(x, y, b)
  local worldX, worldY = screenToWorld(x, y)
  if activePopup then
    if activePopup:inside(x, y) then
      activePopup:mousepressed(x, y, b)
      return
    elseif not activeMenuStrip or not activeMenuStrip:inside(x, y) then
      activePopup = nil
      activeMenuStrip = nil
    end
  end
  for i = #windows.list, 1, -1 do
    local w = windows.list[i]
    if not w.closeAnim and w:inside(x, y) then
      bringWindowToTop(w)
      if y < w.y + window.titleBarHeight then
        if b == 1 then
          local button = w:getTitleButtonOver(x, y)
          if button then
            w.buttonDown = button
            windowControlButtonDown = w
          else
            draggingWindow = w
            dragX = x - w.x
            dragY = y - w.y
          end
        end
      elseif w.menuStrip and y < w.y + window.titleBarHeight + w.menuStrip.height then
        w.menuStrip:mousepressed(x, y, b)
        menuStripDown = w.menuStrip
      else
        local right = w.x + w.width
        local bottom = w.y + w.height
        if w.resizable and not w.maximized and
            x >= right - resizeMargin and x <= right and y >= bottom - resizeMargin and y <= bottom then
          resizingWindow = w
          resizeX = x - w.width
          resizeY = y - w.height
        elseif not w.modalChild then
          w.content:mousepressed(x - w.x, y - w.y - w:contentYOffset(), b)
          windowContentDown = w
        end
      end
      return
    end
  end
  if b == 1 and drawingObject then
    drawingObjectX, drawingObjectY = worldX, worldY
    return
  end
  if b == 1 or b == 2 then
    selectedObject = nil
    for i = #objects.list, 1, -1 do
      local obj = objects.list[i]
      if worldX >= obj.x and worldX < obj.x + obj.width and worldY >= obj.y and worldY < obj.y + obj.height then
        selectedObject = obj
        if b == 1 then
          objectDragX = worldX - obj.x
          objectDragY = worldY - obj.y
          draggingObject = true
        end
        break
      end
    end
  end
  if b == 2 then
    if selectedObject then
      OpenPopupMenu {
        { text = "Paint", action = function()
          if selectedObject.copiedImage then
            selectedObject.copiedImage = false
            selectedObject.imageData = selectedObject.imageData:clone()
            selectedObject.image = lg.newImage(selectedObject.imageData)
          end
          -- copiedObject points to to the original object's imageData
          -- until it's edited, in which case a copy is made
          if copiedObject and selectedObject.imageData == copiedObject.imageData then
            selectedObject.imageData = selectedObject.imageData:clone()
            selectedObject.image = lg.newImage(selectedObject.imageData)
          end
          openObjectImageEditor(selectedObject)
        end },
        { text = "Code", action = function()
          OpenObjectCodeEditor(selectedObject)
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
        { text = "Copy", action = function()
          copiedObject = {
            width = selectedObject.width,
            height = selectedObject.height,
            imageData = selectedObject.imageData,
            image = selectedObject.image,
            code = selectedObject.code,
          }
        end },
        { separator = true },
        { text = "Remove", action = function()
          removeObject(selectedObject)
        end },
      }
    else
      OpenPopupMenu {
        { text = "New object", action = function()
          drawingObject = true
          love.mouse.setCursor(love.mouse.getSystemCursor("crosshair"))
        end },
        { text = "Paste", enabled = copiedObject ~= nil, action = function()
          local new = {
            x = worldX,
            y = worldY,
            width = copiedObject.width,
            height = copiedObject.height,
            imageData = copiedObject.imageData,
            code = copiedObject.code,
            copiedImage = true,
            id = guid()
          }
          new.image = copiedObject.image
          addObject(new)
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
    return
  end
  if b == 3 then
    panning = true
  end
end

function love.mousereleased(x, y, b)
  local worldX, worldY = screenToWorld(x, y)
  if b == 3 and panning then
    panning = false
  elseif b == 1 and draggingObject then
    draggingObject = false
  elseif b == 1 and drawingObject and drawingObjectX then
    -- TODO input object name before adding
    if drawingObjectX ~= worldX and drawingObjectY ~= worldY then
      local new = {
        x = math.min(worldX, drawingObjectX),
        y = math.min(worldY, drawingObjectY),
        width = math.abs(worldX - drawingObjectX),
        height = math.abs(worldY - drawingObjectY),
        id = guid(),
      }
      new.imageData = love.image.newImageData(new.width, new.height)
      new.image = love.graphics.newImage(new.imageData)
      addObject(new)
      selectedObject = new

      openObjectImageEditor(new)
    end

    drawingObject = false
    drawingObjectX = nil
    drawingObjectY = nil
    love.mouse.setCursor()
  elseif menuStripDown then
    menuStripDown:mousereleased(x, y, b)
    menuStripDown = nil
  elseif activePopup then
    activePopup:mousereleased(x, y, b)
  elseif b == 1 and windowControlButtonDown then
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
  if b == 1 and draggingWindow then
    draggingWindow = nil
  elseif b == 1 and resizingWindow then
    resizingWindow = nil
  elseif windowContentDown then
    windowContentDown.content:mousereleased(x - windowContentDown.x,
      y - windowContentDown.y - windowContentDown:contentYOffset(), b)
    windowContentDown = nil
  end
end

function love.wheelmoved(x, y)
  for i = #windows.list, 1, -1 do
    local w = windows.list[i]
    if not w.modalChild and w.content.wheelmoved and w:inside(love.mouse.getPosition()) then
      w.content:wheelmoved(x, y)
      break
    end
  end
end

function love.keypressed(k)
  if k == "f5" and not currentPlaytest then
    for _, w in ipairs(windows.list) do
      if w.content.beforePlaytest then
        w.content:beforePlaytest()
      end
    end
    local compilationError
    for _, obj in ipairs(objects.list) do
      if obj.code then
        local success, result = pcall(parseObjectCode, obj.code)
        if success then
          local code, sourceMap = outputLua(result)
          local compiledCode, luaError = loadstring(code, obj.id)
          if luaError then
            error(luaError)
          end
          obj.compiledCode = compiledCode
          obj.sourceMap = sourceMap
          obj.events = obj.compiledCode()
        else
          -- TODO show toast alert "fix syntax errors before running!"
          local editor = OpenObjectCodeEditor(obj).content
          editor:checkSyntax()
          compilationError = result
          break
        end
      else
        obj.events = {}
      end
    end
    if not compilationError then
      currentPlaytest = playtest.new {
        objects = objects.list,
        backgroundColor = backgroundColor,
        windowWidth = gameWindowWidth,
        windowHeight = gameWindowHeight,
      }
      AddWindow(currentPlaytest:window(
        lg.getWidth() / 2 - currentPlaytest.windowWidth / 2,
        lg.getHeight() / 2 - currentPlaytest.windowHeight / 2))
      tweens:to(dimColor, 0.2, { [4] = 0.4 })
    end
  end
  local last = windows:last()
  if last and last.content.keypressed and not last.modalChild then
    last.content:keypressed(k)
  end
end

function love.textinput(t)
  local last = windows:last()
  if last and last.content.textinput and not last.modalChild then
    last.content:textinput(t)
  end
end

function love.update(dt)
  tweens:update(dt)
  for _, w in ipairs(windows.list) do
    if w.content.update and not w.closeAnim then
      w.content:update(dt)
    end
  end
end

function love.resize(width, height)
  for _, w in ipairs(windows.list) do
    if w.maximized then
      w:resize(width, height)
    else
      w.x = math.floor(((w.x + w.width / 2) / prevWidth) * width - w.width / 2)
      w.y = math.floor(((w.y + w.height / 2) / prevHeight) * height - w.height / 2)
    end
  end
  cameraX = (cameraX + prevWidth / 2) - width / 2
  cameraY = (cameraY + prevHeight / 2) - height / 2
  prevWidth, prevHeight = width, height
end

function love.draw()
  local mouseWorldX, mouseWorldY = screenToWorld(love.mouse.getPosition())

  lg.push()
  lg.translate(-cameraX, -cameraY)

  lg.setColor(1, 1, 1, 0.3)
  for x = math.floor(cameraX / gridSize) * gridSize, cameraX + lg.getWidth(), gridSize do
    lg.setLineWidth(x == 0 and 4 or 1)
    lg.line(x, cameraY, x, cameraY + lg.getHeight())
  end
  for y = math.floor(cameraY / gridSize) * gridSize, cameraY + lg.getHeight(), gridSize do
    lg.setLineWidth(y == 0 and 4 or 1)
    lg.line(cameraX, y, cameraX + lg.getWidth(), y)
  end

  lg.setColor(0.4, 0.6, 0.9, 1)
  lg.setLineWidth(3)
  lg.rectangle("line", 0, 0, gameWindowWidth, gameWindowHeight)

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
    lg.rectangle("line", selectedObject.x - 4, selectedObject.y - 4, selectedObject.width + 8,
      selectedObject.height + 8)
  end

  if drawingObject and drawingObjectX then
    lg.setColor(1, 1, 1)
    lg.setLineWidth(1)
    lg.rectangle("line", drawingObjectX, drawingObjectY, mouseWorldX - drawingObjectX,
      mouseWorldY - drawingObjectY)
  end

  lg.pop()

  lg.setColor(dimColor)
  lg.rectangle("fill", 0, 0, lg.getDimensions())

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
