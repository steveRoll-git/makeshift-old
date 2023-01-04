return function(r1, g1, b1, a1, r2, g2, b2, a2)
  if type(r1) == "table" then
    if type(g1) == "table" then
      r2, g2, b2, a2 = unpack(g1)
    else
      r2, g2, b2, a2 = g1, b1, a1, r2
    end
    r1, g1, b1, a1 = unpack(r1)
  end
  a1 = a1 or 1
  a2 = a2 or 1
  return r1 == r2 and g1 == g2 and b1 == b2 and a1 == a2
end
