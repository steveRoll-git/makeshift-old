local orderedSet = {}
orderedSet.__index = orderedSet

function orderedSet.new(elements)
  local self = setmetatable({}, orderedSet)
  self.lookup = {}
  self.list = {}
  self.count = 0
  if elements then
    for i, e in ipairs(elements) do
      self:add(e)
    end
  end
  return self
end

function orderedSet:add(item)
  assert(not self.lookup[item], "added item is already inside the set")

  self.count = self.count + 1
  self.list[self.count] = item
  self.lookup[item] = self.count
end

function orderedSet:insertAt(index, item)
  assert(not self.lookup[item], "added item is already inside the set")
  assert(index >= 1 and index <= self.count + 1)

  for i = self.count, index, -1 do
    self.list[i + 1] = self.list[i]
    self.lookup[self.list[i + 1]] = i + 1
  end

  self.count = self.count + 1
  self.list[index] = item
  self.lookup[item] = index
end

function orderedSet:remove(item)
  assert(self.lookup[item], "item is not in the set")

  local index = self.lookup[item]
  for i = index, self.count do
    self.list[i] = self.list[i + 1]
    if i < self.count then
      self.lookup[self.list[i]] = i
    end
  end
  self.lookup[item] = nil
  self.count = self.count - 1
end

function orderedSet:last()
  return self.list[self.count]
end

return orderedSet
