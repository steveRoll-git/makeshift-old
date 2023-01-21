local lookupify = require "util.lookupify"

local keywords = lookupify {
  "if", "else", "elseif", "on", "true", "false", "var", "this"
}

local groupPunctuation = lookupify {
  "==", "!=", ">=", "<=", "+=", "-=", "*=", "/=", "&&", "||", ".."
}

local lexer = {}
lexer.__index = lexer

function lexer.new(code, sourceName)
  local self = setmetatable({}, lexer)
  self:init(code, sourceName)
  return self
end

function lexer:init(code, sourceName)
  self.code = code
  self.sourceName = sourceName
  self.index = 1
  self.column = 1
  self.line = 1
  self.prevColumn = 1
  self.prevLine = 1
  self.reachedEnd = #code == 0
end

function lexer:lookAhead(length)
  return self.code:sub(self.index, self.index + length - 1)
end

function lexer:curChar()
  return self.code:sub(self.index, self.index)
end

function lexer:advanceChar(times)
  if self.reachedEnd then
    return
  end

  times = times or 1
  for i = 1, times do
    self.index = self.index + 1
    if self.index > #self.code then
      self.reachedEnd = true
      return
    end
    local c = self:curChar()
    if c == "\n" then
      self.lastLineEnd = self.column
      self.column = 0
      self.line = self.line + 1
    else
      self.column = self.column + 1
    end
  end
end

function lexer:nextToken()
  -- skip past spaces and newlines
  while not self.reachedEnd and self:curChar():find("%s") do
    self:advanceChar()
  end

  self.prevColumn = self.column
  self.prevLine = self.line

  if self.reachedEnd then
    return {
      kind = "EOF"
    }
  end

  if self:lookAhead(2) == "//" then
    self:advanceChar(2)
    local start = self.index
    while self:curChar() ~= "\n" do
      self:advanceChar()
    end
    self:advanceChar()
    return {
      kind = "singleComment",
      value = self.code:sub(start, self.index - 2),
      line = self.prevLine,
      column = self.prevColumn,
    }
  end

  if self:curChar() == '"' then
    local start = self.index + 1
    self:advanceChar()
    while self:curChar() ~= '"' do
      self:advanceChar()
      if self:curChar() == "\n" or self.reachedEnd then
        self:syntaxError("unfinished string")
      end
    end
    self:advanceChar()
    return {
      kind = "string",
      value = self.code:sub(start, self.index - 2),
      line = self.prevLine,
      column = self.prevColumn,
    }
  end

  if self:curChar():find("[%a_]") then
    local start = self.index
    while self:curChar():find("[%w_]") do
      self:advanceChar()
    end
    local value = self.code:sub(start, self.index - 1)
    return {
      kind = keywords[value] and "keyword" or "identifier",
      value = value,
      line = self.prevLine,
      column = self.prevColumn,
    }
  end

  if self:curChar():find("%d") then
    local start = self.index
    while self:curChar():find("[%d%.]") do
      self:advanceChar()
    end
    return {
      kind = "number",
      value = self.code:sub(start, self.index - 1),
      line = self.prevLine,
      column = self.prevColumn,
    }
  end

  if self:curChar():find("%p") then
    local start = self.index
    while groupPunctuation[self.code:sub(start, self.index + 1)] do
      self:advanceChar()
    end
    self:advanceChar()
    return {
      kind = "punctuation",
      value = self.code:sub(start, self.index - 1),
      line = self.prevLine,
      column = self.prevColumn,
    }
  end
end

function lexer:syntaxError(message)
  local toLine, toColumn = self.line, self.column
  if toLine ~= self.prevLine then
    toLine = self.prevLine
    toColumn = self.lastLineEnd
  end
  error {
    fromLine = self.prevLine,
    fromColumn = self.prevColumn,
    toLine = toLine,
    toColumn = toColumn,
    message = message
  }
end

return lexer
