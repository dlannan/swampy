local serialStaticNumberCounter = 0

-- // SimpleVehicle adds concrete vehicle methods to SimpleVehicle_3
local SimpleStatic = function() 

    local self = {}
    -- // maintain unique serial numbers
    self.serialNumber = serialStaticNumberCounter
    serialStaticNumberCounter = serialStaticNumberCounter + 1

    self._mass = 0.0       -- // mass (defaults to unity so acceleration=force)
    self._radius = 0.0     -- // size of bounding sphere, for obstacle avoidance, etc.

    self._speed = 0.0      -- // speed along Forward direction.  Because local space
                        -- // is velocity-aligned, velocity = Forward * Speed

    self._maxForce = 0.0   -- // the maximum steering force this vehicle can apply
                        -- // (steering force is clipped to this magnitude)

    self._maxSpeed = 0.0   -- // the maximum speed this vehicle is allowed to move
                        -- // (velocity is clipped to this magnitude)

    self._curvature = 0.0
    self._lastForward = Vec3()
    self._lastPosition = Vec3()

    SteerLibrary(self)
    LocalSpace(self)

    -- // reset vehicle state
    self.reset = function() 
        -- // reset LocalSpace state
        self.resetLocalSpace(self.localspace)

        self.setMass(1.0)          -- // mass (defaults to 1 so acceleration=force)
        self.setSpeed(0.0)         -- // speed along Forward direction.

        self.setRadius(0.5)     -- // size of bounding sphere

        self.setMaxForce(0.0)   -- // steering force is clipped to this magnitude
        self.setMaxSpeed(0.0)   -- // velocity is clipped to this magnitude
    end

    -- // get/set mass
    self.mass = function() return self._mass end
    self.setMass = function(m) self._mass = m; return m end

    -- // get velocity of vehicle
    self.velocity = function() return self.forward().mult(self._speed) end

    -- // get/set speed of vehicle  (may be faster than taking mag of velocity)
    self.speed = function() return self._speed end
    self.setSpeed = function(s) self._speed = s; return s end

    -- // size of bounding sphere, for obstacle avoidance, etc.
    self.radius = function() return self._radius end
    self.setRadius = function(m) self._radius = m;return m end

    -- // get/set maxForce
    self.maxForce = function() return self._maxForce end
    self.setMaxForce = function(mf) self._maxForce = mf; return mf end

    -- // get/set maxSpeed
    self.maxSpeed = function()  return self._maxSpeed end
    self.setMaxSpeed = function(ms) self._maxSpeed = ms; return ms end

    -- // ratio of speed to max possible speed (0 slowest, 1 fastest)
    self.relativeSpeed = function()  return self.speed() / self.maxSpeed() end
    return self
end

return SimpleStatic
