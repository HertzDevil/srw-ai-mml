#!/usr/bin/env lua

local Trie = require "trie"

--- constants

local whitespace = function (str, b)
  return str:find("[^ \t\r\n]", b) or #str + 1
end

local CHANNELS = 6

local NOTE = {c = 0, d = 2, e = 4, f = 5, g = 7, a = 9, b = 11, x = 12, r = 13}
local ACCIDENTAL = {["+"] = 1, ["-"] = -1, ["="] = 0}
local DURATION = {
   [1] = 0,  [2] = 1,  [3] = 2,  [4] =  3,  [6] =  4,   [8] =  5, [12] = 6,
  [16] = 7, [24] = 8, [32] = 9, [48] = 10, [64] = 11, [128] = 12
}
local DURATION_REV = {}; for k, v in next, DURATION do DURATION_REV[v] = k end
local INSTBYTE = {0x2F, 0x2F, 0x2F, 0xDB, 0xDC, 0xDD}
local PANMASK = {0xEE, 0xDD, 0xBB, 0x77, 0xFC, 0xCF}
local PANFLAG_L = {0x10, 0x20, 0x40, 0x80, 0x02, 0x20}
local PANFLAG_R = {0x01, 0x02, 0x04, 0x08, 0x01, 0x10}

--- closure

local state = {}
local thisch = 1
local macro = {}
local margs = {}

local resetState = function ()
  for i = 1, CHANNELS do
    state[i] = {
      duration = 4,
      active = i == 1,
      key = {c = 0, d = 0, e = 0, f = 0, g = 0, a = 0, b = 0},
      muted = false,
      stream = {},
      length = {[0] = 1, 0},
      lasttick = 192,
    }
  end
  thisch = 1
  macro = {}
end

--- argument functions

local ARGFUNC = {
  uint8 = function (str, b)
    local x = str:match("^%d+", b)
    if x then b = b + #x; x = tonumber(x) end
    assert(x and x <= 255)
    return b, x
  end,
  int8 = function (str, b)
    local x = str:match("^-?%d+", b)
    if x then b = b + #x; x = tonumber(x) end
    assert(x and x >= -128 and x <= 127)
    return b, x & 0xFF
  end,
  hex = function (str, b)
    local x = str:match("^%x+", b)
    assert(x)
    return b + #x, tonumber(x, 16)
  end,
  channel = function (str, b)
    local x = str:match("^%d*", b)
    return b + #x, x
  end,
  note = function (str, b)
    local x; do
      local _b = b
      repeat
        _b = _b - 1
        x = str:sub(_b, _b)
      until not x:find "[ \t\r\n]";
    end
    local n = NOTE[x]
    if x ~= "x" and x ~= "r" then
      if str:find("^=", b) then
        b = b + 1
      else
        n = n + state[thisch].key[x]
      end
      local acc = str:match("^[+-]*", b)
      b = b + #acc
      for ch in acc:gmatch "." do
        n = n + (ch == "+" and 1 or -1)
      end
      assert(n >= 0 and n <= 11)
    end
    local len = str:match("^%d+", b)
    if len then
      b = b + #len
      len = tonumber(len)
    else
      len = state[thisch].duration
    end
    return b, DURATION[len] << 4 | n
  end,
  pan = function (str, b)
    return b + 2, str:match("^[.Ll][.Rr]", b)
  end,
  bool = function (str, b)
    return b + 1, assert(str:match("^[01]", b)) == "1" and true or false
  end,
  identifier = function (str, b)
    local x = str:match("^[%w_]+", b)
    return b + #x, x
  end,
  macro = function (str, b)
    local x = str:match("^[^\n]*", b)
    return b + #x, x
  end,
  --[[
  argmacro = function (str, b)
    local x = str:match("^[^;\n]*", b)
    b = b + #x
    if str:sub(b, b) == ";" then b = b + 1 end
    return b, x
  end,
  ]]
  key_signature = function (str, b)
    local x, n = str:match("^([+-=])([a-g]+)", b)
    b = b + #x + #n
    local t = {}
    for ch in n:gmatch "." do t[ch] = ACCIDENTAL[x] end
    return b, t
  end,
}

--- core commands

local COMMAND = Trie()

local defcommand = function (name, arglist, func)
  COMMAND:add(name, function (str, b)
    local args = {}
    for i, v in ipairs(arglist) do
      if i > 1 then
        b = whitespace(str, b) + 1
        assert(str:sub(b - 1, b - 1) == ",")
      end
      b = whitespace(str, b)
      b, args[i] = ARGFUNC[v](str, b)
    end
    return b, string.char(func(table.unpack(args)))
  end)
end

for ch in pairs(NOTE) do
  COMMAND:add(ch, function (str, b)
    local n = nil
    b = whitespace(str, b)
    b, n = ARGFUNC.note(str, b)
    if state[thisch].muted then return b, "" end
    local t = state[thisch].length
    state[thisch].lasttick = 768 / DURATION_REV[n >> 4]
    t[t[0]] = t[t[0]] + state[thisch].lasttick
    return b, string.char(n)
  end)
end
defcommand("k", {"key_signature"}, function (t)
  for _, s in ipairs(state) do if s.active then
    for k, v in pairs(t) do s.key[k] = v end
  end end
end)
defcommand("l", {"uint8"}, function (x)
  for _, v in ipairs(state) do if v.active then
    v.duration = x
  end end
end)
defcommand("m", {"bool"}, function (x)
  for _, v in ipairs(state) do if v.active then
    v.muted = x
  end end
end)

local parse = nil
COMMAND:add(";", function (str, b)
  return b + #str:match("[^\n]*", b) + 1, ""
end)
COMMAND:add("/*", function (str, b)
  b = str:find("*/", b)
  return b and b + 2 or #str + 1, ""
end)
defcommand("!", {"channel"}, function (str)
  for _, v in ipairs(state) do v.active = false end
  for ch in str:gmatch "." do state[tonumber(ch)].active = true end
end)

defcommand("$", {"identifier", "macro"}, function (id, str)
  macro[id] = str
  margs[id] = 0
end)
defcommand("$-", {"identifier"}, function (id)
  macro[id] = nil
  margs[id] = nil
end)
defcommand("$$", {"identifier"}, function (id)
  parse(assert(macro[id], "Macro not found"))
end)
--[=[
defcommand("$@", {"identifier", "uint8", "macro"}, function (id, x, str)
  assert(not macro[id], "Macro already defined")
  macro[id] = str
  margs[id] = x
end)
COMMAND:add("$$", function (str, b)
  local args = {}
  b = whitespace(str, b)
  b, args[1] = ARGFUNC.identifier(str, b)
  assert(macro[args[1]], "Macro not found")
  for i = 1, margs[args[1]] do
    b = whitespace(str, b) + 1
    assert(str:sub(b - 1, b - 1) == ",")
    b = whitespace(str, b)
    b, args[i + 1] = ARGFUNC.argmacro(str, b)
  end
  parse()
  return b, ""string.char(func(table.unpack(args)))
end)
]=]

defcommand("`", {"hex"}, function (x)
  local t = {}
  repeat
    table.insert(t, 1, x & 0xFF)
    x = x >> 8
  until x == 0;
  return table.unpack(t)
end)

--- effect commands

for _, v in ipairs {
  {"S+", 0x0F}, { "S-", 0x1E}, {  ")", 0x5F}, {  "(", 0x6E}, { ">", 0x6F}, { "<", 0x7E},
  { "L", 0xBF}, {  ".", 0xD1}, { "EX", 0xD3},
  {"PX", 0xE0}, {"@@X", 0xE1}, {"EPX", 0xE3}, {"@~X", 0xEB}, {"H>", 0xEE}, {"H<", 0xEF},
} do
  COMMAND:add(v[1], function (_, b) return b, string.char(v[2]) end)
end
COMMAND:add(".", function (_, b)
  if not state[thisch].muted then
    local t = state[thisch].length
    t[t[0]] = t[t[0]] + state[thisch].lasttick / 2
  end
  return b, not state[thisch].muted and "\xD1" or ""
end)
COMMAND:add("~", function (_, b)
  return b, not state[thisch].muted and "\xD4" or ""
end)

for _, v in ipairs {
  {"SD", 1, 0x0E}, {"SR", 1, 0x1F}, {"O", 1, 0x4F}, {"V", 1, 0x5E}, {"T", 1, 0x7F},
  { "E", 5, 0xD2}, { "P", 3, 0xDF}, {"B", 1, 0xE5}, {"W", 3, 0xE7},
} do
  local a = {}
  for i = 1, v[2] do a[i] = "uint8" end
  defcommand(v[1], a, function (...) return v[3], ... end)
end
defcommand("EP", {"int8", "int8", "int8", "uint8", "uint8"}, function (...) return 0xE2, ... end)

for _, v in ipairs {{"D", 0xD5}, {"H", 0xE4}, {"_", 0xE9}, {"_V", 0xF1}} do
  defcommand(v[1], {"int8"}, function (x) return v[2], x end)
end

defcommand("[", {}, function (x)
  local t = state[thisch].length
  t[0] = t[0] + 1; t[t[0]] = 0
  return 0xD6
end)
defcommand("]", {"uint8"}, function (x)
  local t = state[thisch].length
  t[t[0] - 1] = t[t[0] - 1] + t[t[0]] * x; t[0] = t[0] - 1
  return 0xD7, x
end)

defcommand("@A", {"uint8"}, function (x) assert(x <= 0x7F); return 0xDA, x end)
defcommand("@B", {"uint8"}, function (x) assert(x <= 0x7F); return 0xDA, x + 0x80 end)
defcommand("@~", {"uint8"}, function (x) assert(x < 0xFF); return 0xEA, x + 1 end)

defcommand("@", {"uint8"}, function (x)
  return INSTBYTE[thisch], x
end)

defcommand("@@", {"uint8", "uint8", "uint8"}, function (x, y, z)
  assert(x < 0xFF); return 0xDE, x + 1, y, z
end)

defcommand("Y", {"pan"}, function (str)
  local l, r = str:match "(.)(.)"
  l, r = l ~= "." and 1 or 0, r ~= "." and 1 or 0
  return 0xD0, PANMASK[thisch], PANFLAG_L[thisch] * l + PANFLAG_R[thisch] * r
end)

--- main loop

parse = function (str)
  local p = 1
  local lastp = p

  local throw = function (msg)
    local row, column = 1, 1
    local linebegin = 1
    local DIST = 10

    local i = 1
    for ch in str:sub(1, lastp - 1):gmatch "." do
      i = i + 1
      if ch == '\r' or ch == '\n' then
        row, column, linebegin = row + 1, 1, i
      else
        column = column + 1
      end
    end

    local line = str:sub(linebegin, lastp)
    local epos = column
    if column > DIST + 1 then
      line = "... " .. str:sub(lastp - 10, lastp)
      epos = DIST + 5
    end
    for i = 1, DIST + 1 do
      if i == DIST + 1 then line = line .. " ..."; break end
      local ch = str:sub(lastp + i, lastp + i)
      if ch == '\r' or ch == '\n' then break end
      line = line .. ch
    end

    local second = ""
    for i = 1, epos - 1 do
      second = second .. (line:byte(i) == 0x09 and '\t' or ' ')
    end
    error(("\nError: %s\nNear row %d, column %d\n%s\n%s^\n"):format(
      msg, row, column, line, second), 0)
  end

  while true do
    p = whitespace(str, p)
    if p > #str then return end
    lastp = p

    local k, f = COMMAND:lookup(str, p)
    if not k then throw "Unknown command" end
    p = p + #k
    local _p = p
    for i, v in ipairs(state) do if v.active then
      thisch = i
      local suc, com; suc, _p, com = pcall(f, str, p)
      if not suc then throw(_p) end
      table.insert(v.stream, com)
    end end
    p = _p
  end
end

local compile = function (fname)
  local f = io.open(fname, "r")
  assert(f, "File " .. fname .. " does not exist!")
  resetState()
  local suc, err = pcall(parse, f:read "*a")
  f:close()
  if not suc then io.stderr:write(err); os.exit(1) end

  local bin = ""
  local s = 0x0E
  for i, v in ipairs(state) do
    thisch = i
    v.ptr = s
    table.insert(v.stream, "\xFF")
    for i, ev in ipairs(v.stream) do if type(ev) ~= "string" then
      assert(false, "TODO: non-string commands")
    end end
    v.stream = table.concat(v.stream)
    s = s + #v.stream
    io.stdout:write(("%04X   "):format(#v.stream))
--    io.stdout:write(("%05i  "):format(v.length[1]))
  end
  local odd = s % 2 == 1
  if odd then s = s + 1 end
  assert(s <= 0xFFFF)
  io.stdout:write(("%04X\n"):format(s))
  bin = bin .. ("<I2"):pack(s)
  for _, v in ipairs(state) do bin = bin .. ("<I2"):pack(v.ptr) end
  for _, v in ipairs(state) do bin = bin .. v.stream end
  if odd then bin = bin .. "\xFF" end

  return bin
end

local main = function (rom, fname)
  local music = {}
  local list = io.open(fname, "r")
  assert(list, "File " .. fname .. " does not exist!")
  local f = io.open(rom, "r+b")
  assert(f, "File " .. rom .. " does not exist!")
  local adr = tonumber(list:read("*l"):match "%x+", 16)
  io.stdout:write "                             "
  for i = 1, CHANNELS do io.stdout:write("  CH" .. i .. "  ") end
  io.stdout:write("Total\n")

  require "constants"
  local RES = setContext(f)
  seekRes(f, "MUSIC")
  for i = 1, RES.TRACKS do
    local size = ("<I2"):unpack(f:read(2))
    if size == 0 then break end
    f:seek("cur", -2)
    music[i] = f:read(size)
  end
  local track_count = #music

  for str in list:lines() do
    local id, mml_fname = str:match("^(%x+)[ \t]+([^;]+)")
    if mml_fname then
      id = tonumber(assert(id), 16)
      if id >= track_count then
        track_count = id + 1
      end
      io.stdout:write(("Track %03d: Compiling %s..."):format(id, mml_fname))
      io.stdout:write("\n                              ")
      music[id + 1] = compile(mml_fname)
    end
  end
  list:close()

  for i = 1, track_count do if not music[i] then
    music[i] = "\x14\x00" ..
               "\x0E\x00\x0F\x00\x10\x00\x11\x00\x12\x00\x13\x00" ..
               "\xFF\xFF\xFF\xFF\xFF\xFF"
  end end

  if not RES then error("Unknown ROM") end
  print("Inserting music data...")
  f:seek("set", adr)
  f:write(table.concat(music))
  print(("Music data ends at 0x%08X"):format(f:seek()))
  updateRes(f, "MUSIC", adr)
  f:close()
end

if #arg < 2 then
  print "Usage: lua putsongs.lua <rom> <songlist>"
  os.exit(1)
end

main(arg[1], arg[2])

-- srwj song name pointers: 99598
