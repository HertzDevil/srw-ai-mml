local mt; mt = {
  __metatable = "Trie",

  __index = {
    add = function (t, ...)
      local str, k = ...
      if type(str) ~= "string" then return false end
      if select("#", ...) == 1 then k = true end
      if k == nil then return false end
      for ch in str:gmatch "." do
        if rawequal(rawget(t, ch), nil) then rawset(t, ch, {}) end
        t = rawget(t, ch)
      end
      rawset(t, true, k)
      return true
    end,
    
    remove = function (t, str)
      local cache_k = {}
      local cache_t = setmetatable({[0] = t}, {__mode = "v"})
      for x = 1, #str do
        local ch = str:sub(x, x)
        t = rawget(t, ch)
        if t == nil then return false end
        cache_k[#cache_k + 1] = ch
        cache_t[#cache_t + 1] = t
      end
      local z = rawget(t, true)
      if z == nil then return false end
      rawset(t, true, nil)
      for i = #cache_t, 1, -1 do
        if next(cache_t[i]) ~= nil then break end
        rawset(cache_t[i - 1], cache_k[i], nil)
      end
      return true
    end,
    
    clear = function (t)
      local function f (t)
        for k, v in next, t do
          if k ~= true then f(v) end
          rawset(t, k, nil)
        end
      end
      f(t)
    end,
    
    get = function (t, str)
      for x = 1, #str do
        t = rawget(t, str:sub(x, x))
        if t == nil then return nil end
      end
      return rawget(t, true)
    end,
    
    lookup = function (t, str, beg)
      beg = beg or 1
      local x = beg - 1
      local longest, val
      repeat
        if rawget(t, true) ~= nil then
          longest, val = str:sub(beg, x), rawget(t, true)
        end
        x = x + 1
        t = rawget(t, str:sub(x, x))
      until t == nil;
      return longest, val
    end,

    begins = function (t, str)
      local out = {}
      for x = 1, #str do
        t = rawget(t, str:sub(x, x))
        if t == nil then return out end
      end
      local function f (t, prefix)
        for k, v in next, t do
          if k == true then out[#out + 1] = prefix
          else f(v, prefix .. k) end
        end
      end
      f(t, str)
      return out
    end,
    
    clone = function (t)
      local z = setmetatable({}, mt)
      for k, v in pairs(t) do z:add(k, v) end
      return z
    end,
  },

  __pairs = function (t)
    local function f (t, prefix)
      for k, v in next, t do
        if k == true then coroutine.yield(prefix, v)
        else f(v, prefix .. k) end
      end
    end
    return coroutine.wrap(f), t, ""
  end,
}

return function () return setmetatable({}, mt) end
