-- an unordered set
local unorderedSet = {}
unorderedSet.__index = unorderedSet

function unorderedSet.new()
  local self = setmetatable({}, unorderedSet)
  self.lookup = {}
  self.list = {}
  self.count = 0
  return self
end

function unorderedSet:add(item)
  assert(not self.lookup[item], "added item is already inside the set")

  table.insert(self.list, item)
  self.count = self.count + 1
  self.lookup[item] = self.count
end

function unorderedSet:remove(item)
  assert(self.lookup[item], "item is not in the set")

  local index = self.lookup[item]
  if index ~= self.count then
    self.list[index], self.list[self.count] = self.list[self.count], self.list[index]
    self.lookup[self.list[index]] = index
  end
  self.lookup[item] = nil
  table.remove(self.list)
  self.count = self.count - 1
end

function unorderedSet:has(item)
  return not not self.lookup[item]
end

return unorderedSet
