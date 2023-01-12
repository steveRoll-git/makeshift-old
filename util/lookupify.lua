return function(t)
  local new = {}
  for _, k in ipairs(t) do
    new[k] = true
  end
  return new
end