

-- // construct a PolylinePathway given the number of points (vertices),
-- // an array of points, and a path radius.
function PolylinePathway1 (_pointCount, _points, _radius, _cyclic) 
    local pw = new PolylinePathway()
    pw.initialize (_pointCount, _points, _radius, _cyclic)
    return pw
end


-- // ----------------------------------------------------------------------------
-- // PolylinePathway: a simple implementation of the Pathway protocol.  The path
-- // is a "polyline" a series of line segments between specified points.  A
-- // radius defines a volume for the path which is the union of a sphere at each
-- // point and a cylinder along each segment.

local PolylinePathway = function() 

    local self = {}
    -- // xxx shouldn't these 5 just be local variables?
    -- // xxx or are they used to pass secret messages between calls?
    -- // xxx seems like a bad design
    self.segmentLength = 0.0
    self.segmentProjection = 0.0
    self.localspace = Vec3()
    self.chosen = Vec3()
    self.segmentNormal = Vec3()

    self.lengths = {}
    self.normals = {}
    self.totalPathLength = 0.0

    -- // is the given point inside the path tube?
    self.isInsidePath = function(point) 
        local outside 
        local tangent = Vec3()
        local res = mapPointToPath(point, tangent, outside)
        return res.outside < 0.0
    end

    -- // how far outside path tube is the given point?  (negative is inside)
    self.howFarOutsidePath = function(point) 
        local outside 
        local tangent = Vec3()
        local res = mapPointToPath(point, tangent, outside)
        return res.outside
    end

    self.pointCount = 0
    self.points = {}
    self.radius = 0.0
    self.cyclic = false


    -- // utility for constructors in derived classes
    self.initialize = function( _pointCount, _points, _radius, _cyclic) 
        -- // set data members, allocate arrays
        self.radius = _radius
        self.cyclic = _cyclic
        self.pointCount = _pointCount
        self.totalPathLength = 0.0
        if (self.cyclic) then self.pointCount = self.pointCount + 1 end
        self.lengths = {}
        self.points  = {}
        self.normals = {}

        -- // loop over all points
        for i = 0, self.pointCount-1  do

            -- // copy in point locations, closing cycle when appropriate
            local closeCycle = self.cyclic and (i == self.pointCount-1)
            local j = i
            if closeCycle then j = 0 end
            self.points[i] = _points[j]

            -- // for the end of each segment
            if (i > 0) then 
                -- // compute the segment length
                self.normals[i] = self.points[i].sub( self.points[i-1] )
                self.lengths[i] = self.normals[i].length()

                -- // find the normalized vector parallel to the segment
                self.normals[i] = self.normals[i].mult(1.0 / self.lengths[i])

                -- // keep running total of segment lengths
                self.totalPathLength = self.totalPathLength + self.lengths[i]
            end
        end
    end

    -- // Given an arbitrary point ("A"), returns the nearest point ("P") on
    -- // this path.  Also returns, via output arguments, the path tangent at
    -- // P and a measure of how far A is outside the Pathway's "tube".  Note
    -- // that a negative distance indicates A is inside the Pathway.
    self.mapPointToPath = function( point, tangent, outside) 

        local d
        local minDistance = Number.MAX_VALUE
        local onPath = Vec3()
    
        -- // loop over all segments, find the one nearest to the given point
        for i = 1, self.pointCount-1 do 
            self.segmentLength = self.lengths[i]
            self.segmentNormal = self.normals[i]
            d = self.pointToSegmentDistance(point, self.points[i-1], self.points[i])
            if (d < minDistance) then
                minDistance = d
                onPath = self.chosen
                tangent = self.segmentNormal
            end
        end
    
        -- // measure how far original point is outside the Pathway's "tube"
        outside = Vec3.distance(onPath, point) - self.radius
        local res = { onPath=onPath, tangent=tangent, outside=outside }
        -- // return point on path
        return res
    end


    -- // given an arbitrary point, convert it to a distance along the path
    self.mapPointToPathDistance = function(point) 
        local d
        local minDistance = Number.MAX_VALUE
        local segmentLengthTotal = 0.0
        local pathDistance = 0.0
    
        for i = 1, self.pointCount-1 do
            self.segmentLength = self.lengths[i]
            self.segmentNormal = self.normals[i]
            d = self.pointToSegmentDistance(point, self.points[i-1], self.points[i])
            if (d < minDistance) then 
                minDistance = d
                pathDistance = segmentLengthTotal + self.segmentProjection
            end
            segmentLengthTotal = segmentLengthTotal + self.segmentLength
        end
    
        -- // return distance along path of onPath point
        return pathDistance
    end

    -- // given a distance along the path, convert it to a point on the path
    self.mapPathDistanceToPoint = function(pathDistance) 
        
        -- // clip or wrap given path distance according to cyclic flag
        local remaining = pathDistance
        if (self.cyclic) then 
            remaining = (pathDistance % self.totalPathLength)
        else
            if (pathDistance < 0.0) then return self.points[0] end
            if (pathDistance >= self.totalPathLength) then return self.points[self.pointCount-1] end
        end

        -- // step through segments, subtracting off segment lengths until
        -- // locating the segment that contains the original pathDistance.
        -- // Interpolate along that segment to find 3d point value to return.
        local result = Vec3()
        for i = 1, self.pointCount-1 do
            self.segmentLength = self.lengths[i]
            if (self.segmentLength < remaining) then 
                remaining = remaining - self.segmentLength
            else 
                local ratio = remaining / self.segmentLength
                result = interpolateV(ratio, self.points[i-1], self.points[i])
                break
            end
        end
        return result
    end

    -- // utility methods

    -- // compute minimum distance from a point to a line segment
    self.pointToSegmentDistance = function( point, ep0, ep1) 

        -- // convert the test point to be "local" to ep0
        self.localspace = point.sub( ep0 )

        -- // find the projection of "local" onto "segmentNormal"
        self.segmentProjection = self.segmentNormal.dot(self.localspace)

        -- // handle boundary cases: when projection is not on segment, the
        -- // nearest point is one of the endpoints of the segment
        if (self.segmentProjection < 0.0)  then 
            self.chosen = ep0
            self.segmentProjection = 0
            return Vec3.distance(point, ep0)
        end
        if (self.segmentProjection > self.segmentLength) then 
            self.chosen = ep1
            self.segmentProjection = self.segmentLength
            return Vec3.distance(point, ep1)
        end

        -- // otherwise nearest point is projection point on segment
        self.chosen = self.segmentNormal.mult( self.segmentProjection)
        self.chosen = self.chosen.add( ep0 )
        return Vec3.distance (point, self.chosen)
    end

    -- // assessor for total path length
    self.getTotalPathLength = function() return self.totalPathLength end
    return self
end

return PolylinePathway
