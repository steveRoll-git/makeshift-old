local window = require "ui.window"
local love = love
local lg = love.graphics

local playtest = {}
playtest.__index = playtest

function playtest.new(game)
  local self = setmetatable({}, playtest)
  self:init(game)
  return self
end

function playtest:init(game)
  self.objects = {}
  for _, obj in ipairs(game.objects) do
    table.insert(self.objects, {
      x = obj.x,
      y = obj.y,
      width = obj.width,
      height = obj.height,
      image = obj.image,
      events = obj.events
    })
  end
  self.cameraX = 0
  self.cameraY = 0
  self.windowWidth = game.windowWidth
  self.windowHeight = game.windowHeight
  self.backgroundColor = game.backgroundColor
end

function playtest:mousepressed(x, y, b)

end

function playtest:mousereleased(x, y, b)

end

function playtest:mousemoved(x, y, dx, dy)

end

function playtest:keypressed(key)

end

function playtest:update(dt)
  for _, obj in ipairs(self.objects) do
    local f = obj.events["update"]
    if f then
      f(obj)
    end
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
end

function playtest:window(x, y)
  local w = window.new(self, "Playtest", self.windowWidth, self.windowHeight + window.titleBarHeight, x, y)
  w.buttons = window.onlyCloseButton
  return w
end

return playtest
