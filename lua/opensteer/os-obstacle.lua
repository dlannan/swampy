-- // ----------------------------------------------------------------------------
-- // Obstacle: a pure virtual base class for an abstract shape in space, to be
-- // used with obstacle avoidance.
-- //
-- // XXX this should define generic methods for querying the obstacle shape

-- // ----------------------------------------------------------------------------
-- // SphericalObstacle a simple concrete type of obstacle

function SphericalObstacle1 ( r,  c ) 
    local so = new SphericalObstacle()
    so.center = c
    so.radius = r
    return so
end

local SphericalObstacle = function()

    local self = {}
    self.radius = 1.0
    self.center = new Vec3()
    self._seenFrom = nil

    -- // constructors
    self.seenFrom = function() return _seenFrom end
    self.setSeenFrom = function( s) self._seenFrom = s end

    -- // XXX 4-23-03: Temporary work around (see comment above)
    -- //
    -- // Checks for intersection of the given spherical obstacle with a
    -- // volume of "likely future vehicle positions": a cylinder along the
    -- // current path, extending minTimeToCollision seconds along the
    -- // forward axis from current position.
    -- //
    -- // If they intersect, a collision is imminent and this function returns
    -- // a steering force pointing laterally away from the obstacle's center.
    -- //
    -- // Returns a zero vector if the obstacle is outside the cylinder
    -- //
    -- // xxx couldn't this be made more compact using localizePosition?

    self.steerToAvoid = function( v, minTimeToCollision) 

        -- // minimum distance to obstacle before avoidance is required
        local minDistanceToCollision = minTimeToCollision * v.speed()
        local minDistanceToCenter = minDistanceToCollision + self.radius

        -- // contact distance: sum of radii of obstacle and vehicle
        local totalRadius = self.radius + v.radius()

        -- // obstacle center relative to vehicle position
        local localOffset = self.center.sub( v.position() )

        -- // distance along vehicle's forward axis to obstacle's center
        local forwardComponent = localOffset.dot (v.forward())
        local forwardOffset = forwardComponent.mult( v.forward())

        -- // offset from forward axis to obstacle's center
        local offForwardOffset = localOffset.sub(forwardOffset)

        -- // test to see if sphere overlaps with obstacle-free corridor
        local inCylinder = offForwardOffset.length() < totalRadius
        local nearby = forwardComponent < minDistanceToCenter
        local inFront = forwardComponent > 0

        -- // if all three conditions are met, steer away from sphere center
        if (inCylinder and nearby and inFront) then 
            return offForwardOffset.mult( -1 )
        else 
            return Vec3.zero
        end
    end
    return self
end 

return SphericalObstacle