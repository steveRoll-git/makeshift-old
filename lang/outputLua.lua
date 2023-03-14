local insertAll = require "util.insertAll"

local translateBinaryOperators = {
  ["!="] = "~=",
  ["&&"] = "and",
  ["||"] = "or",
}

local translateUnaryOperators = {
  ["!"] = "not",
}

local output = {}

local function translate(tree)
  return output[tree.kind](tree)
end

function output.stringLiteral(tree)
  return { { string = ("%q"):format(tree.value), line = tree.line } }
end

function output.number(tree)
  return { { string = tree.value, line = tree.line } }
end

function output.boolean(tree)
  return { { string = tree.value, line = tree.line } }
end

function output.identifier(tree)
  return { { string = tree.value, line = tree.line } }
end

function output.thisValue(tree)
  return { { string = "self" } }
end

function output.objectIndex(tree)
  local result = {}

  insertAll(result, translate(tree.object))

  local index = translate(tree.index)
  index[1].string = "[" .. index[1].string
  insertAll(result, index)
  table.insert(result, { string = "]", line = tree.line })

  return result
end

function output.functionCall(tree)
  local result = {}

  insertAll(result, translate(tree.object))
  result[#result].appendNewline = false
  table.insert(result, { string = "(", line = tree.line })
  for i, p in ipairs(tree.params) do
    insertAll(result, translate(p))
    if i < #tree.params then
      table.insert(result, { string = "," })
    end
  end
  table.insert(result, { string = ")" })

  return result
end

function output.assignment(tree)
  local result = {}

  insertAll(result, translate(tree.object))
  table.insert(result, { string = "=" })
  insertAll(result, translate(tree.value))

  return result
end

function output.compoundAssignment(tree)
  return output.assignment {
    object = tree.object,
    value = {
      kind = "binaryOperator",
      operator = tree.operator:sub(1, 1),
      lhs = tree.object,
      rhs = tree.value,
      line = tree.line,
    }
  }
end

function output.ifStatement(tree)
  local result = {}

  table.insert(result, { string = "if" })
  insertAll(result, translate(tree.condition))
  table.insert(result, { string = "then" })
  insertAll(result, translate(tree.body))

  for _, e in ipairs(tree.elseIfs) do
    table.insert(result, { string = "elseif" })
    insertAll(result, translate(e.condition))
    table.insert(result, { string = "then" })
    insertAll(result, translate(e.body))
  end

  if tree.elseBody then
    table.insert(result, { string = "else" })
    insertAll(result, translate(tree.elseBody))
  end

  table.insert(result, { string = "end" })
  return result
end

function output.whileLoop(tree)
  local result = {}

  table.insert(result, { string = "while" })
  insertAll(result, translate(tree.condition))
  table.insert(result, { string = "do" })
  insertAll(result, translate(tree.body))
  table.insert(result, { string = (" _yield('loop %d') end"):format(tree.line) })

  return result
end

function output.unaryOperator(tree)
  local result = {}
  table.insert(result, { string = translateUnaryOperators[tree.operator] or tree.operator, line = tree.line })
  insertAll(result, translate(tree.value))
  return result
end

function output.binaryOperator(tree)
  local result = {}

  local lhs = translate(tree.lhs)
  lhs[1].string = "(" .. lhs[1].string
  lhs[#lhs].string = lhs[#lhs].string .. ")"
  insertAll(result, lhs)

  table.insert(result, { string = translateBinaryOperators[tree.operator] or tree.operator, line = tree.line })

  local rhs = translate(tree.rhs)
  rhs[1].string = "(" .. rhs[1].string
  rhs[#rhs].string = rhs[#rhs].string .. ")"
  insertAll(result, rhs)

  return result
end

function output.block(tree)
  local result = {}
  for _, s in ipairs(tree.statements) do
    insertAll(result, translate(s))
  end
  return result
end

function output.eventHandler(tree)
  local result = {}
  table.insert(result, { string = ("function theObject:%s(%s)"):format(tree.eventName, table.concat(tree.params, ", ")) })
  insertAll(result, translate(tree.body))
  table.insert(result, { string = ("end") })
  return result
end

function output.objectCode(tree)
  local result = {}
  table.insert(result, { string = ("local theObject = {}") })
  for _, e in ipairs(tree.eventHandlers) do
    insertAll(result, translate(e))
  end
  table.insert(result, { string = ("return theObject") })
  return result
end

-- returns the resulting lua code, and a source map.
local function finalOutput(tree)
  local resultString = ""
  local elements = translate(tree)
  local sourceMap = {}
  local currentLine = 1

  for _, e in ipairs(elements) do
    resultString = (e.appendNewline == false and "%s%s" or "%s%s\n"):format(resultString, e.string)
    if e.line then
      sourceMap[currentLine] = e.line
    end
    if e.appendNewline ~= false then
      currentLine = currentLine + 1
    end
  end

  return resultString, sourceMap
end

return finalOutput
