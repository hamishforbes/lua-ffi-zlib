local zlib = require "lib.ffi-zlib"

local printf = io.write
local chunk_size = 10


local f = io.open(arg[1] or "sample.gz", "rb")

local input = function (bufsize)
   return f:read(bufsize)
end

local output = function (data)
   printf(data)
end

-- Decompress the data
local ok, err = zlib.inflateGzip(input, output, chunk_size)
if not ok then
   print(err)
end

