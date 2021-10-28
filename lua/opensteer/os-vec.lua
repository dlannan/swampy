-- // ----------------------------------------------------------------------------
-- //
-- //
-- // OpenSteer -- Steering Behaviors for Autonomous Characters
-- //
-- // Copyright (c) 2002-2005, Sony Computer Entertainment America
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
-- //
-- // ----------------------------------------------------------------------------
-- //
-- // Vec3: OpenSteer's generic type for 3d vectors
-- //
-- // This file defines the class Vec3, which is used throughout OpenSteer to
-- // manipulate 3d geometric data.  It includes standard vector operations (like
-- // vector addition, subtraction, scale, dot, cross...) and more idiosyncratic
-- // utility functions.
-- //
-- // When integrating OpenSteer into a preexisting 3d application, it may be
-- // important to use the 3d vector type of that application.  In that case Vec3
-- // can be changed to inherit from the preexisting application' vector type and
-- // to match the interface used by OpenSteer to the interface provided by the
-- // preexisting 3d vector type.
-- //
-- // 10-04-04 bk:  put everything into the OpenSteer namespace
-- // 03-26-03 cwr: created to replace for Hiranabe-san's execellent but larger
-- //               vecmath package (http://objectclub.esm.co.jp/vecmath/)
-- //
-- // ----------------------------------------------------------------------------
-- 
-- 
-- // ----------------------------------------------------------------------------
-- // Generic interpolation
-- 
function square( a ) 
    return a * a
end

function interpolate (alpha, x0, x1) 
    return x0 + ((x1 - x0) * alpha)
end


function interpolateV (alpha, x0, x1) 
    return x0.add((x1.sub(x0)).mult(alpha));
end

function maxXXX ( x, y) if (x > y) then return x else return y end end
function minXXX ( x, y) if (x < y) then return x else return y end end


-- // ----------------------------------------------------------------------------
-- // Random number utilities
-- 
-- 
-- // Returns a float randomly distributed between 0 and 1

function frandom01() 
    return (math.random())
end


-- // Returns a float randomly distributed between lowerBound and upperBound

function frandom2( lowerBound, upperBound ) 
    local diff = upperBound - lowerBound
    return math.floor((math.random() * diff) + lowerBound)
end


-- // ----------------------------------------------------------------------------
-- // Constrain a given value (x) to be between two (ordered) bounds: min
-- // and max.  Returns x if it is between the bounds, otherwise returns
-- // the nearer bound.

function clip( x, minv, maxv) 
    if (x < minv) then return minv end 
    if (x > maxv) then return maxv end 
    return x
end

-- // ----------------------------------------------------------------------------
-- // remap a value specified relative to a pair of bounding values
-- // to the corresponding value relative to another pair of bounds.
-- // Inspired by (dyna:remap-interval y y0 y1 z0 z1)

function remapInterval (x, in0, in1, out0, out1) 
    -- // uninterpolate: what is x relative to the interval in0:in1?
    local relative = (x - in0) / (in1 - in0)

    -- // now interpolate between output interval based on relative x
    return interpolate(relative, out0, out1)
end


-- // Like remapInterval but the result is clipped to remain between
-- // out0 and out1
function remapIntervalClip(x, in0, in1, out0, out1) 
    -- // uninterpolate: what is x relative to the interval in0:in1?
    local relative = (x - in0) / (in1 - in0)

    -- // now interpolate between output interval based on relative x
    return interpolate(clip(relative, 0, 1), out0, out1)
end


-- // Like remapInterval but the result is clipped to remain between
-- // out0 and out1
function remapIntervalClipV (x, in0, in1, out0, out1) 
    -- // uninterpolate: what is x relative to the interval in0:in1?
    local relative = (x - in0) / (in1 - in0)

    -- // now interpolate between output interval based on relative x
    return interpolateV(clip(relative, 0.0, 1.0), out0, out1)
end


-- // ----------------------------------------------------------------------------
-- // classify a value relative to the interval between two bounds:
-- //     returns -1 when below the lower bound
-- //     returns  0 when between the bounds (inside the interval)
-- //     returns +1 when above the upper bound

function intervalComparison ( x, lowerBound, upperBound) 
    if (x < lowerBound) then return -1 end
    if (x > upperBound) then return 1 end
    return 0
end

-- // ----------------------------------------------------------------------------

function scalarRandomWalk(initial, walkspeed, minv, maxv) 
    local next = initial + (((frandom01() * 2) - 1) * walkspeed)
    if (next < minv) then return minv end
    if (next > maxv) then return maxv end
    return next
end

-- // ----------------------------------------------------------------------------

function blendIntoAccumulator( smoothRate, newValue, smoothedAccumulator ) 
    return interpolate( clip(smoothRate, 0.0, 1.0), smoothedAccumulator, newValue)
end

-- // ----------------------------------------------------------------------------

function blendIntoAccumulatorV( smoothRate, newValue, smoothedAccumulator ) 
    return interpolateV( clip(smoothRate, 0.0, 1.01), smoothedAccumulator, newValue)
end 

-- // ----------------------------------------------------------------------------

function clamp( valueToClamp, minValue, maxValue) 

    if ( valueToClamp < minValue ) then 
        return minValue
    else 
        if ( valueToClamp > maxValue ) then 
            return maxValue
        end
    end 
    return valueToClamp
end

-- // ----------------------------------------------------------------------------

local Vec3 = function() 

    local self = {}
    
    -- // ----------------------------------------- generic 3d vector operations
    -- // three-dimensional Cartesian coordinates
    self.x = 0.0
    self.y = 0.0
    self.z = 0.0

    -- // vector addition
    self.add = function(v) 
        local res = Vec3Set( self.x+v.x, self.y+v.y, self.z+v.z )
        return res
    end

    -- // vector subtraction
    self.sub = function(v) 
        local res = Vec3Set( self.x-v.x, self.y-v.y, self.z-v.z )
        return res
    end 

    -- // unary minus
    self.neg = function() 
        local res = Vec3Set( -self.x, -self.y, -self.z )
        return res
    end
    
    -- // vector times scalar product (scale length of vector times argument)
    self.mult = function(s) 
        local res = Vec3Set( self.x*s, self.y*s, self.z*s )
        return res
    end 

    -- // vector divided by a scalar (divide length of vector by argument)
    self.div = function(s) 
        local res = Vec3Set( self.x/s, self.y/s, self.z/s )
        return res
    end 

    -- // dot product
    self.dot = function( v ) 
        return (self.x * v.x) + (self.y * v.y) + (self.z * v.z)
    end

    -- // length
    self.length = function() 
        return math.sqrt( self.lengthSquared() )
    end 

    -- // length squared
    self.lengthSquared = function() 
        return self.dot(self)
    end

    -- // normalize: returns normalized version (parallel to this, length = 1)
    self.normalize = function() 
        -- // skip divide if length is zero
        local len = self.length()
        if(len>0) then 
            return self.div(len)
        else 
            return Vec3Set( self.x, self.y, self.z )
        end 
    end 

    -- // cross product (modify "*this" to be A x B)
    -- // [XXX  side effecting -- deprecate this function?  XXX]
    self.cross = function ( a, b ) 
        self.set((a.y * b.z) - (a.z * b.y),
                        (a.z * b.x) - (a.x * b.z),
                        (a.x * b.y) - (a.y * b.x))
    end 

    -- // assignment
    self.setV = function(v) 
        self.x=v.x; self.y=v.y; self.z=v.z
        return self
    end 

    -- // set XYZ coordinates to given three floats
    self.set = function( _x, _y, _z) 
        self.x = _x; self.y = _y; self.z = _z
    end 

    -- // +=
    self.addV = function(v) 
        self.add(v)
        return self
    end

    -- // -=
    self.subV = function(v) 
        self.sub(v)
        return self 
    end 

    -- // *=
    self.multV = function(s) 
        self.mult(s)
        return self
    end 
    
    self.divV = function(d) 
        self.div(d)
        return self  
    end

    self.clone = function()
        return Vec3Set( self.x, self.y, self.z )
    end
    
    self.copy = function(v) 
        self.x = v.x; self.y = v.y; self.z = v.z
    end

    -- // equality/inequality
    self.eq = function(v)  return (self.x==v.x) and (self.y==v.y) and (self.z==v.z) end
    self.neq = function(v)  return not(self.eq(v)) end

    -- // --------------------------- utility member functions used in OpenSteer

    -- // return component of vector parallel to a unit basis vector
    -- // (IMPORTANT NOTE: assumes "basis" has unit magnitude (length==1))
    self.parallelComponent = function( unitBasis ) 
        local projection = self.dot ( unitBasis )
        return unitBasis.mult( projection )
    end

    -- // return component of vector perpendicular to a unit basis vector
    -- // (IMPORTANT NOTE: assumes "basis" has unit magnitude (length==1))

    self.perpendicularComponent = function( unitBasis ) 
        return self.sub( self.parallelComponent(unitBasis) )
    end 

    -- // clamps the length of a given vector to maxLength.  If the vector is
    -- // shorter its value is returned unaltered, if the vector is longer
    -- // the value returned has length of maxLength and is paralle to the
    -- // original input.
    self.truncateLength = function( maxLength)  

        local maxLengthSquared = maxLength * maxLength
        local vecLengthSquared = self.lengthSquared()
        if (vecLengthSquared <= maxLengthSquared) then
            return self
        else
            return self.mult(maxLength / math.sqrt(vecLengthSquared))
        end
    end

    -- // forces a 3d position onto the XZ (aka y=0) plane
    self.setYtoZero = function() self.y = 0.0 end

    self.setYto = function( ypos ) self.y = ypos end

    -- // rotate this vector about the global Y (up) axis by the given angle
    self.rotateAboutGlobalY = function(angle) 
        local s = math.sin(angle)
        local c = math.cos(angle)
        return Vec3Set((self.x * c) + (self.z * s), (self.y), (self.z * c) - (self.x * s))
    end

    -- // version for caching sin/cos computation
    self.rotateAboutGlobalY = function( angle, sin, cos) 
        -- // is both are zero, they have not be initialized yet
        if (sin==0 and cos==0) then 
            sin = Math.sin(angle)
            cos = Math.cos(angle)
        end 
        return Vec3Set ((self.x * cos) + (self.z * sin), (self.y), (self.z * cos) - (self.x * sin))
    end

    -- // if this position is outside sphere, push it back in by one diameter
    self.sphericalWrapAround = function( center, radius )
        local offset = self.sub( center )
        local r = offset.length()
        if (r > radius) then 
            return self.add((offset.div(r)).mult(radius * -2))
        else
            return this
        end
    end

    return self
end

function Vec3Set( X, Y, Z ) 

    local newVec = Vec3()
    newVec.set(X, Y, Z)
    return newVec
end

function Vec3FromTJS( tjsPos ) 

    local newVec = Vec3()
    newVec.set(tjsPos.x, tjsPos.y, tjsPos.z)
    return newVec
end


-- // ----------------------------------------------------------------------------
-- // names for frequently used vector constants
Vec3_zero = Vec3Set(0, 0, 0)
Vec3_side = Vec3Set(-1, 0, 0)
Vec3_up = Vec3Set(0, 1, 0)
Vec3_forward = Vec3Set(0, 0, 1)

-- // @todo Remove - use @c distance from the Vec3Utilitites header instead.
-- // XXX experimental (4-1-03 cwr): is this the right approach?  defining
-- // XXX "Vec3 distance (vec3, Vec3)" collided with STL's distance template.
Vec3_distance = function( a, b ) return(a.sub(b)).length() end

-- // return cross product a x b
function crossProduct(a, b) 
    
    local result = Vec3Set((a.y * b.z) - (a.z * b.y),
                (a.z * b.x) - (a.x * b.z),
                (a.x * b.y) - (a.y * b.x))
    return result
end

-- // ----------------------------------------------------------------------------
-- // Returns a position randomly distributed inside a sphere of unit radius
-- // centered at the origin.  Orientation will be random and length will range
-- // between 0 and 1
-- 
function RandomVectorInUnitRadiusSphere () 
    local v = Vec3();
    repeat
        v.set((frandom01()*2) - 1, (frandom01()*2) - 1, (frandom01()*2) - 1)
    until (v.length() < 1)
    return v
end


-- // ----------------------------------------------------------------------------
-- // Returns a position randomly distributed on a disk of unit radius
-- // on the XZ (Y=0) plane, centered at the origin.  Orientation will be
-- // random and length will range between 0 and 1
-- 
function randomVectorOnUnitRadiusXZDisk() 
    local v = Vec3()
    repeat
        v.set((frandom01()*2) - 1,  0,  (frandom01()*2) - 1)
    until (v.length() < 1)
    return v
end


-- // ----------------------------------------------------------------------------
-- // Returns a position randomly distributed on the surface of a sphere
-- // of unit radius centered at the origin.  Orientation will be random
-- // and length will be 1
function RandomUnitVector () 
    local v = RandomVectorInUnitRadiusSphere()
    return v.normalize()
end

-- 
-- // ----------------------------------------------------------------------------
-- // Returns a position randomly distributed on a circle of unit radius
-- // on the XZ (Y=0) plane, centered at the origin.  Orientation will be
-- // random and length will be 1
function RandomUnitVectorOnXZPlane () 
    local v = RandomVectorInUnitRadiusSphere()
    v.setYtoZero()
    return v.normalize()
end


-- // ----------------------------------------------------------------------------
-- // used by limitMaxDeviationAngle / limitMinDeviationAngle below
function vecLimitDeviationAngleUtility (insideOrOutside, source, cosineOfConeAngle, basis) 
    
    -- // immediately return zero length input vectors
    local sourceLength = source.length()
    if (sourceLength == 0) then return source end

    -- // measure the angular diviation of "source" from "basis"
    local direction = source.div(sourceLength)
    local cosineOfSourceAngle = direction.dot(basis)

    -- // Simply return "source" if it already meets the angle criteria.
    -- // (note: we hope this top "if" gets compiled out since the flag
    -- // is a constant when the function is inlined into its caller)
    if (insideOrOutside == true) then 
        -- // source vector is already inside the cone, just return it
        if (cosineOfSourceAngle >= cosineOfConeAngle) then return source end
    else 
        -- // source vector is already outside the cone, just return it
        if (cosineOfSourceAngle <= cosineOfConeAngle) then return source end
    end

    -- // find the portion of "source" that is perpendicular to "basis"
    local perp = source.perpendicularComponent(basis)

    -- // normalize that perpendicular
    local unitPerp = perp.normalize()

    -- // construct a new vector whose length equals the source vector,
    -- // and lies on the intersection of a plane (formed the source and
    -- // basis vectors) and a cone (whose axis is "basis" and whose
    -- // angle corresponds to cosineOfConeAngle)
    local perpDist = math.sqrt(1.0 - (cosineOfConeAngle * cosineOfConeAngle))
    local c0 = basis.multV( cosineOfConeAngle )
    local c1 = unitPerp.multV( perpDist )
    return (c0.add(c1)).multV( sourceLength )
end


-- // ----------------------------------------------------------------------------
-- // Enforce an upper bound on the angle by which a given arbitrary vector
-- // diviates from a given reference direction (specified by a unit basis
-- // vector).  The effect is to clip the "source" vector to be inside a cone
-- // defined by the basis and an angle.
function limitMaxDeviationAngle ( source, cosineOfConeAngle, basis) 
    return vecLimitDeviationAngleUtility (true, source, cosineOfConeAngle, basis)
end


-- // ----------------------------------------------------------------------------
-- // Enforce a lower bound on the angle by which a given arbitrary vector
-- // diviates from a given reference direction (specified by a unit basis
-- // vector).  The effect is to clip the "source" vector to be outside a cone
-- // defined by the basis and an angle.

function limitMinDeviationAngle ( source, cosineOfConeAngle, basis) 
    return vecLimitDeviationAngleUtility (false, source, cosineOfConeAngle, basis)
end


-- // ----------------------------------------------------------------------------
-- // Returns the distance between a point and a line.  The line is defined in
-- // terms of a point on the line ("lineOrigin") and a UNIT vector parallel to
-- // the line ("lineUnitTangent")
-- 
function distanceFromLine (point, lineOrigin, lineUnitTangent) 
    local offset = point.sub( lineOrigin )
    local perp = offset.perpendicularComponent (lineUnitTangent)
    return perp.length()
end

-- // ----------------------------------------------------------------------------
-- // given a vector, return a vector perpendicular to it (note that this
-- // arbitrarily selects one of the infinitude of perpendicular vectors)
findPerpendicularIn3d = function(direction) 
    -- // to be filled in:
    local quasiPerp = Vec3() --  // a direction which is "almost perpendicular"
    local result = Vec3()    --  // the computed perpendicular to be returned

    -- // three mutually perpendicular basis vectors
    local i = Vec3Set(1, 0, 0)
    local j = Vec3Set(0, 1, 0)
    local k = Vec3Set(0, 0, 1)

    -- // measure the projection of "direction" onto each of the axes
    local id = i.dot (direction)
    local jd = j.dot (direction)
    local kd = k.dot (direction)

    -- // set quasiPerp to the basis which is least parallel to "direction"
    if ((id <= jd) and (id <= kd)) then 
        quasiPerp = i               -- // projection onto i was the smallest
    else 
        if ((jd <= id) and (jd <= kd)) then 
            quasiPerp = j           -- // projection onto j was the smallest
        else
            quasiPerp = k           -- // projection onto k was the smallest
        end
    end

    -- // return the cross product (direction x quasiPerp)
    -- // which is guaranteed to be perpendicular to both of them
    result.cross(direction, quasiPerp)
    return result
end 


function nearestPointOnSegment( point, segmentPoint0, segmentPoint1 ) 
    -- // convert the test point to be "local" to ep0
    local vl = Vec3()
    vl.setV( point.sub( segmentPoint0 ))
    
    -- // find the projection of "local" onto "segmentNormal"
    local segment = Vec3()
    segment.setV( segmentPoint1.sub( segmentPoint0 ))
    local segmentLength = segment.length()
    
    -- //assert( 0 != segmentLength and "Segment mustn't be of length zero." );
    
    local segmentNormalized = Vec3()
    segmentNormalized.setV( segment.div(segmentLength) );
    local segmentProjection = segmentNormalized.dot(vl)
    
    segmentProjection = clamp( segmentProjection, 0.0, segmentLength )
    
    local result = Vec3()
    result.setV( segmentNormalized.mult( segmentProjection ))
    result =  result.add(segmentPoint0)
    return result
end

function pointToSegmentDistance ( point, segmentPoint0, segmentPoint1) 
    return Vec3.distance( point, nearestPointOnSegment( point, segmentPoint0, segmentPoint1 ) )
end 

-- // ----------------------------------------------------------------------------
-- // candidates for global utility functions
-- //
-- // dot
-- // cross
-- // length
-- // distance
-- // normalized
-- // ----------------------------------------------------------------------------

return Vec3 
