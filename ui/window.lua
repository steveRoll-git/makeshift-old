local love = love
local lg = love.graphics

local titleBarHeight = 24
local titleFont = lg.newFont(FontName, titleBarHeight - 6)
local cornerSize = 7

local buttons = {
  {
    draw = function()
      lg.setColor(1, 1, 1)
      lg.setLineWidth(1)
      local q = titleBarHeight / 4
      lg.line(q, q, q * 3, q * 3)
      lg.line(q * 3, q, q, q * 3)
    end
  }
}

local window = {}
window.__index = window

window.titleBarHeight = titleBarHeight

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
    lg.rectangle("fill", 0, 0, self.width, self.height, cornerSize)
  end
  self.stencilTitle = function()
    lg.rectangle("fill", 0, 0, self.width, titleBarHeight)
  end
end

function window:inside(x, y)
  return x >= self.x and x <= self.x + self.width and y >= self.y and y <= self.y + self.height
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
  lg.push()
  lg.translate(self.x, self.y)

  lg.setColor(0.2, 0.2, 0.2, 0.98)
  lg.rectangle("fill", 0, 0, self.width, self.height, cornerSize)
  lg.setColor(1, 1, 1)
  lg.setLineWidth(1)
  lg.rectangle("line", 0, 0, self.width, self.height, cornerSize)
  lg.line(0, titleBarHeight, self.width, titleBarHeight)

  lg.push()
  lg.translate(self.width - titleBarHeight, 0)
  for i, btn in ipairs(buttons) do
    lg.setColor(1,1,1)
    lg.setLineWidth(1)
    lg.line(0, 0, 0, titleBarHeight)
    btn.draw()
    lg.translate(-titleBarHeight, 0)
  end
  lg.pop()

  lg.stencil(self.stencilWhole, "replace", 1)
  lg.setStencilTest("greater", 0)

  lg.setColor(1, 1, 1)
  lg.setFont(titleFont)
  lg.print(self.title, math.floor(cornerSize / 2))

  lg.push()
  lg.stencil(self.stencilTitle, "decrement", 1, true)
  lg.translate(0, titleBarHeight)
  self.content:draw()
  lg.pop()

  lg.setColor(1,1,1)
  lg.setLineWidth(1)
  lg.line(self.width - cornerSize - 1, self.height, self.width, self.height - cornerSize - 1)
  lg.line(self.width - cornerSize - 6, self.height, self.width, self.height - cornerSize - 6)

  lg.setStencilTest()
  lg.pop()
end

return window
