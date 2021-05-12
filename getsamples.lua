#!/usr/bin/env lua

if #arg < 1 then
  print "Usage: lua getsamples.lua <rom>"
  os.exit(1)
end

require "constants"
local f = io.open(arg[1], "rb")
setContext(f)
seekRes(f, "INST")

local make_bin = function (id, buf, rate)
  local f = io.open(("%02i.bin"):format(id), "wb")
  f:write(("<I2"):pack(rate))
  f:write(buf)
  f:close()
end

local make_wav = function (id, buf, rate)
  local f = io.open(("%02i.wav"):format(id), "wb")
  f:write(
    "RIFF",
    ("<I4"):pack(#buf + 0x24),
    "WAVEfmt ",
    ("<I4"):pack(0x10),
    ("<I2"):pack(0x01),
    ("<I2"):pack(0x01),
    ("<I4"):pack(rate),
    ("<I4"):pack(rate),
    ("<I2"):pack(0x01),
    ("<I2"):pack(0x08),
    "data",
    ("<I4"):pack(#buf)
  )
  for i = 1, #buf do
    f:write(string.char(buf:byte(i) ~ 0x80))
  end
  f:close()
end

for i = 0, 0xFF do
  local size = ("<I4"):unpack(f:read(4))
  if size == 0 then break end
  if i == 0 then
    print(('%06X'):format(f:seek() - 4))
  end
  print(('%02X\t%03i.bin'):format(i, i))
  local rate = ("<I2"):unpack(f:read(2))
  local buf = f:read(size - 6)
  make_bin(i, buf, rate)
  --make_wav(i, buf, rate)
end

f:close()
