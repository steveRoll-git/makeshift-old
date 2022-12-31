local love = love
local lg = love.graphics

local lerp = require "util.lerp"

local titleBarHeight = 24
local titleFont = lg.newFont(FontName, titleBarHeight - 6)
local cornerSize = 7

local buttons = {
  {
    action = "close",
    draw = function()
      lg.setColor(1, 1, 1)
      lg.setLineWidth(1)
      local q = titleBarHeight / 4
      lg.line(q, q, q * 3, q * 3)
      lg.line(q * 3, q, q, q * 3)
    end
  },
  {
    action = "maximize",
    draw = function()
      lg.setColor(1, 1, 1)
      lg.setLineWidth(1)
      local q = titleBarHeight / 4
      local h = q * 1.5
      lg.rectangle("line", q, titleBarHeight / 2 - h / 2, q * 2, h)
    end
  },
}

local window = {}
window.__index = window

window.titleBarHeight = titleBarHeight
window.buttons = buttons

function window.new(content, title, width, height)
  local self = setmetatable({}, window)
  self:init(content, title, width, height)
  return self
end

function window:init(content, title, width, height)
  self.content = content
  self.title = title
  self:resize(width, height)
  self.stencilWhole = function()
    lg.rectangle("fill", 0, 0, self.width, self.height, self:cornerSize())
  end
  self.stencilTitle = function()
    lg.rectangle("fill", 0, 0, self.width, titleBarHeight)
  end
end

function window:cornerSize()
  return self.maximizeAnim and lerp(cornerSize, 0, self.maximizeAnim) or (self.maximized and 0 or cornerSize)
end

function window:inside(x, y)
  return x >= self.x and x <= self.x + self.width and y >= self.y and y <= self.y + self.height
end

function window:getTitleButtonOver(x, y)
  if y < self.y or y > self.y + titleBarHeight or x > self.x + self.width then
    return nil
  end
  for i = 1, #buttons do
    if x >= self.x + self.width - titleBarHeight * i then
      return i
    end
  end
end

function window:resize(w, h)
  self.width = w
  self.height = h
  local prevW, prevH = self.content.windowWidth, self.content.windowHeight
  self.content.windowWidth = w
  self.content.windowHeight = h - titleBarHeight
  self.content:resize(self.content.windowWidth, self.content.windowHeight, prevW, prevH)
end

function window:draw()
  local outlineColor = self.maximizeAnim and (1 - self.maximizeAnim) or (self.maximized and 0 or 1)

  if self.closeAnim then
    local amount = self.closeAnim / 8
    lg.translate(self.width / 2 * amount, self.height / 2 * amount)
    lg.scale(1 - amount)
    lg.setColor(1, 1, 1, 1 - self.closeAnim)
    lg.draw(self.canvas)
    return
  end

  lg.setColor(0.2, 0.2, 0.2, 0.98)
  lg.rectangle("fill", 0, 0, self.width, self.height, self:cornerSize())
  lg.setColor(1, 1, 1)
  lg.setLineWidth(1)
  lg.line(0, titleBarHeight, self.width, titleBarHeight)
  lg.setColor(1, 1, 1, outlineColor)
  lg.rectangle("line", 0, 0, self.width, self.height, self:cornerSize())

  lg.stencil(self.stencilWhole, "replace", 1)
  lg.setStencilTest("greater", 0)

  lg.push()
  lg.translate(self.width - titleBarHeight, 0)
  for i, btn in ipairs(buttons) do
    lg.setColor(1, 1, 1)
    lg.setLineWidth(1)
    btn.draw()
    if self.buttonDown == i then
      lg.setColor(1, 1, 1, 0.5)
      lg.rectangle("fill", 0, 0, titleBarHeight, titleBarHeight)
    elseif self.buttonOver == i then
      lg.setColor(1, 1, 1, 0.2)
      lg.rectangle("fill", 0, 0, titleBarHeight, titleBarHeight)
    end
    lg.setColor(1, 1, 1)
    lg.line(0, 0, 0, titleBarHeight)
    lg.translate(-titleBarHeight, 0)
  end
  lg.pop()

  lg.setColor(1, 1, 1)
  lg.setFont(titleFont)
  lg.print(self.title, math.floor(cornerSize / 2))

  lg.push()
  lg.stencil(self.stencilTitle, "decrement", 1, true)
  lg.translate(0, titleBarHeight)
  self.content:draw()
  lg.pop()

  if not self.maximized then
    lg.setColor(1, 1, 1, outlineColor)
    lg.setLineWidth(1)
    lg.line(self.width - cornerSize - 1, self.height, self.width, self.height - cornerSize - 1)
    lg.line(self.width - cornerSize - 6, self.height, self.width, self.height - cornerSize - 6)
  end

  lg.setStencilTest()
end

return window
