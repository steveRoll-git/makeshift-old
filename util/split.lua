return function(str, sep)
  local gmatch = str:gmatch(("([^%s]*)(%s?)"):format(sep, sep))
  return function()
    local result = gmatch()
    return result
  end
end
