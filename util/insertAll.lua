return function (t, elements)
  for _, v in ipairs(elements) do
    table.insert(t, v)
  end
end