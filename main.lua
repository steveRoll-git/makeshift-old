function TODO(msg)
  error("todo: " .. msg, 1)
end

local imageEditor = require "imageEditor"
local images = require "images"

local test = imageEditor.new(love.graphics.getWidth(), love.graphics.getHeight(), 200, 400)

love.graphics.setBackgroundColor(0.5, 0.5, 0.5)

function love.mousemoved(x, y, dx, dy)
  test:mousemoved(x, y, dx, dy)
end

function love.mousepressed(x, y, b)
  test:mousepressed(x, y, b)
end

function love.mousereleased(x, y, b)
  test:mousereleased(x, y, b)
end

function love.wheelmoved(x, y)
  test:wheelmoved(x, y)
end

function love.keypressed(k)
  test:keypressed(k)
end

function love.draw()
  test:draw()
end

