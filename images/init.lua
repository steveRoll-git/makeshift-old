local love = love
local lfs = love.filesystem
local lg = love.graphics

lg.setDefaultFilter("nearest")

local imageDir = "images/"

local function shortPath(s)
  return s:sub(#imageDir+1)
end

local images = {}

local function addDirectory(path)
  for _, f in ipairs(lfs.getDirectoryItems(path)) do
    local type = lfs.getInfo(path .. f).type
    if type == "file" and (f:sub(-4) == ".png" or f:sub(-4) == ".jpg") then
      local img = lg.newImage(path .. f)
      img:setWrap("repeat")
      images[shortPath(path) .. f] = img
    elseif type == "directory" then
      addDirectory(path .. f .. "/")
    end
  end
end

addDirectory(imageDir)

return images