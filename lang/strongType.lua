local function getType(value)
  local mt = getmetatable(value)
  if mt and mt.__typeName then
    return mt.__typeName
  end
  return type(value)
end

local strongType = {}
strongType.__index = strongType

function strongType.new(name, fields)
  local self = setmetatable({}, strongType)
  self:init(name, fields)
  return self
end

function strongType:init(name, fields)
  self.name = name
  self.fields = fields
end

function strongType:instance(init)
  local actual = init or {}
  return setmetatable({}, {
    __typeName = self.name,

    __index = function(obj, key)
      if self.fields[key] then
        return actual[key]
      else
        error(("Type %s doesn't have a field named %q"):format(self.name, key), 2)
      end
    end,

    __newindex = function(obj, key, value)
      if self.fields[key] then
        if getType(value) == self.fields[key].type then
          actual[key] = value
        else
          error(("Field %q is of type %s - can't assign value of type %s to it"):format(key, self.fields[key].type, getType(value)), 2)
        end
      else
        error(("Type %s doesn't have a field named %q"):format(self.name, key), 2)
      end
    end
  })
end

return strongType
