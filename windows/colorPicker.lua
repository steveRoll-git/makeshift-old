local love = love
local lg = love.graphics

local hsvToRgb    = require "util.hsvToRgb"
local rgbToHsv    = require "util.rgbToHsv"
local dist        = require "util.dist"
local normalize   = require "util.normalize"
local clamp       = require "util.clamp"
local shallowCopy = require "util.shallowCopy"
local window      = require "ui.window"
local button      = require "ui.button"

local wheelSize = 120
local center = wheelSize / 2
local wheelImage
do
  local data = love.image.newImageData(wheelSize, wheelSize)
  data:mapPixel(function(x, y)
    local d = dist(x, y, center, center)
    if d <= wheelSize / 2 then
      local hue = math.atan2(y - center, x - center) / (math.pi * 2)
      local saturation = d / (wheelSize / 2)
      return hsvToRgb(hue, saturation, 1)
    end
    return 0, 0, 0, 0
  end)
  wheelImage = love.graphics.newImage(data)
end

local sliderWidth = 20
local sliderX, sliderY = wheelSize + 20, 0

-- TODO:
-- allow inputing RGB values and hex codes
local colorPicker = {}
colorPicker.__index = colorPicker

function colorPicker.new(selectedColor, onOk)
  local self = setmetatable({}, colorPicker)
  self:init(selectedColor, onOk)
  return self
end

function colorPicker:init(selectedColor, onOk)
  self.selectedColor = shallowCopy(selectedColor)
  self.alpha = selectedColor[4] or 1
  local h, s, v = rgbToHsv(unpack(selectedColor))
  local angle = h * math.pi * 2
  local distance = s * (wheelSize / 2)
  self.wheelX = math.cos(angle) * distance
  self.wheelY = math.sin(angle) * distance
  self.sliderY = (1 - v) * wheelSize
  self.slider = love.image.newImageData(1, wheelSize)
  self.sliderImage = love.graphics.newImage(self.slider)
  self.lightness = v
  self:dragWheel(self.wheelX + center, self.wheelY + center)

  self.okButton = button.new(0, 0, 70, 20, "OK", function()
    if onOk then
      onOk(self.selectedColor)
    end
    StartClosingWindow(self.window)
  end)
  self.cancelButton = button.new(0, 0, 70, 20, "Cancel", function()
    StartClosingWindow(self.window)
  end)

  self.buttons = { self.okButton, self.cancelButton }
end

function colorPicker:updateSliderImage()
  self.slider:mapPixel(function(x, y)
    return hsvToRgb(self.hue, self.saturation, 1 - y / self.slider:getHeight())
  end)
  self.sliderImage:replacePixels(self.slider)
end

function colorPicker:buttonLayout()
  self.okButton.x = 10
  self.okButton.y = self.windowHeight - self.okButton.h - 10

  self.cancelButton.x = self.okButton.x + self.okButton.w + 10
  self.cancelButton.y = self.okButton.y
end

function colorPicker:resize(w, h, oldW, oldH)
  self:buttonLayout()
end

function colorPicker:insideWheel(x, y)
  return x >= 0 and x < wheelSize and y >= 0 and y < wheelSize
end

function colorPicker:insideSlider(x, y)
  return x >= sliderX and x < sliderX + sliderWidth and y >= sliderY and y < sliderY + wheelSize
end

function colorPicker:dragWheel(x, y)
  self.wheelX = x - center
  self.wheelY = y - center
  if dist(self.wheelX, self.wheelY, 0, 0) > center then
    self.wheelX, self.wheelY = normalize(self.wheelX, self.wheelY)
    self.wheelX = self.wheelX * center
    self.wheelY = self.wheelY * center
  end
  self.hue = math.atan2(self.wheelY, self.wheelX) / (math.pi * 2)
  self.saturation = dist(self.wheelX, self.wheelY, 0, 0) / (wheelSize / 2)
  self:updateSliderImage()
  self:updateColor()
end

function colorPicker:dragSlider(x, y)
  self.sliderY = clamp(y - sliderY, 0, wheelSize)
  self.lightness = 1 - self.sliderY / wheelSize
  self:updateColor()
end

function colorPicker:updateColor()
  self.selectedColor = { hsvToRgb(self.hue, self.saturation, self.lightness, self.alpha) }
end

function colorPicker:mousepressed(x, y, b)
  if b == 1 then
    if self:insideWheel(x, y) then
      self.draggingWheel = true
      self:dragWheel(x, y)
      return
    elseif self:insideSlider(x, y) then
      self.draggingSlider = true
      self:dragSlider(x, y)
      return
    end
  end
  for _, btn in ipairs(self.buttons) do
    btn:mousepressed(x, y, b)
  end
end

function colorPicker:mousereleased(x, y, b)
  self.draggingWheel = false
  self.draggingSlider = false
  for _, btn in ipairs(self.buttons) do
    btn:mousereleased(x, y, b)
  end
end

function colorPicker:mousemoved(x, y, dx, dy)
  if self.draggingWheel then
    self:dragWheel(x, y)
    return
  elseif self.draggingSlider then
    self:dragSlider(x, y)
    return
  end
  for _, btn in ipairs(self.buttons) do
    btn:mousemoved(x, y, dx, dy)
  end
end

function colorPicker:draw()
  lg.setColor(1, 1, 1)
  lg.draw(wheelImage)

  lg.setColor(0, 0, 0)
  lg.setLineWidth(1)
  lg.circle("line", self.wheelX + center, self.wheelY + center, 3)
  lg.setColor(1, 1, 1)
  lg.circle("line", self.wheelX + center, self.wheelY + center, 2)

  lg.setColor(1, 1, 1)
  lg.draw(self.sliderImage, sliderX, sliderY, 0, sliderWidth, 1)
  lg.setLineWidth(1)
  lg.rectangle("line", sliderX - 3, sliderY + self.sliderY - 3, sliderWidth + 6, 6, 3)
  lg.setColor(0, 0, 0)
  lg.rectangle("line", sliderX - 2, sliderY + self.sliderY - 2, sliderWidth + 4, 4, 3)

  lg.setColor(self.selectedColor)
  lg.rectangle("fill", 0, wheelSize + 20, self.windowWidth, 20)

  for _, b in ipairs(self.buttons) do
    b:draw()
  end
end

function colorPicker:window(x, y, title)
  local new = window.new(self, title, 250, wheelSize + 100, x, y)
  new.buttons = window.onlyCloseButton
  return new
end

return colorPicker
