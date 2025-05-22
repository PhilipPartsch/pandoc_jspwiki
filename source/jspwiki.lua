local lpeg = require("lpeg")
local P, R, S, V, C, Ct, Cmt, Cg, Cb = lpeg.P, lpeg.R, lpeg.S, lpeg.V, lpeg.C, lpeg.Ct, lpeg.Cmt, lpeg.Cg, lpeg.Cb

local pandoc = require("pandoc")
local List = require("pandoc.List")

-- Utility patterns
local newline = P("\r")^-1 * P("\n")
local space = S(" \t")^0
local non_newline = (1 - newline)
local blankline = space * newline

-- Inline patterns
local function make_inline_parser()
  local any = P(1)
  local str = (1 - S("'\n_"))^1

  local bold = P("__") * C((1 - P("__"))^1) * P("__") / function(s)
    return pandoc.Strong{pandoc.Str(s)}
  end

  local italic = P("''") * C((1 - P("''"))^1) * P("''") / function(s)
    return pandoc.Emph{pandoc.Str(s)}
  end

  local word = C((1 - S(" \t\n"))^1) / function(s)
    return pandoc.Str(s)
  end

  local space = P(" ") / function() return pandoc.Space() end

  local inline = Ct((bold + italic + word + space)^1)
  return inline
end

local inline = make_inline_parser()

-- Block parsing

local function parse_blocks(text)
  local blocks = List{}
  local lines = {}

  for line in text:gmatch("([^\r\n]*)\r?\n?") do
    table.insert(lines, line)
  end

  local i = 1
  while i <= #lines do
    local line = lines[i]

    -- Headings
    if line:match("^!!!") then
      local content = line:match("^!!!%s*(.+)")
      blocks:insert(pandoc.Header(1, inline:match(content)))
    elseif line:match("^!!") then
      local content = line:match("^!!%s*(.+)")
      blocks:insert(pandoc.Header(2, inline:match(content)))
    elseif line:match("^!") then
      local content = line:match("^!%s*(.+)")
      blocks:insert(pandoc.Header(3, inline:match(content)))

    -- Unordered List
    elseif line:match("^%*") then
      local items = {}
      while i <= #lines and lines[i]:match("^%*") do
        local content = lines[i]:match("^%*+%s*(.+)")
        table.insert(items, { pandoc.Plain(inline:match(content)) })
        i = i + 1
      end
      blocks:insert(pandoc.BulletList(items))
      goto continue

    -- Ordered List
    elseif line:match("^#") then
      local items = {}
      while i <= #lines and lines[i]:match("^#") do
        local content = lines[i]:match("^#+%s*(.+)")
        table.insert(items, { pandoc.Plain(inline:match(content)) })
        i = i + 1
      end
      blocks:insert(pandoc.OrderedList(items))
      goto continue

    -- Paragraph
    elseif line:match("%S") then
      local para = line
      -- Merge following lines until blank
      while i + 1 <= #lines and lines[i + 1]:match("%S") do
        i = i + 1
        para = para .. " " .. lines[i]
      end
      blocks:insert(pandoc.Para(inline:match(para)))
    end

    ::continue::
    i = i + 1
  end

  return blocks
end

function Reader(input, reader_opts)
  local text = input
  local blocks = parse_blocks(text)
  return pandoc.Pandoc(blocks)
end
