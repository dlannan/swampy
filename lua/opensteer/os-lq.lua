-- //
-- // ----------------------------------------------------------------------------
-- //
-- //
-- // OpenSteer -- Steering Behaviors for Autonomous Characters
-- //
-- // Copyright (c) 2002-2003, Sony Computer Entertainment America
-- // Original author: Craig Reynolds <craig_reynolds@playstation.sony.com>
-- //
-- // Permission is hereby granted, free of charge, to any person obtaining a
-- // copy of this software and associated documentation files (the "Software"),
-- // to deal in the Software without restriction, including without limitation
-- // the rights to use, copy, modify, merge, publish, distribute, sublicense,
-- // and/or sell copies of the Software, and to permit persons to whom the
-- // Software is furnished to do so, subject to the following conditions:
-- //
-- // The above copyright notice and this permission notice shall be included in
-- // all copies or substantial portions of the Software.
-- //
-- // THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- // IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- // FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
-- // THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- // LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- // FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
-- // DEALINGS IN THE SOFTWARE.
-- //
-- // ----------------------------------------------------------------------------

-- // ------------------------------------------------------------------ 
-- //                                                                    
-- // Locality Query facility                                            
-- //                                                                    
-- // (by Craig Reynolds, see lq.h file for documentation)               
-- //                                                                    
-- //  5-17-99: created                                                  
-- //  5-20-99: found elusive "allocate 0 bins" bug                      
-- //  5-28-99: lqMapOverAllObjectsInLocality: clipped, incremental      
-- //  6- 7-99: clean up, split off annotation stuff into debuglq.c      
-- //  6- 8-99: tried screening by sum of coords ("first mean"?) but     
-- //           it was slightly slower, moved unused code to debuglq     
-- // 10-19-99: Change lqClientObject, lqObject from: "struct x {end" to  
-- //           "typedef struct x {end x" for EE compiler.                
-- // 12- 2-00: Make lqObject "private" using lqInternalDB.              
-- // 12- 5-00: Rename lqObject to lqDB, lqClientObject to lqClientProxy 
-- // 12- 6-00: Change lqCallBackFunction from arglist of (void*) to:    
-- //           (void* clientObject, float distanceSquared, void*        
-- //           clientQueryState).  Add void* clientQueryState arg to    
-- //           lqMapOverAllObjectsInLocality and its helper functions   
-- //           lqMapOverAllObjectsInLocalityClipped and                 
-- //           lqMapOverAllOutsideObjects. Change macro                 
-- //           lqTraverseBinClientObjectList to invoke callback         
-- //           function with three arguments, add "state" to its        
-- //           arglist.  Remove extern lqDistanceSquared.               
-- // 12- 7-00: Rename lqInitClientObject to lqInitClientProxy, make     
-- //           "func" be an argument to lqTraverseBinClientObjectList,  
-- //           add comments.                                            
-- // 12- 8-00: Add lqFindNearestNeighborWithinRadius and related        
-- //           definitions: lqFindNearestHelper lqFindNearestState      
-- //           Add lqMapOverAllObjects and lqRemoveAllObjects (plus:    
-- //           lqMapOverAllObjectsInBin and lqRemoveAllObjectsInBin)    
-- //                                                                    
-- // ------------------------------------------------------------------ 


-- // Converted to JS by David Lannan
-- // lq.h included here.

-- // ------------------------------------------------------------------ 
-- //                                                                    
-- //                   Locality Query (LQ) Facility                     
-- //                                                                    
-- // ------------------------------------------------------------------ 
-- //

--     This utility is a spatial database which stores objects each of
--     which is associated with a 3d point (a location in a 3d space).
--     The points serve as the "search key" for the associated object.
--     It is intended to efficiently answer "sphere inclusion" queries,
--     also known as range queries: basically questions like:
-- 
--         Which objects are within a radius R of the location L?
-- 
--     In this context, "efficiently" means significantly faster than the
--     naive, brute force O(n) testing of all known points.  Additionally
--     it is assumed that the objects move along unpredictable paths, so
--     that extensive preprocessing (for example, constructing a Delaunay
--     triangulation of the point set) may not be practical.
-- 
--     The implementation is a "bin lattice": a 3d rectangular array of
--     brick-shaped (rectangular parallelepipeds) regions of space.  Each
--     region is represented by a pointer to a (possibly empty) doubly-
--     linked list of objects.  All of these sub-bricks are the same
--     size.  All bricks are aligned with the global coordinate axes.
-- 
--     Terminology used here: the region of space associated with a bin
--     is called a sub-brick.  The collection of all sub-bricks is called
--     the super-brick.  The super-brick should be specified to surround
--     the region of space in which (almost) all the key-points will
--     exist.  If key-points move outside the super-brick everything will
--     continue to work, but without the speed advantage provided by the
--     spatial subdivision.  For more details about how to specify the
--     super-brick's position, size and subdivisions see lqCreateDatabase
--     below.
-- 
--     Overview of usage: an application using this facility would first
--     create a database with lqCreateDatabase.  For each client object
--     the application wants to put in the database it creates a
--     lqClientProxy and initializes it with lqInitClientProxy.  When a
--     client object moves, the application calls lqUpdateForNewLocation.
--     To perform a query lqMapOverAllObjectsInLocality is passed an
--     application-supplied call-back function to be applied to all
--     client objects in the locality.  See lqCallBackFunction below for
--     more detail.  The lqFindNearestNeighborWithinRadius function can
--     be used to find a single nearest neighbor using the database.
-- 
--     Note that "locality query" is also known as neighborhood query,
--     neighborhood search, near neighbor search, and range query.  For
--     additional information on this and related topics see:
--     http:-- //www.red3d.com/cwr/boids/ips.html
-- 
--     For some description and illustrations of this database in use,
--     see this paper: http:-- //www.red3d.com/cwr/papers/2000/pip.html
-- 



-- // ------------------------------------------------------------------ 
-- // This structure is a proxy for (and contains a pointer to) a client
--    (application) object in the spatial database.  One of these exists
--    for each client object.  This might be included within the
--    structure of a client object, or could be allocated separately.  
-- 

function lqClientProxy() 

    local self = {}
    -- // bin ID (pointer to pointer to bin contents list) 
    self.bin = nil

    -- // bin tag in the bin list - its a simple hash lookup for a guid 
    self.bintag = math.random().toString(36).substring(2) + (os.date()).getTime().toString(36)

    -- // pointer to client object 
    self.object = nil

    -- // the object's location ("key point") used for spatial sorting 
    self.x = 0.0
    self.y = 0.0
    self.z = 0.0

    return self
end

-- // ------------------------------------------------------------------ 
-- // Apply an application-specific function to all objects in a certain
--    locality.  The locality is specified as a sphere with a given
--    center and radius.  All objects whose location (key-point) is
--    within this sphere are identified and the function is applied to
--    them.  The application-supplied function takes three arguments:
-- 
--      (1) a void* pointer to an lqClientProxy's "object".
--      (2) the square of the distance from the center of the search
--          locality sphere (x,y,z) to object's key-point.
--      (3) a void* pointer to the caller-supplied "client query state"
--          object -- typically NULL, but can be used to store state
--          between calls to the lqCallBackFunction.
-- 
--    This routine uses the LQ database to quickly reject any objects in
--    bins which do not overlap with the sphere of interest.  Incremental
--    calculation of index values is used to efficiently traverse the
--    bins of interest. 
-- 

-- // type for a pointer to a function used to map over client objects 
function lqCallBackFunction(clientObject, distanceSquared, clientQueryState) end


-- // ------------------------------------------------------------------ 
-- // This structure represents the spatial database.  Typically one of
--    these would be created, by a call to lqCreateDatabase, for a given
--    application.  
-- 

function lqInternalDB() 

    local self = {}
    -- // the origin is the super-brick corner minimum coordinates 
    self.originx = 0.0
    self.originy = 0.0
    self.originz = 0.0

    -- // length of the edges of the super-brick 
    self.sizex = 0.0
    self.sizey = 0.0
    self.sizez = 0.0

    -- // number of sub-brick divisions in each direction 
    self.divx = 0
    self.divy = 0
    self.divz = 0

    -- // pointer to an array of pointers, one for each bin 
    self.bins = {}

    -- // extra bin for "everything else" (points outside super-brick) 
    self.other = nil
    return self
end

-- // Global lq proximity database handle.
local glq = new lqInternalDB()

-- // ------------------------------------------------------------------ 
-- // Allocate and initialize an LQ database, return a pointer to it.
--    The application needs to call this before using the LQ facility.
--    The nine parameters define the properties of the "super-brick":
--       (1) origin: coordinates of one corner of the super-brick, its
--           minimum x, y and z extent.
--       (2) size: the width, height and depth of the super-brick.
--       (3) the number of subdivisions (sub-bricks) along each axis.
--    This routine also allocates the bin array, and initialize its
--    contents. 
-- 

function lqCreateDatabase (originx, originy, originz, sizex, sizey, sizez, divx, divy, divz)
    
    local lq = new lqInternalDB()

    lqInitDatabase(lq, originx, originy, originz, sizex, sizey, sizez, divx, divy, divz)
    return lq
end


-- // ------------------------------------------------------------------ 
-- // Deallocate the memory used by the LQ database 


function lqDeleteDatabase(lq) 
    lq.bins = nil
    lq = nil
end


-- // ------------------------------------------------------------------ 
-- // Given an LQ database object and the nine basic parameters: fill in
--    the object's slots, allocate the bin array, and initialize its
--    contents. 
-- 

function lqInitDatabase (lq, originx, originy, originz, sizex, sizey, sizez, divx, divy, divz) 
    lq.originx = originx
    lq.originy = originy
    lq.originz = originz
    lq.sizex = sizex
    lq.sizey = sizey
    lq.sizez = sizez
    lq.divx = divx
    lq.divy = divy
    lq.divz = divz
    
	local bincount = divx * divy * divz
    lq.bins = {}
    lq.bins.length = bincount
	for i=0, bincount-1 do
        lq.bins[i] = nil
    end 

    lq.other = nil
end


-- // ------------------------------------------------------------------ 
-- // Determine index into linear bin array given 3D bin indices 


function lqBinCoordsToBinIndex(lq, ix, iy, iz) 
    return ((ix * lq.divy * lq.divz) + (iy * lq.divz) + iz)
end


-- // ------------------------------------------------------------------ 
-- // Find the bin ID for a location in space.  The location is given in
--    terms of its XYZ coordinates.  The bin ID is a pointer to a pointer
--    to the bin contents list.  
-- 

function lqBinForLocation (lq, x, y, z) 
    local i, ix, iy, iz = nil

    -- // if point outside super-brick, return the "other" bin 
    if (x < lq.originx) then               return (lq.other) end
    if (y < lq.originy) then              return (lq.other) end
    if (z < lq.originz) then              return (lq.other) end
    if (x >= lq.originx + lq.sizex) then return (lq.other) end
    if (y >= lq.originy + lq.sizey) then return (lq.other) end
    if (z >= lq.originz + lq.sizez) then return (lq.other) end

    -- // if point inside super-brick, compute the bin coordinates 
    ix = (((x - lq.originx) / lq.sizex) * lq.divx) or 0
    iy = (((y - lq.originy) / lq.sizey) * lq.divy) or 0
    iz = (((z - lq.originz) / lq.sizez) * lq.divz) or 0

    -- // convert to linear bin number 
    i = lqBinCoordsToBinIndex (lq, ix, iy, iz)

    -- // return pointer to that bin 
    return i
end


-- // ------------------------------------------------------------------ 
-- // The application needs to call this once on each lqClientProxy at
--    setup time to initialize its list pointers and associate the proxy
--    with its client object.  
-- 
function lqInitClientProxy (proxy, clientObject) 
    
    local proxy = new lqClientProxy()
    proxy.object = clientObject
    return proxy
end


-- // ------------------------------------------------------------------ 
-- // Adds a given client object to a given bin, linking it into the bin
--   contents list. 

function lqAddToBin(lq, object, idx) 
    
    -- // Old object at this idx
    local binlist = lq.bins[idx]

    -- // if bin is currently empty     
    if(binlist == nil) then 
        lq.bins[idx] = {}
    end

    -- // record bin ID in proxy object 
    object.bin = idx
    lq.bins[idx][object.bintag] = object
    -- //console.log("Added:", object)
end


-- // ------------------------------------------------------------------ 
-- // Removes a given client object from its current bin, unlinking it
--   from the bin contents list. 

function lqRemoveFromBin(lq, object) 

    -- // Object bin
    local binobj = lq.bins[object.bin]

    -- // adjust pointers if object is currently in a bin 
    if (binobj !== nil) then
        binobj[object.bintag] = nil
    end

    -- // Null out prev, next and bin pointers of this object. 
    object.bin = nil

    -- //console.log("Removed:", object)
    lq.bins[object.bin] = binobj
end


-- // ------------------------------------------------------------------ 
-- // Call for each client object every time its location changes.  For
--    example, in an animation application, this would be called each
--    frame for every moving object.  
-- 

function lqUpdateForNewLocation(lq, object, x, y, z) 
    -- // find bin for new location 
    local idx = lqBinForLocation(lq, x, y, z)

    -- // store location in client object, for future reference 
    object.x = x
    object.y = y
    object.z = z

    if(idx == nil) then return end
    local newBin = lq.bins[idx]

    -- // has object moved into a new bin? 
    if(newBin == nil) then
        -- //console.log("Adding bin!")
        lqAddToBin(lq, object, idx)
    -- // Changing bin for this object?
    else 
        if(idx !== object.bin) then
            -- //console.log("Changing bin!")
            lqRemoveFromBin(lq, object)
            lqAddToBin(lq, object, idx)
        end
    end
end


-- // ------------------------------------------------------------------ 
-- // Given a bin's list of client proxies, traverse the list and invoke
--    the given lqCallBackFunction on each object that falls within the
--    search radius.  
-- 

function lqTraverseBinClientObjectList(lq, x, y, z, idx, radiusSquared, func, state) 
    
    local binlist = lq.bins[idx]
    for idx,bidx in pairs(binlist) do
        local co = binlist[bidx]

        -- // compute distance (squared) from this client              
        -- // object to given locality sphere's centerpoint            
        local dx = x - co.x                                         
        local dy = y - co.y                                         
        local dz = z - co.z                                         
        local distanceSquared = (dx * dx) + (dy * dy) + (dz * dz)    
                                                                        
        -- // apply function if client object within sphere            
        if (distanceSquared < radiusSquared) then
            func(co.object, distanceSquared, state)             
        end                 
    end
end


-- // ------------------------------------------------------------------ 
-- // This subroutine of lqMapOverAllObjectsInLocality efficiently
--    traverses of subset of bins specified by max and min bin
--    coordinates. 
-- 

function lqMapOverAllObjectsInLocalityClipped ( lq, x, y, z, radius, func, clientQueryState, minBinX, minBinY, minBinZ, maxBinX, maxBinY, maxBinZ) 
    local i, j, k = nil
    local iindex, jindex, kindex = nil

    local slab = lq.divy * lq.divz
    local row = lq.divz

    local istart = minBinX * slab
    local jstart = minBinY * row
    local kstart = minBinZ

    local co
    local bin
    local radiusSquared = radius * radius

    -- // loop for x bins across diameter of sphere 
    iindex = istart
    for i = minBinX, maxBinX do
        -- // loop for y bins across diameter of sphere 
        jindex = jstart
        for j = minBinY, maxBinY do
            -- // loop for z bins across diameter of sphere 
            kindex = kstart
            for k = minBinZ, maxBinZ do
                -- // get current bin's client object list 
                co = iindex + jindex + kindex

                -- // traverse current bin's client object list 
                lqTraverseBinClientObjectList(lq, x, y, z, co, radiusSquared, func, clientQueryState)
                kindex = kindex + 1
            end
            jindex = jindex + row
        end
        iindex = iindex + slab
    end
end


-- // ------------------------------------------------------------------ 
-- // If the query region (sphere) extends outside of the "super-brick"
--    we need to check for objects in the catch-all "other" bin which
--    holds any object which are not inside the regular sub-bricks  
-- 

function lqMapOverAllOutsideObjects ( lq, x, y, z, radius, func, clientQueryState)

    if(lq.other == nil) then return end
    local co = lq.other
    local radiusSquared = radius * radius

    -- // traverse the "other" bin's client object list 
    lqTraverseBinClientObjectList ( lq, co, radiusSquared, func, clientQueryState)
end


-- // ------------------------------------------------------------------ 
-- // Apply an application-specific function to all objects in a certain
--    locality.  The locality is specified as a sphere with a given
--    center and radius.  All objects whose location (key-point) is
--    within this sphere are identified and the function is applied to
--    them.  The application-supplied function takes three arguments:
-- 
--      (1) a void* pointer to an lqClientProxy's "object".
--      (2) the square of the distance from the center of the search
--          locality sphere (x,y,z) to object's key-point.
--      (3) a void* pointer to the caller-supplied "client query state"
--          object -- typically NULL, but can be used to store state
--          between calls to the lqCallBackFunction.
-- 
--    This routine uses the LQ database to quickly reject any objects in
--    bins which do not overlap with the sphere of interest.  Incremental
--    calculation of index values is used to efficiently traverse the
--    bins of interest. 
-- 

function lqMapOverAllObjectsInLocality( lq, x, y, z, radius, func, clientQueryState) 

    local minBinX, minBinY, minBinZ, maxBinX, maxBinY, maxBinZ = nil
    local partlyOut = 0
    local completelyOutside = ((x + radius) < lq.originx) or ((y + radius) < lq.originy) or ((z + radius) < lq.originz)
    completelyOutside = completelyOutside or ((x - radius) >= lq.originx + lq.sizex) or ((y - radius) >= lq.originy + lq.sizey) or ((z - radius) >= lq.originz + lq.sizez)

    -- // is the sphere completely outside the "super brick"? 
    if(completelyOutside == true) then
        -- //console.log("Outside super brick??????")
        lqMapOverAllOutsideObjects (lq, x, y, z, radius, func, clientQueryState)
        return
    end

    -- // compute min and max bin coordinates for each dimension 
    minBinX = ((((x - radius) - lq.originx) / lq.sizex) * lq.divx) or 0
    minBinY = ((((y - radius) - lq.originy) / lq.sizey) * lq.divy) or 0
    minBinZ = ((((z - radius) - lq.originz) / lq.sizez) * lq.divz) or 0
    maxBinX = ((((x + radius) - lq.originx) / lq.sizex) * lq.divx) or 0
    maxBinY = ((((y + radius) - lq.originy) / lq.sizey) * lq.divy) or 0
    maxBinZ = ((((z + radius) - lq.originz) / lq.sizez) * lq.divz) or 0

    -- // clip bin coordinates 
    if (minBinX < 0)         then partlyOut = 1 minBinX = 0 end
    if (minBinY < 0)         then partlyOut = 1 minBinY = 0 end
    if (minBinZ < 0)         then partlyOut = 1 minBinZ = 0 end
    if (maxBinX >= lq.divx) then  partlyOut = 1 maxBinX = lq.divx - 1 end
    if (maxBinY >= lq.divy) then partlyOut = 1 maxBinY = lq.divy - 1 end
    if (maxBinZ >= lq.divz) then partlyOut = 1 maxBinZ = lq.divz - 1 end

    -- // map function over outside objects if necessary (if clipped) 
    if (partlyOut == 1) then
        -- //console.log("Partly out")
        lqMapOverAllOutsideObjects (lq, x, y, z, radius, func, clientQueryState)
    end

    -- //console.log("Map over objects")
    -- // map function over objects in bins 
    lqMapOverAllObjectsInLocalityClipped (lq, x, y, z, radius, func, clientQueryState, minBinX, minBinY, minBinZ, maxBinX, maxBinY, maxBinZ)
end


-- // ------------------------------------------------------------------ 
-- // internal helper function 


local lqFindNearestState = function() 
    self.ignoreObject = nil
    self.nearestObject = nil
    self.minDistanceSquared = 0.0

end

function lqFindNearestHelper (clientObject, distanceSquared, clientQueryState) 
    local fns = clientQueryState

    -- // do nothing if this is the "ignoreObject" 
    if (fns.ignoreObject ~= clientObject) then
        -- // record this object if it is the nearest one so far 
        if (fns.minDistanceSquared > distanceSquared) then
            fns.nearestObject = clientObject
            fns.minDistanceSquared = distanceSquared
        end
    end
end


-- // ------------------------------------------------------------------ 
-- // Search the database to find the object whose key-point is nearest
--    to a given location yet within a given radius.  That is, it finds
--    the object (if any) within a given search sphere which is nearest
--    to the sphere's center.  The ignoreObject argument can be used to
--    exclude an object from consideration (or it can be NULL).  This is
--    useful when looking for the nearest neighbor of an object in the
--    database, since otherwise it would be its own nearest neighbor.
--    The function returns a void* pointer to the nearest object, or
--    NULL if none is found.  
-- 

function lqFindNearestNeighborWithinRadius (lq, x, y, z, radius, ignoreObject) 
    
    -- // initialize search state 
    local lqFNS = new lqFindNearestState()
    lqFNS.nearestObject = nil
    lqFNS.ignoreObject = ignoreObject
    lqFNS.minDistanceSquared = Number.MAX_VALUE

    -- // map search helper function over all objects within radius 
    lqMapOverAllObjectsInLocality (lq, x, y, z, radius, lqFindNearestHelper, lqFNS)

    -- // return nearest object found, if any 
    return lqFNS.nearestObject
end

-- // ------------------------------------------------------------------ 
-- // internal helper function 

function lqMapOverAllObjectsInBin (binProxyList, func, clientQueryState)

    -- // walk down proxy list, applying call-back function to each one 
    while (binProxyList ~= nil) do
        func(binProxyList.object, 0, clientQueryState)
        binProxyList = binProxyList.next
    end
end


-- // ------------------------------------------------------------------ 
-- // Apply a user-supplied function to all objects in the database,
--   regardless of locality (cf lqMapOverAllObjectsInLocality) 

function lqMapOverAllObjects (lq, func, clientQueryState)

    local bincount = lq.divx * lq.divy * lq.divz
    for i=0, bincount-1 do
        lqMapOverAllObjectsInBin (lq.bins[i], func, clientQueryState)
    end
    lqMapOverAllObjectsInBin (lq.other, func, clientQueryState)
end


-- // ------------------------------------------------------------------ 
-- // internal helper function 


function lqRemoveAllObjectsInBin(lq, bin) 
    while (bin !== nil) do
        lqRemoveFromBin(lq, bin)
    end
end


-- // ------------------------------------------------------------------ 
-- // Removes (all proxies for) all objects from all bins 

function lqRemoveAllObjects (lq) 

    local bincount = lq.divx * lq.divy * lq.divz
    for i=0, bincount-1 do
        lqRemoveAllObjectsInBin (lq, lq.bins[i])
    end
    lqRemoveAllObjectsInBin (lq.other)
end


-- // ------------------------------------------------------------------ 