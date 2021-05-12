local t = {
  A = {
    TRACKS = 38,
    INSTRUMENTS = 56,
    TABLE_ADDR = 0x76C24,
    BASE_ADDR = 0x10FA20,
    INDEX = {MUSIC = 27, INST = 25, SFX = 26, WAVE = 22, NOISE_PERC = 23, NOISE_SFX = 24},
  },
  R = {
    TRACKS = 43,
    INSTRUMENTS = 64,
    TABLE_ADDR = 0x121FB4,
    BASE_ADDR = 0x121FB4,
    INDEX = {MUSIC = 9, INST = 7, SFX = 8, WAVE = 4, NOISE_PERC = 5, NOISE_SFX = 6},
  },
  D = {
    TRACKS = 47,
    INSTRUMENTS = 64,
    TABLE_ADDR = 0x1196B8,
    BASE_ADDR = 0x1196B8,
    INDEX = {MUSIC = 9, INST = 7, SFX = 8, WAVE = 4, NOISE_PERC = 5, NOISE_SFX = 6},
  },
  J = {
    TRACKS = 52,
    INSTRUMENTS = 98,
    TABLE_ADDR = 0x1D6DE4,
    BASE_ADDR = 0x1D6DE4,
    INDEX = {MUSIC = 90, INST = 88, SFX = 89, WAVE = 85, NOISE_PERC = 86, NOISE_SFX = 87},
  },
}

local ident = {
  ["SRWA\0\0\0\0\0\0\0\0ASRJ"] = "A",
  ["SRWR\0\0\0\0\0\0\0\0AJ9J"] = "R",
  ["SRWD\0\0\0\0\0\0\0\0A6SJ"] = "D",
  ["SRWJ\0\0\0\0\0\0\0\0B6JJ"] = "J",
}

local res = {}

setContext = function (f)
  f:seek("set", 0xA0)
  res[f] = t[ident[f:read(16)]]
  return assert(res[f])
end

seekRes = function (f, str)
  f:seek("set", res[f].TABLE_ADDR + 4 * res[f].INDEX[str])
  f:seek("set", res[f].BASE_ADDR + ("<I4"):unpack(f:read(4)))
end

updateRes = function (f, str, pos)
  f:seek("set", res[f].TABLE_ADDR + 4 * res[f].INDEX[str])
  f:write(("<I4"):pack(pos - res[f].BASE_ADDR))
end
