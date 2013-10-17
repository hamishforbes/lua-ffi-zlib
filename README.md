# lua-ffi-zlib

A [Lua](http://www.lua.org) module using LuaJIT's [FFI](http://luajit.org/ext_ffi.html) feature to access zlib.
Intended primarily for use within [OpenResty](http://openresty.org) to allow manipulation of gzip encoded HTTP responses.

Currently only provides gzip compression and decompression

# Example
Reads a file and output the decompressed version.
Roughly equivilent to running `gzip -dc file.gz`

```lua
local table_insert = table.insert
local table_concat = table.concat
local zlib = require('lib.ffi-zlib')

local f = io.open(arg[1], "rb")

local input = function(bufsize)
    local d = f:read(bufsize)
    if d == nil then
        return nil
    end
    return d
end

local output_table = {}
local output = function(data)
    table_insert(output_table, data)
end

-- Decompress the data
local ok, err = zlib.inflateGzip(input, output)
if not ok then
    -- Err message
    print(err)
    return
end

local decompressed = table_concat(output_table,'')

print(decompressed)
```