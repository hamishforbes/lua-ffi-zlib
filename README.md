# lua-ffi-zlib

A [Lua](http://www.lua.org) module using LuaJIT's [FFI](http://luajit.org/ext_ffi.html) feature to access zlib.
Intended primarily for use within [OpenResty](http://openresty.org) to allow manipulation of gzip encoded HTTP responses.

Currently only provides gzip compression and decompression

# Methods
## inflateGzip
`Syntax: ok, err = inflateGzip(input, output, chunk)`

 * `input` should be a function that accepts a chunksize as its only argument and return that many bytes of the gzip stream
 * `output` will receive a string of decompressed data as its only argument, do with it as you will!
 * `chunk` is the size of the input and output buffers, this defaults to 16KB

On error returns `false` and the error message, otherwise `true` and the last status message

## deflateGzip
`Syntax: ok, err = deflateGzip(input, output, chunk)`
 * `input` should be a function that accepts a chunksize as its only argument and return that many bytes of uncompressed data.
 * `output` will receive a string of compressed data as its only argument, do with it as you will!
 * `chunk` is the size of the input and output buffers, this defaults to 16KB

On error returns `false` and the error message, otherwise `true` and the last status message

# Example
Reads a file and output the decompressed version.

Roughly equivalent to running `gzip -dc file.gz`

```lua
local table_insert = table.insert
local table_concat = table.concat
local zlib = require('lib.ffi-zlib')

local f = io.open(arg[1], "rb")

local input = function(bufsize)
    -- Read the next chunk
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
    print(err)
    return
end

local decompressed = table_concat(output_table,'')

print(decompressed)
```
