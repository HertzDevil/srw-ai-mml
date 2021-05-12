#!/usr/bin/env lua

if #arg < 1 then
  print "Usage: lua getsongs.lua <rom>"
  os.exit(1)
end

-- definitions

local thisch = 1

local ARGFUNC = {
  uint8 = function (f) return (("I1"):unpack(f:read(1))) end,
  int8 = function (f) return (("i1"):unpack(f:read(1))) end,
  uint16 = function (f) return (("I2"):unpack(f:read(2))) end,
  int16 = function (f) return (("I2"):unpack(f:read(2))) end,
}

local COMMAND = {}
local defcommand = function (ch, name, arglist, func)
  if not arglist then arglist = {} end
  if not func then func = function (...) return ... end end
  COMMAND[ch] = function (f)
    local a = {}
    for _, v in ipairs(arglist) do
      table.insert(a, ARGFUNC[v](f))
    end
    return " " .. name .. table.concat({func(table.unpack(a))}, ",")
  end
end

for _, v in ipairs {
  { "S+", 0x0F}, { "S-", 0x1E}, {  ")", 0x5F}, { "(", 0x6E}, { ">", 0x6F}, {"<", 0x7E},
  {  "L", 0xBF}, { "EX", 0xD3}, {  "[", 0xD6}, {"PX", 0xE0},
  {"@@X", 0xE1}, {"EPX", 0xE3}, {"@~X", 0xEB}, {"H>", 0xEE}, {"H<", 0xEF},
} do
  COMMAND[v[2]] = function (f) return " " .. v[1] end
end

for _, v in ipairs { -- no space
  {".", 0xD1}, {"~", 0xD4}
} do
  COMMAND[v[2]] = function (f) return v[1] end
end

for _, v in ipairs {
  {"SD", 0x0E}, {"SR", 0x1F}, {"@", 0x2F}, {"O", 0x4F}, {"V", 0x5E},
  { "T", 0x7F}, { "]", 0xD7}, {"@", 0xDB}, {"@", 0xDC}, {"@", 0xDD}, {"B", 0xE5},
} do
  defcommand(v[2], v[1], {"uint8"})
end

for _, v in ipairs {
  {"D", 0xD5}, {"H", 0xE4}, {"_", 0xE9}, {"_V", 0xF1},
} do
  defcommand(v[2], v[1], {"int8"})
end

for _, v in ipairs {
  { "E", 0xD2, {"uint8", "uint8", "uint8", "uint8", "uint8"}},
  { "P", 0xDF, {"uint8", "uint8", "uint8"}},
  {"EP", 0xE2, {"int8", "int8", "int8", "uint8", "uint8"}},
  { "W", 0xE7, {"uint8", "uint8", "uint8"}},
} do
  defcommand(v[2], v[1], v[3])
end

do
  local PANFLAG_L = {0x10, 0x20, 0x40, 0x80, 0x02, 0x20}
  local PANFLAG_R = {0x01, 0x02, 0x04, 0x08, 0x01, 0x10}
  defcommand(0xD0,  "Y", {"uint8", "uint8"}, function (_, x)
    -- assert(_ == 0xFF & ~PANFLAG_L[thisch] & ~PANFLAG_R[thisch])
    return (x & PANFLAG_L[thisch] ~= 0 and "L" or ".") ..
           (x & PANFLAG_R[thisch] ~= 0 and "R" or ".")
  end)
end
defcommand(0xDA,  "@", {"int8"}, function (a) return a >= 0 and "A" .. a or "B" .. (a + 0x80) end)
defcommand(0xDE, "@@", {"uint8", "uint8", "uint8"}, function (a, b, c) return a - 1, b, c end)
defcommand(0xEA, "@~", {"uint8"}, function (a) return a - 1 end)

do
  local NOTE = {[0] = "c", "c+", "d", "d+", "e", "f", "f+", "g", "g+", "a", "a+", "b", "x", "r"}
  local DURATION = {[0] = 1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64, 128}
  for i = 0, 0xC do
    local f = function () return DURATION[i] end
    for j = 0, 0xD do defcommand(i * 0x10 + j, NOTE[j], {}, f) end
  end
end

defcommand(0xFF, "\n") -- end of channel

for _, v in ipairs {
  {0x2E, 1}, {0x3E, 1}, {0x9F, 1}, {0xAE, 1}, {0xEC, 1},
  {0x3F, 0}, {0x4E, 0}, {0x8E, 1}, {0x8F, 1}, {0x9E, 1}, {0xAF, 1}, {0xBE, 1},
  {0xCE, 1}, {0xCF, 1}, {0xD8, 0}, {0xD9, 0}, {0xE6, 2}, {0xE8, 1}, {0xED, 1},
  {0xF0, 0}, {0xF2, 0}, {0xF3, 0}, {0xF4, 0}, {0xF5, 0}, {0xF6, 0}, {0xF7, 0},
  {0xF8, 0}, {0xF9, 0}, {0xFA, 0}, {0xFB, 0}, {0xFC, 0}, {0xFD, 0}, {0xFE, 0},
} do
  COMMAND[v[1]] = function (f)
    local str = " `" .. ("%02X"):format(v[1])
    for i = 1, v[2] do str = str .. ("%02X"):format(ARGFUNC.uint8(f)) end
    return str
  end
end

require "constants"
local f = io.open(arg[1], "rb")
setContext(f)
seekRes(f, "MUSIC")

local track = 0
while true do
  local beg = f:seek()
  local size = ("<I2"):unpack(f:read(2))
  if size == 0 then break end
  local ch = {}
  for i = 1, 6 do ch[i] = beg + ("<I2"):unpack(f:read(2)) end
  if track == 0 then io.stdout:write(("%06X\n"):format(beg)) end
  io.stdout:write(("%02X\t%03i.mml\n"):format(track, track))
  io.output(io.open(("%03i.mml"):format(track), "w"))
  io.write((";%03d %08X\n"):format(track, f:seek() - 14))
  
  for i, v in ipairs(ch) do
    io.write("!" .. i .. " ")
    f:seek("set", v)
    thisch = i
    while true do
      local b = ARGFUNC.uint8(f)
      io.write(COMMAND[b](f))
      if b == 0xFF then break end
    end
  end
  
  track = track + 1
  f:seek("set", beg + size)
  io.output():close()
end

f:close()
