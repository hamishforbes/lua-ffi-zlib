local table_insert = table.insert
local table_concat = table.concat

local zlib = require('lib.ffi-zlib')

local chunk = 16384
local uncompressed = ''
local input
local f

if arg[1] == nil then
    print("No file provided")
    return
else
    f = io.open(arg[1], "rb")
    input = function(bufsize)
        local d = f:read(bufsize)
        if d == nil then
            return nil
        end
        uncompressed = uncompressed..d
        return d
    end
end

local output_table = {}
local output = function(data)
    table_insert(output_table, data)
end

-- Compress the data
local ok, err = zlib.deflateGzip(input, output, chunk)
if not ok then
    -- Err message
    print(err)
end

local compressed = table_concat(output_table,'')


-- Decompress it again
output_table = {}
local count = 0
local input = function(bufsize)
    local start = count > 0 and bufsize*count or 1
    local data = compressed:sub(start, (bufsize*(count+1)-1) )
    count = count + 1
    return data
end

local ok, err = zlib.inflateGzip(input, output, chunk)
if not ok then
    -- Err message
    print(err)
end
local output_data = table_concat(output_table,'')

if output_data ~= uncompressed then
    print(":(")
else
    print(":)")
end
