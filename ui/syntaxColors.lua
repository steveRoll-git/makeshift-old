local colors = {
  identifier = { 1, 1, 1 },
  keyword = { 0.773, 0.525, 0.753 },
  constant = { 0.310, 0.757, 1.000 },
  string = { 0.808, 0.569, 0.471 },
  number = { 0.710, 0.808, 0.659 },
  comment = { 0.416, 0.600, 0.333 }
}

local data = {
  words = {
    ["end"] = colors.keyword,
    ["if"] = colors.keyword,
    ["then"] = colors.keyword,
    ["else"] = colors.keyword,
    ["elseif"] = colors.keyword,
    ["while"] = colors.keyword,
    ["for"] = colors.keyword,
    ["in"] = colors.keyword,
    ["do"] = colors.keyword,
    ["repeat"] = colors.keyword,
    ["until"] = colors.keyword,

    ["local"] = colors.keyword,
    ["function"] = colors.keyword,

    ["return"] = colors.keyword,
    ["break"] = colors.keyword,
    ["goto"] = colors.keyword,

    ["and"] = colors.keyword,
    ["or"] = colors.keyword,
    ["not"] = colors.keyword,

    ["true"] = colors.constant,
    ["false"] = colors.constant,
    ["nil"] = colors.constant,
  },
  string = colors.string,
  number = colors.number,
  comment = colors.comment,
  identifier = colors.identifier
}

return data
