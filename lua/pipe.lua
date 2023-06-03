---------------------------------------------------------------------------------

local ffi = require("ffi")
ffi.cdef[[
    int open( int handle );
    int read( int handle, char * buffer, int size );
    int write( int handle, char * buffer, int size );
    int close( int handle );

    int pipe(int *pipes, unsigned int flags);
    int fflush(int stream);
]]

local O_NONBLOCK    = 0x4000

---------------------------------------------------------------------------------
-- This is a global - all includes use it.
gPipeFDs = nil

---------------------------------------------------------------------------------
-- Pipe init
--    Create two pipes for each "channel". One read, one write.
local function pipeinit( num )

    gPipeFDs = ffi.new("int[?]", num * 2)

    for i=0, num-1 do 
        local tmp = ffi.new("int[2]")
        local pipeok = ffi.C.pipe( tmp, O_NONBLOCK )
        if( pipeok < 0) then 
            print("[Error] Unable to allocate pipes for channel: "..i)
            return nil
        else 
            gPipeFDs[i * 2]     = tmp[0]
            gPipeFDs[i * 2+1]   = tmp[1]    
        end 
    end
    return true
end

---------------------------------------------------------------------------------
local function piperead( handle, size )
    size = size or 16
    local temp = ffi.new( "char[?]", size + 1)
    ffi.fill(temp, 0, size + 1)
    local count = ffi.C.read(gPipeFDs[handle], temp, size)
    return count, ffi.string(temp)
end 

---------------------------------------------------------------------------------
local function pipewrite( handle, str )

    local buf = ffi.new( "char[?]", #str+1, str )
    ffi.C.write(gPipeFDs[handle], buf, #str+1)
end 

---------------------------------------------------------------------------------
local function pipeopen( handle )
    ffi.C.open(gPipeFDs[handle])
end 

---------------------------------------------------------------------------------
local function pipeclose( handle )
    ffi.C.close(gPipeFDs[handle])
end 

---------------------------------------------------------------------------------

local function flush( handle )
    ffi.C.fflush(gPipeFDs[handle]) 
end 

---------------------------------------------------------------------------------

return {

    init        = pipeinit,
    open        = pipeopen,
    read        = piperead,
    write       = pipewrite,
    close       = pipeclose,
    flush       = flush,
}

---------------------------------------------------------------------------------