return function(x, y)
  local len = (x^2 + y^2) ^ 0.5
  return x / len, y / len
end
