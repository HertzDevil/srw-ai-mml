#!/usr/bin/env lua

require "constants"

local main = function (rom, fname)
  local samples = {}
  local list = io.open(fname, "r")
  assert(list, "File " .. fname .. " does not exist!")
  local f = io.open(rom, "r+b")
  assert(f, "File " .. rom .. " does not exist!")
  local adr = tonumber(list:read("*l"):match "%x+", 16)

  local RES = setContext(f)
  if not RES then error("Unknown ROM") end
  seekRes(f, "INST")

  while true do
    local sample_adr = f:seek()
--    io.stdout:write(("Sample %03d at $%08X\n"):format(#samples, sample_adr))
    local size = ("<I4"):unpack(f:read(4))
    if size == 0 then break end
    size = size - 6
    local rate = ("<I2"):unpack(f:read(2))
    samples[#samples + 1] = {
      size = size, rate = rate, data = f:read(size), source = ("ROM $%08X"):format(sample_adr)
    }
    f:seek("cur", (-size) % 2)
  end
  local sample_count = #samples

  for str in list:lines() do
    local id, sample_fname = str:match("^(%x+)[ \t]+([^;]+)")
    if sample_fname then
      id = tonumber(assert(id), 16)
      if id >= sample_count then
        sample_count = id + 1
      end
      local sample = io.open(sample_fname, "rb")
      assert(sample, "File " .. sample_fname .. " does not exist!")
      local rate = ("<I2"):unpack(sample:read(2))
      local data = sample:read("*a")
      samples[id + 1] = {
        size = data:len(), rate = rate, data = data, source = fname
      }
      sample:close()
    end
  end

  for i = 1, sample_count do
    if not samples[i] then
      samples[i] = {
        size = 64, rate = 0x07D0, data = ("\x00"):rep(64), source = "(empty)"
      }
    end
  end

  io.stdout:write("Inserting sample data...\n")
  f:seek("set", adr)
  for i, sample in ipairs(samples) do
    io.stdout:write(("Sample %03d at $%08X <- %s\n"):format(i - 1, f:seek(), sample.source))
    f:write(("<I4<I2"):pack(sample.size + 6, sample.rate))
    f:write(sample.data)
    f:write(("\x00"):rep((-sample.size) % 2))
  end
  io.stdout:write(("Sample data ends at $%08X\n"):format(f:seek()))
  updateRes(f, "INST", adr)

  f:close()
end

if #arg < 2 then
  print "Usage: lua putsamples.lua <rom> <samplelist>"
  os.exit(1)
end

main(arg[1], arg[2])
