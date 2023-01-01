local love = love
local lg = love.graphics

local shallowCopy = require "util.shallowCopy"
local dist = require "util.dist"
local clamp = require "util.clamp"
local compareColors = require "util.compareColors"
local posHash = require "util.posHash"
local sign = require "util.sign"
local normalize = require "util.normalize"
local colorPicker = require "windows.colorPicker"
local window      = require "ui.window"

local defaultPalette = {
  {1,1,1,1},
  {0,0,0,1},
  {1,0,0,1},
  {0,1,0,1},
  {0,0,1,1},
  {1,1,0,1},
  {0,1,1,1},
  {1,0,1,1},
}

local transparentColor = {0,0,0,0}

local images = require "images"

local transparency = images["transparency.png"]
transparency:setWrap("repeat")

local fillOffsets = {
  {1, 0},
  {-1, 0},
  {0, 1},
  {0, -1},
}

local sideFont = lg.newFont(FontName, 12)

-- TODO:
-- remove palette colors with right-click menu
local imageEditor = {}
imageEditor.__index = imageEditor

function imageEditor.new(imageWidth, imageHeight)
  local self = setmetatable({}, imageEditor)

  self.paletteColors = shallowCopy(defaultPalette)
  self.selectedColor = 1

  self.paletteSquareSize = 26
  self.palettePanelWidth = self.paletteSquareSize * 4
  self.paletteColumns = math.floor(self.palettePanelWidth / self.paletteSquareSize)

  local imageData = type(imageWidth) == "number" and love.image.newImageData(imageWidth, imageHeight) or imageWidth

  self.imageData = imageData
  self.undoData = imageData:clone()
  self.drawableImage = lg.newImage(imageData)
  self.drawableImage:setFilter("nearest")

  self.clean = type(imageWidth) == "number"

  self.zoom = 1
  self.wheelFactor = 0.1

  self.mouseX = 0
  self.mouseY = 0

  self.transparencyQuad = lg.newQuad(0, 0, 0, 0, 0, 0)
  self:updateTransparencyQuad()

  self.toolbarWidth = 48
  self.tools = {
    {
      name = "Pencil",
      icon = images["tools/pencil.png"],
      onDrag = function(tool, x, y, prevX, prevY)
        self:paintCircle(x, y, prevX, prevY, self.paletteColors[self.selectedColor])
      end
    },
    {
      name = "Fill",
      icon = images["tools/fill.png"],
      onClick = function(tool, x, y)
        if not self:inRange(x, y) then return end

        local ir, ig, ib, ia = self.imageData:getPixel(x, y)
        if compareColors(ir, ig, ib, ia, unpack(self.paletteColors[self.selectedColor])) then
          return
        end

        if self.clean then
          self.imageData:mapPixel(function() return unpack(self.paletteColors[self.selectedColor]) end)
          return
        end

        self.clean = false
        local queue = {[posHash(x, y)] = true}
        while next(queue) do
          local pos = next(queue)
          queue[next(queue)] = nil
          local x, y = pos:match("(%d+),(%d+)")
          x, y = tonumber(x), tonumber(y)
          self.imageData:setPixel(x, y, self.paletteColors[self.selectedColor])
          for _, dir in ipairs(fillOffsets) do
            local x1, y1 = x + dir[1], y + dir[2]
            if self:inRange(x1, y1) then
              local r, g, b, a = self.imageData:getPixel(x1, y1)
              if compareColors(ir, ig, ib, ia, self.imageData:getPixel(x1, y1)) and not compareColors(r,g,b,a, unpack(self.paletteColors[self.selectedColor])) then
                queue[posHash(x1, y1)] = true
              end
            end
          end
        end
      end
    },
    {
      name = "Erase",
      icon = images["tools/erase.png"],
      onDrag = function(tool, x, y, prevX, prevY)
        self:paintCircle(x, y, prevX, prevY, transparentColor)
      end
    }
  }
  self.currentTool = self.tools[1]
  self.toolSize = 3

  self.panning = false
  self.painting = false

  return self
end

function imageEditor:inRange(x, y)
  return x >= 0 and x < self.imageData:getWidth() and y >= 0 and y < self.imageData:getHeight()
end

function imageEditor:updateTransparencyQuad()
  self.transparencyQuad:setViewport(0, 0, self.imageData:getWidth() * self.zoom, self.imageData:getHeight() * self.zoom, transparency:getDimensions())
end

function imageEditor:updateImage()
  self.drawableImage:replacePixels(self.imageData)
end

function imageEditor:screenToImage(x, y)
  return math.floor((x - self.transX) / self.zoom), math.floor((y - self.transY) / self.zoom)
end

function imageEditor:paintCircle(toX, toY, fromX, fromY, color)
  local size = self.toolSize
  
  local currentX, currentY = fromX, fromY
  
  local dirX, dirY = toX - fromX, toY - fromY
  local step = math.abs(dirX) > math.abs(dirY) and math.abs(dirX) or math.abs(dirY)
  local nextX, nextY = currentX, currentY

  local count = 0
  
  repeat
    currentX = nextX
    currentY = nextY
    local x = currentX + 0.5
    local y = currentY + 0.5
    local x1, y1 = x - size / 2, y - size / 2
    local x2, y2 = x + size / 2 - 1, y + size / 2 - 1
    for ix = x1, x2 do
      for iy = y1, y2 do
        if dist(ix, iy, x, y) <= math.ceil(size / 2 + (size < 4 and 1 or 0)) and self:inRange(ix, iy) then
          self.imageData:setPixel(ix, iy, color)
        end
      end
    end
    nextX, nextY = currentX + dirX / step, currentY + dirY / step
    count = count + 1
  until dist(currentX, currentY, toX, toY) <= 0.5

  self.clean = false
end

function imageEditor:mouseOnPaletteResize(x)
  return x >= self.palettePanelWidth and x <= self.palettePanelWidth + 5
end

function imageEditor:mousemoved(x, y, dx, dy)
  if self.panning then
    self.transX = self.transX + dx
    self.transX = clamp(self.transX, -self.imageData:getWidth() * self.zoom, self.windowWidth)
    self.transY = self.transY + dy
    self.transY = clamp(self.transY, -self.imageData:getHeight() * self.zoom, self.windowHeight)
  elseif self.painting and self.currentTool.onDrag then
    local ix, iy = self:screenToImage(x, y)
    local pix, piy = self:screenToImage(self.mouseX, self.mouseY)
    self.currentTool:onDrag(ix, iy, pix, piy)
    self:updateImage()
  elseif self.resizingPalette then
    self.palettePanelWidth = clamp(x, self.paletteSquareSize, self.windowWidth / 2)
    self.paletteColumns = math.floor(self.palettePanelWidth / self.paletteSquareSize)
  else
    if self:mouseOnPaletteResize(x) then
      love.mouse.setCursor(love.mouse.getSystemCursor("sizewe"))
    else
      love.mouse.setCursor()
    end
  end

  self.mouseX, self.mouseY = x, y
end

function imageEditor:mousepressed(x, y, b)
  if b == 1 and x < self.palettePanelWidth then
    local index = math.floor(y / self.paletteSquareSize) * self.paletteColumns + math.floor(x / self.paletteSquareSize) + 1
    if index == #self.paletteColors + 1 then
      local picker = colorPicker.new(self.paletteColors[self.selectedColor], function(color)
        table.insert(self.paletteColors, color)
        self.selectedColor = #self.paletteColors
      end)
      AddWindow(picker:window(self.window.x + 50, self.window.y + 50))
    elseif index >= 1 and index <= #self.paletteColors then
      self.selectedColor = index
    end
  elseif b == 1 and x >= self.windowWidth - self.toolbarWidth then
    local index = math.floor(y / self.toolbarWidth) + 1
    if index >= 1 and index <= #self.tools then
      self.currentTool = self.tools[index]
    end
  elseif b == 1 and self:mouseOnPaletteResize(x) then
    self.resizingPalette = true
  elseif b == 1 then
    self.painting = true
    self.undoData:paste(self.imageData, 0, 0, 0, 0, self.imageData:getDimensions())
    self.undoData, self.imageData = self.imageData, self.undoData
    local ix, iy = self:screenToImage(x, y)
    if self.currentTool.onClick then
      self.currentTool:onClick(ix, iy)
    elseif self.currentTool.onDrag then
      self.currentTool:onDrag(ix, iy, ix, iy)
    end
    self:updateImage()
  elseif b == 3 then
    self.panning = true
  end
end

function imageEditor:mousereleased(x, y, b)
  if b == 3 then
    self.panning = false
  end
  if b == 1 then
    self.painting = false
    self.resizingPalette = false
  end
end

function imageEditor:wheelmoved(x, y)
  if self.mouseX >= self.windowWidth - self.toolbarWidth and self.mouseY >= self.toolbarWidth * #self.tools then
    self.toolSize = self.toolSize + y
    self.toolSize = clamp(self.toolSize, 1, 100)
  else
    -- zoom
    local placeX = (self.mouseX - self.transX) / (self.imageData:getWidth() * self.zoom)
    local placeY = (self.mouseY - self.transY) / (self.imageData:getHeight() * self.zoom)

    self.zoom = self.zoom / (1 - y * self.wheelFactor)
    self.zoom = clamp(self.zoom, 0.25, 8)
    if math.abs(self.zoom - 1) <= 0.05 then
      self.zoom = 1
    end

    self.transX = -(self.imageData:getWidth() * self.zoom * placeX) + self.mouseX
    self.transY = -(self.imageData:getHeight() * self.zoom * placeY) + self.mouseY

    self:updateTransparencyQuad()
  end
end

function imageEditor:keypressed(k)
  if love.keyboard.isDown("lctrl", "rctrl") and k == "z" then
    self.undoData, self.imageData = self.imageData, self.undoData
    self:updateImage()
  end
end

function imageEditor:resize(w, h, prevW, prevH)
  if not self.transX then
    self.transX = w / 2 - self.imageData:getWidth() / 2
    self.transY = h / 2 - self.imageData:getHeight() / 2
  else
    self.transX = self.transX - (prevW - w) / 2
    self.transY = self.transY - (prevH - h) / 2
  end
end

function imageEditor:draw()
  lg.push()
  lg.translate(math.floor(self.transX), math.floor(self.transY))
  lg.setColor(1,1,1)
  lg.draw(transparency, self.transparencyQuad)
  lg.scale(self.zoom)
  lg.setColor(1,1,1)
  lg.draw(self.drawableImage)
  lg.pop()

  lg.setColor(0,0,0, 0.8)
  lg.rectangle("fill", 0, 0, self.palettePanelWidth, self.windowHeight)

  -- palette
  local x, y = 0, 0
  for i, color in ipairs(self.paletteColors) do
    lg.setColor(0, 0, 0)
    lg.rectangle("fill", x, y, self.paletteSquareSize, self.paletteSquareSize)
    lg.setColor(1,1,1)
    lg.draw(transparency, x + 2, y + 2)
    lg.setColor(color)
    lg.rectangle("fill", x + 2, y + 2, self.paletteSquareSize - 4, self.paletteSquareSize - 4)

    x = x + self.paletteSquareSize
    if x + self.paletteSquareSize > self.palettePanelWidth then
      x = 0
      y = y + self.paletteSquareSize
    end
  end

  -- toolbar
  lg.setColor(0,0,0, 0.8)
  lg.rectangle("fill", self.windowWidth - self.toolbarWidth, 0, self.toolbarWidth, self.windowHeight)
  for i, tool in ipairs(self.tools) do
    local x, y = self.windowWidth - self.toolbarWidth, (i - 1) * self.toolbarWidth
    lg.setColor(1,1,1)
    if tool == self.currentTool then
      lg.setLineWidth(2)
      lg.rectangle("line", x, y, self.toolbarWidth, self.toolbarWidth, 8, 8)
    end
    lg.draw(tool.icon, x, y)
  end
  lg.setColor(1,1,1)
  lg.setFont(sideFont)
  lg.printf(("Size:\n%d"):format(self.toolSize), self.windowWidth - self.toolbarWidth, self.toolbarWidth * #self.tools, self.toolbarWidth, "center")
  lg.printf(("Zoom:\n%d%%"):format(math.floor(self.zoom * 100)), self.windowWidth - self.toolbarWidth, self.windowHeight - sideFont:getHeight() * 2, self.toolbarWidth, "center")

  do
    -- selected color crosshair
    lg.setColor(1,1,1)
    lg.setLineWidth(2)
    local x = ((self.selectedColor - 1) % self.paletteColumns) * self.paletteSquareSize
    local y = math.floor((self.selectedColor - 1) / self.paletteColumns) * self.paletteSquareSize
    local x2, y2 = x + self.paletteSquareSize, y + self.paletteSquareSize
    lg.line(x, y + 7, x, y, x + 7, y)
    lg.line(x2 - 7, y, x2, y, x2, y + 7)
    lg.line(x, y2 - 7, x, y2, x + 7, y2)
    lg.line(x2 - 7, y2, x2, y2, x2, y2 - 7)
  end

  -- "new color" plus symbol
  lg.setColor(1,1,1)
  lg.setLineWidth(2)
  lg.line(x + self.paletteSquareSize / 2, y + 4, x + self.paletteSquareSize / 2, y + self.paletteSquareSize - 4) 
  lg.line(x + 4, y + self.paletteSquareSize / 2, x + self.paletteSquareSize - 4, y + self.paletteSquareSize / 2) 

  --lg.setColor(1,1,1)
  --lg.print(self.zoom, self.palettePanelWidth, 0)
end

function imageEditor:window(x, y)
  local new = window.new(self, "Image Editor", 400, 300, x, y)
  new.buttons = window.allButtons
  return new
end

return imageEditor

