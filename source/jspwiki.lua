-- jspwiki.lua
-- Pandoc Lua Reader für JSPWiki-Markup

local List = require 'pandoc.List'

-- Hilfsfunktion: Inline-Formatierung
local function parse_inline(text)
  local elems = pandoc.read(text, 'markdown').blocks[1].content
  return elems
end

-- Hauptfunktion für das Parsen
function Reader(input, reader_opts)
  local blocks = List{}
  local list_stack = {}  -- für verschachtelte Listen

  print(">>> TYPE", type(input), input.read)
  local text = input:read("*all")
  print(">>> INPUT CONTENT:\n" .. text)
  text = text:gsub("\r\n", "\n") -- Normalize line endings
  for line in text:gmatch("([^\n]*)\n?") do
    -- Trim leere Zeilen
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed == '' then
      -- Leere Zeile = Absatzende oder Blocktrennung
      if #list_stack > 0 then
        for _, list in ipairs(list_stack) do
          blocks:insert(list)
        end
        list_stack = {}
      end
    elseif trimmed:match("^!!!") then
      local content = trimmed:match("^!!!%s*(.+)$")
      blocks:insert(pandoc.Header(1, parse_inline(content)))
    elseif trimmed:match("^!!") then
      local content = trimmed:match("^!!%s*(.+)$")
      blocks:insert(pandoc.Header(2, parse_inline(content)))
    elseif trimmed:match("^!") then
      local content = trimmed:match("^!%s*(.+)$")
      blocks:insert(pandoc.Header(3, parse_inline(content)))
    elseif trimmed:match("^%*+") then
      -- Ungeordnete Liste
      local level, content = trimmed:match("^(%*+)%s*(.+)$")
      local depth = #level
      list_stack[depth] = list_stack[depth] or pandoc.BulletList({})
      table.insert(list_stack[depth], { pandoc.Plain(parse_inline(content)) })
    elseif trimmed:match("^#+") then
      -- Geordnete Liste
      local level, content = trimmed:match("^(#+)%s*(.+)$")
      local depth = #level
      list_stack[depth] = list_stack[depth] or pandoc.OrderedList({})
      table.insert(list_stack[depth], { pandoc.Plain(parse_inline(content)) })
    else
      -- Standardabsatz
      blocks:insert(pandoc.Para(parse_inline(trimmed)))
    end
  end

  -- Noch offene Listen einfügen
  for _, list in ipairs(list_stack) do
    blocks:insert(list)
  end

  return pandoc.Pandoc(blocks)
end
