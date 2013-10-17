local ffi = require "ffi"
local ffi_new = ffi.new
local ffi_str = ffi.string
local ffi_sizeof =ffi.sizeof
local ffi_copy = ffi.copy
local setmetatable = setmetatable
local error = error

local _M = {
    _VERSION = '0.01',
}

local mt = { __index = _M }


ffi.cdef([[

enum {
    Z_NO_FLUSH           = 0,
    Z_PARTIAL_FLUSH      = 1,
    Z_SYNC_FLUSH         = 2,
    Z_FULL_FLUSH         = 3,
    Z_FINISH             = 4,
    Z_BLOCK              = 5,
    Z_TREES              = 6,
    /* Allowed flush values; see deflate() and inflate() below for details */
    Z_OK                 = 0,
    Z_STREAM_END         = 1,
    Z_NEED_DICT          = 2,
    Z_ERRNO              = -1,
    Z_STREAM_ERROR       = -2,
    Z_DATA_ERROR         = -3,
    Z_MEM_ERROR          = -4,
    Z_BUF_ERROR          = -5,
    Z_VERSION_ERROR      = -6,
    /* Return codes for the compression/decompression functions. Negative values
    * are errors, positive values are used for special but normal events.
    */
    Z_NO_COMPRESSION      =  0,
    Z_BEST_SPEED          =  1,
    Z_BEST_COMPRESSION    =  9,
    Z_DEFAULT_COMPRESSION = -1,
    /* compression levels */
    Z_FILTERED            =  1,
    Z_HUFFMAN_ONLY        =  2,
    Z_RLE                 =  3,
    Z_FIXED               =  4,
    Z_DEFAULT_STRATEGY    =  0,
    /* compression strategy; see deflateInit2() below for details */
    Z_BINARY              =  0,
    Z_TEXT                =  1,
    Z_ASCII               =  Z_TEXT,   /* for compatibility with 1.2.2 and earlier */
    Z_UNKNOWN             =  2,
    /* Possible values of the data_type field (though see inflate()) */
    Z_DEFLATED            =  8,
    /* The deflate compression method (the only one supported in this version) */
    Z_NULL                =  0,  /* for initializing zalloc, zfree, opaque */
};


typedef void*    (* z_alloc_func)( void* opaque, unsigned items, unsigned size );
typedef void     (* z_free_func) ( void* opaque, void* address );

typedef struct z_stream_s {
   char*         next_in;
   unsigned      avail_in;
   unsigned long total_in;
   char*         next_out;
   unsigned      avail_out;
   unsigned long total_out;
   char*         msg;
   void*         state;
   z_alloc_func  zalloc;
   z_free_func   zfree;
   void*         opaque;
   int           data_type;
   unsigned long adler;
   unsigned long reserved;
} z_stream;


const char*   zlibVersion(          );

const char*   zError(               int );

int           inflate(              z_stream*, int flush );
int           inflateEnd(           z_stream*  );
int           inflateInit2_(        z_stream*, int windowBits, const char* version, int stream_size);

int           deflate(              z_stream*, int flush );
int           deflateEnd(           z_stream*  );
int           deflateInit2_(        z_stream*, int level, int method, int windowBits, int memLevel,
                       int strategy, const char *version, int stream_size );


]])

local zlib = ffi.load(ffi.os == "Windows" and "zlib1" or "z")

local function zlib_err(err)
    return ffi_str(zlib.zError(err))
end

local function createStream(bufsize)
    -- Default to 16k output buffer
    local bufsize = bufsize or 16384

    -- Setup Stream
    local stream = ffi_new("z_stream")

    -- Create input buffer var
    local inbuf = ffi_new('char[?]', bufsize+1)
    stream.next_in, stream.avail_in = inbuf, 0

    -- create the output buffer
    local outbuf = ffi_new('char[?]', bufsize)
    stream.next_out, stream.avail_out = outbuf, 0

    return stream, inbuf, outbuf
end

local function initInflate(stream)
    -- Setup inflate process
    local windowBits = 15 + 32 -- +32 sets automatic header detection
    local version = ffi_str(zlib.zlibVersion())
    local init = zlib.inflateInit2_(stream, windowBits, version, ffi_sizeof(stream))
    return init
end

local function initDeflate(stream, level, method, memLevel, strategy)
    -- Setup deflate process
    local level = level or zlib.Z_DEFAULT_COMPRESSION
    local method = method or zlib.Z_DEFLATED
    local memLevel = memLevel or 8
    local strategy = strategy or zlib.Z_DEFAULT_STRATEGY
    local windowBits = 15 + 16 -- +16 sets gzip wrapper not zlib
    local version = ffi_str(zlib.zlibVersion())
    local init = zlib.deflateInit2_(stream, level, method, windowBits, memLevel, strategy, version, ffi_sizeof(stream))
    return init
end

local function flushOutput(stream, bufsize, output, outbuf)
    -- Calculate available output bytes
    local out_sz = bufsize - stream.avail_out
    if out_sz == 0 then
        return
    end
    -- Read bytes from output buffer and pass to output function
    output(ffi_str(outbuf, out_sz))
end


local function flate(flate, flateEnd, input, output, bufsize, stream, inbuf, outbuf)
    -- Inflate or Deflate a stream
    local err = 0
    local mode = zlib.Z_NO_FLUSH
    repeat
        -- Read some input
        local data = input(bufsize)
        if data ~= nil then
            ffi_copy(inbuf, data)
            stream.next_in, stream.avail_in = inbuf, #data
        else
            -- EOF, try and finish up
            mode = zlib.Z_FINISH
            stream.avail_in = 0
        end

        -- While the output buffer is being filled completely just keep going
        repeat
            stream.next_out = outbuf
            stream.avail_out = bufsize
            -- Decompress!
            err = flate(stream, mode)
            if err < zlib.Z_OK then
                -- Error :(
                flateEnd(stream)
                return false, "FLATE: "..zlib_err(err), stream
            end
            -- Write the data out
            flushOutput(stream, bufsize, output, outbuf)
        until stream.avail_out ~= 0

    until err == zlib.Z_STREAM_END

    -- Stream finished, clean up and return
    flateEnd(stream)
    return true, zlib_err(err)

end

function _M.inflateGzip(input, output, bufsize)
    -- Takes 2 functions that provide input data from a gzip stream and receives output data
    -- Returns uncompressed string
    local stream, inbuf, outbuf = createStream(bufsize)

    if initInflate(stream) == zlib.Z_OK then
        local ok, err = flate(zlib.inflate, zlib.inflateEnd, input, output, bufsize, stream, inbuf, outbuf)
        return ok,err
    else
        -- Init error
        zlib.inflateEnd(stream)
        return false, "INIT: "..zlib_err(init)
    end
end

function _M.deflateGzip(input, output, bufsize)
    -- Takes 2 functions that provide plain input data and receives output data
    -- Returns gzip compressed string
    local stream, inbuf, outbuf = createStream(bufsize)

    if initDeflate(stream) == zlib.Z_OK then
        local ok, err = flate(zlib.deflate, zlib.deflateEnd, input, output, bufsize, stream, inbuf, outbuf)
        return ok,err
    else
        -- Init error
        zlib.deflateEnd(stream)
        return false, "INIT: "..zlib_err(init)
    end
end


return _M