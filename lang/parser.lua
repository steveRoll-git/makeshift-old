local lexer       = require "lang.lexer"
local lookupify   = require "util.lookupify"
local inspect     = require "lib.inspect"
local articleNoun = require "util.articleNoun"

local binaryPrecedence = {
  ["*"] = 1,
  ["/"] = 1,
  ["+"] = 2,
  ["-"] = 2,
  ["<"] = 3,
  [">"] = 3,
  ["<="] = 3,
  [">="] = 3,
  ["=="] = 4,
  ["!="] = 4,
  ["&&"] = 5,
  ["||"] = 6,
  [".."] = 7,
}

local unaryOperators = lookupify {
  "!", "-"
}

local compundAssignment = lookupify {
  "+=", "-=", "*=", "/="
}

local function isBinaryOperator(token)
  return token.kind == "punctuation" and binaryPrecedence[token.value]
end

local parser = setmetatable({}, lexer)
parser.__index = parser

function parser.new(code)
  local self = setmetatable(lexer.new(code), parser)
  self:nextToken()
  return self
end

function parser:nextToken()
  self.token = lexer.nextToken(self)
end

-- if the current token is of the same `kind` (and `value` if provided) -
-- consumes it and returns it. otherwise does nothing.
function parser:accept(kind, value)
  if self.token.kind == kind then
    if not value or self.token.value == value then
      local prev = self.token
      self:nextToken()
      return prev
    end
  end
end

function parser:expect(kind, value)
  local result = self:accept(kind, value)
  if not result then
    local noun = value and value or articleNoun(kind)
    self:syntaxError(("Expected %s but got %s"):format(noun, self.token.value or articleNoun(self.token.kind)))
  end
  return result
end

-- parses the primary pieces used in an expression.
function parser:parsePrimary()
  if self.token.kind == "punctuation" and unaryOperators[self.token.value] then
    local operator = self.token
    self:nextToken()
    return {
      kind = "unaryOperator",
      operator = operator.value,
      value = self:parsePrimary(),
      line = operator.line,
      column = operator.column
    }
  end

  local number = self:accept("number")
  if number then
    return number
  end

  local string = self:accept("string")
  if string then
    return {
      kind = "stringLiteral",
      value = string.value,
      line = string.line,
      column = string.column
    }
  end

  local boolean = self:accept("keyword", "true") or self:accept("keyword", "false")
  if boolean then
    return {
      kind = "boolean",
      value = boolean.value,
      line = boolean.line,
      column = boolean.column
    }
  end

  return self:parseIndexOrCall()
end

-- parses an infix expression using the shunting yard algorithm.
function parser:parseInfixExpression()
  local output = {}
  local operatorStack = {}

  local function popOperator()
    local op = table.remove(operatorStack)
    local b = table.remove(output)
    local a = table.remove(output)
    table.insert(output, {
      kind = "binaryOperator",
      lhs = a,
      rhs = b,
      operator = op.value,
      line = op.line
    })
  end

  table.insert(output, self:parsePrimary())
  while isBinaryOperator(self.token) do
    local p = binaryPrecedence[self.token.value]
    while #operatorStack > 0 and p >= binaryPrecedence[operatorStack[#operatorStack].value] do
      popOperator()
    end
    table.insert(operatorStack, self.token)
    self:nextToken()
    table.insert(output, self:parsePrimary())
  end

  while #operatorStack > 0 do
    popOperator()
  end

  return output[1]
end

-- parses either an object index, or a function call.
-- this is because these can appear in both expressions and statements.
function parser:parseIndexOrCall(object)
  if not object then
    if self:accept("punctuation", "(") then
      object = self:parseInfixExpression()
      self:expect("punctuation", ")")
    else
      if self:accept("keyword", "this") then
        object = {
          kind = "thisValue"
        }
      else
        object = {
          kind = "identifier",
          value = self:expect("identifier").value
        }
      end
    end
  end

  local dot = self:accept("punctuation", ".")
  if dot then
    local index = self:expect("identifier")
    return self:parseIndexOrCall {
      kind = "objectIndex",
      object = object,
      index = {
        kind = "stringLiteral",
        value = index.value
      },
      line = dot.line
    }
  end

  local lSquare = self:accept("punctuation", "[")
  if lSquare then
    local index = self:parseInfixExpression()
    self:expect("punctuation", "]")
    return self:parseIndexOrCall {
      kind = "objectIndex",
      object = object,
      index = index,
      line = lSquare.line
    }
  end

  local lParen = self:accept("punctuation", "(")
  if lParen then
    local params = {}
    if self.token.kind ~= "punctuation" and self.token.value ~= ")" then
      local param = self:parseInfixExpression()
      while param do
        table.insert(params, param)
        param = self:accept("punctuation", ",") and self:parseInfixExpression()
      end
    end
    self:expect("punctuation", ")")
    return self:parseIndexOrCall {
      kind = "functionCall",
      object = object,
      params = params,
      line = lParen.line
    }
  end

  return object
end

function parser:parseStatement()
  if self:accept("keyword", "var") then
    local name = self:expect("identifier").value
    local value
    if self:accept("punctuation", "=") then
      value = self:parseInfixExpression()
    end
    return {
      kind = "localVariableDeclaration",
      name = name,
      value = value
    }
  end

  if self:accept("keyword", "if") then
    local condition = self:parseInfixExpression()
    local body = self:parseBlock()
    local elseIfs = {}
    local elseBody
    while true do
      if self:accept("keyword", "elseif") then
        local condition = self:parseInfixExpression()
        local body = self:parseBlock()
        table.insert(elseIfs, {
          condition = condition,
          body = body
        })
      elseif self:accept("keyword", "else") then
        elseBody = self:parseBlock()
        break
      else
        break
      end
    end
    return {
      kind = "ifStatement",
      condition = condition,
      body = body,
      elseIfs = elseIfs,
      elseBody = elseBody
    }
  end

  local object = self:parseIndexOrCall()
  if object.kind == "functionCall" then
    return object
  end

  local line = self.line

  local compoundOperator
  if self.token.kind == "punctuation" and compundAssignment[self.token.value] then
    compoundOperator = self.token.value
    self:nextToken()
  else
    self:expect("punctuation", "=")
  end
  local value = self:parseInfixExpression()
  return {
    kind = compoundOperator and "compoundAssignment" or "assignment",
    operator = compoundOperator,
    object = object,
    value = value,
    line = line
  }
end

function parser:parseBlock()
  self:expect("punctuation", "{")
  local statements = {}
  while not self:accept("punctuation", "}") do
    table.insert(statements, self:parseStatement())
  end
  return {
    kind = "block",
    statements = statements
  }
end

function parser:parseObjectCode()
  local events = {}
  while true do
    if self:accept("keyword", "on") then
      local event = self:expect("identifier").value
      local params = {}
      if self:accept("punctuation", "(") then
        local param = self:accept("identifier")
        while param do
          table.insert(params, param.value)
          param = self:accept("punctuation", ",") and self:expect("identifier")
        end
        self:expect("punctuation", ")")
      end
      local body = self:parseBlock()
      table.insert(events, {
        kind = "eventHandler",
        eventName = event,
        params = params,
        body = body
      })
    else
      self:syntaxError(("did not expect %s here"):format(self.token.value))
    end
    if self.reachedEnd then
      break
    end
  end
  return {
    kind = "objectCode",
    eventHandlers = events
  }
end

return parser
