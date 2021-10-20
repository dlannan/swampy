
local Vec3 = require("lua.opensteer.os-vec")
local SteerLibrary = require("lua.opensteer.os-library")
local LocalSpace = require("lua.opensteer.os-localspace")

local serialNumberCounter = 0

-- -- // SimpleVehicle adds concrete vehicle methods to SimpleVehicle_3
local SimpleVehicle = function() 

    local self = {}
    -- -- // maintain unique serial numbers
    self.serialNumber = serialNumberCounter
    serialNumberCounter = serialNumberCounter + 1

    self._mass = 0.0 --       -- // mass (defaults to unity so acceleration=force)
    self._radius = 0.0 --     -- // size of bounding sphere, for obstacle avoidance, etc.

    self._speed = 0.0 --      -- // speed along Forward direction.  Because local space
                      --      -- // is velocity-aligned, velocity = Forward * Speed

    self._maxForce = 0.0 --   -- // the maximum steering force this vehicle can apply
                         --   -- // (steering force is clipped to this magnitude)

    self._maxSpeed = 0.0 --   -- // the maximum speed this vehicle is allowed to move
                         --   -- // (velocity is clipped to this magnitude)

    self._curvature = 0.0
    self._lastForward = Vec3()
    self._lastPosition = Vec3()
    self._smoothedPosition = Vec3()
    self._smoothedCurvature = 0.0
    self._smoothedAcceleration = Vec3()

    SteerLibrary(self)
    LocalSpace(self)

    -- -- // reset vehicle state
    self.reset = function() 
        -- -- // reset LocalSpace state
        self.resetLocalSpace(self.localspace)

        self.setMass(1.0)          -- -- // mass (defaults to 1 so acceleration=force)
        self.setSpeed(0.0)         -- -- // speed along Forward direction.

        self.setRadius(0.5)     -- -- // size of bounding sphere

        self.setMaxForce(0.1)   -- -- // steering force is clipped to this magnitude
        self.setMaxSpeed(1.0)   -- -- // velocity is clipped to this magnitude

        -- -- // reset bookkeeping to do running averages of these quanities
        self.resetSmoothedPosition()
        self.resetSmoothedCurvature()
        self.resetSmoothedAcceleration()
    end

    -- -- // get/set mass
    self.mass = function() return self._mass end
    self.setMass = function(m) self._mass = m; return m end

    -- -- // get velocity of vehicle
    self.velocity = function() return self.forward().mult(self._speed) end 

    -- -- // get/set speed of vehicle  (may be faster than taking mag of velocity)
    self.speed = function()  return self._speed end
    self.setSpeed = function(s)  self._speed = s; return s end

    -- -- // size of bounding sphere, for obstacle avoidance, etc.
    self.radius = function()  return self._radius end
    self.setRadius = function(m) self._radius = m; return m end

    -- -- // get/set maxForce
    self.maxForce = function() return self._maxForce end 
    self.setMaxForce = function(mf) self._maxForce = mf; return mf end

    -- -- // get/set maxSpeed
    self.maxSpeed = function()  return self._maxSpeed end 
    self.setMaxSpeed = function(ms) self._maxSpeed = ms; return ms end 

    -- -- // ratio of speed to max possible speed (0 slowest, 1 fastest)
    self.relativeSpeed = function() return self.speed() / self.maxSpeed() end

    -- -- // apply a given steering force to our momentum,
    -- -- // adjusting our orientation to maintain velocity-alignment.
    self.applySteeringForce = function( force, elapsedTime )

        local adjustedForce = self.adjustRawSteeringForce(force, elapsedTime)

        -- -- // enforce limit on magnitude of steering force
        local clippedForce = adjustedForce.truncateLength( self.maxForce() )
    
        -- -- // compute acceleration and velocity
        local newAcceleration = clippedForce.div( self.mass() )
        local newVelocity = self.velocity()
    
        -- -- // damp out abrupt changes and oscillations in steering acceleration
        -- -- // (rate is proportional to time step, then clipped into useful range)
        if (elapsedTime > 0.0) then 
            local smoothRate = clip(9.0 * elapsedTime, 0.15, 0.4)
            self._smoothedAcceleration = blendIntoAccumulatorV(smoothRate, newAcceleration, self._smoothedAcceleration)
        end

        -- -- // Euler integrate (per frame) acceleration into velocity
        local accel = self._smoothedAcceleration.mult( elapsedTime )
        newVelocity = newVelocity.add( accel )

        -- -- // enforce speed limit
        newVelocity = newVelocity.truncateLength( self.maxSpeed ())

        -- -- // update Speed
        self.setSpeed(newVelocity.length());
    
        -- -- // Euler integrate (per frame) velocity into position
        self.setPosition(self.position().add(newVelocity.mult(elapsedTime)))
    
        -- -- // regenerate local space (by default: align vehicle's forward axis with
        -- -- // new velocity, but this behavior may be overridden by derived classes.)
        self.regenerateLocalSpace(newVelocity, elapsedTime)

        -- -- // maintain path curvature information
        self.measurePathCurvature(elapsedTime)
    
        -- -- // running average of recent positions
        self._smoothedPosition = blendIntoAccumulatorV(elapsedTime * 0.06, self.position(), self._smoothedPosition)
    end 

    -- -- // the default version: keep FORWARD parallel to velocity, change
    -- -- // UP as little as possible.
    self.regenerateLocalSpace = function( newVelocity, elapsedTime) 
        -- -- // adjust orthonormal basis vectors to be aligned with new velocity
        if (self.speed() > 0.0) then self.regenerateOrthonormalBasisUF(newVelocity.div(self.speed())) end
    end

    -- // alternate version: keep FORWARD parallel to velocity, adjust UP
    -- // according to a no-basis-in-reality "banking" behavior, something
    -- // like what birds and airplanes do.  (XXX experimental cwr 6-5-03)
    self.regenerateLocalSpaceForBanking = function( newVelocity, elapsedTime ) 
        -- // the length of this global-upward-pointing vector controls the vehicle's
        -- // tendency to right itself as it is rolled over from turning acceleration
        local globalUp = Vec3Set(0, 0.2, 0);

        -- // acceleration points toward the center of local path curvature, the
        -- // length determines how much the vehicle will roll while turning
        local accelUp = self._smoothedAcceleration.mult( 0.05 );

        -- // combined banking, sum of UP due to turning and global UP
        local bankUp = accelUp.add( globalUp );

        -- // blend bankUp into vehicle's UP basis vector
        local smoothRate = elapsedTime * 3;
        local tempUp = self.up();
        tempUp = blendIntoAccumulatorV(smoothRate, bankUp, tempUp);
        self.localspace.setUp(tempUp.normalize());

    -- //  annotationLine (position(), position() + (globalUp * 4), gWhite);  -- // XXX
    -- //  annotationLine (position(), position() + (bankUp   * 4), gOrange); -- // XXX
    -- //  annotationLine (position(), position() + (accelUp  * 4), gRed);    -- // XXX
    -- //  annotationLine (position(), position() + (up ()    * 1), gYellow); -- // XXX

        -- // adjust orthonormal basis vectors to be aligned with new velocity
        if (self.speed() > 0) then regenerateOrthonormalBasisUF (newVelocity.div(self.speed())) end
    end

    -- // adjust the steering force passed to applySteeringForce.
    -- // allows a specific vehicle class to redefine this adjustment.
    -- // default is to disallow backward-facing steering at low speed.
    -- // xxx experimental 8-20-02
    self.adjustRawSteeringForce = function( force, deltaTime ) 

        local maxAdjustedSpeed = 0.2 * self.maxSpeed();
        if ((self.speed() > maxAdjustedSpeed) or force.eq(Vec3_zero) ) then 
            return force
        else 
            local range = self.speed() / maxAdjustedSpeed
            -- // const float cosine = interpolate (pow (range, 6), 1.0f, -1.0f)
            -- // const float cosine = interpolate (pow (range, 10), 1.0f, -1.0f)
            -- // const float cosine = interpolate (pow (range, 20), 1.0f, -1.0f)
            -- // const float cosine = interpolate (pow (range, 100), 1.0f, -1.0f)
            -- // const float cosine = interpolate (pow (range, 50), 1.0f, -1.0f)
            local cosine = interpolate(math.pow (range, 20), 1.0, -1.0)
            return limitMaxDeviationAngle (force, cosine, self.forward())
        end        
    end

    -- // apply a given braking force (for a given dt) to our momentum.
    -- // xxx experimental 9-6-02
    self.applyBrakingForce = function( rate, deltaTime ) 
        local rawBraking = self.speed () * rate
        local clipBraking = self.maxForce()
        if (rawBraking < self.maxForce ()) then clipBraking = rawBraking end
        self.setSpeed (self.speed () - (clipBraking * deltaTime))
    end

    -- // predict position of this vehicle at some time in the future
    -- // (assumes velocity remains constant)
    self.predictFuturePosition = function( predictionTime ) 
        return self.position().add( self.velocity().mult(predictionTime) )
    end

    -- // get instantaneous curvature (since last update)
    self.curvature = function() return self._curvature end

    -- // get/reset smoothedCurvature, smoothedAcceleration and smoothedPosition
    self.smoothedCurvature = function() return self._smoothedCurvature end
    self.resetSmoothedCurvature = function( value ) 
        value = value or 0
        self._lastForward.setV( Vec3_zero )
        self._lastPosition.setV( Vec3_zero )
        self._smoothedCurvature, self._curvature = value
        return value
    end
    self.smoothedAcceleration = function() return self._smoothedAcceleration end
    self.resetSmoothedAcceleration = function(value) 
        if(not value) then value = Vec3_zero end
        self._smoothedAcceleration.setV(value)
        return self._smoothedAcceleration
    end
    self.smoothedPosition = function() return self._smoothedPosition end
    self.resetSmoothedPosition = function( value ) 
        if(value == nil) then value = Vec3_zero end
        self._smoothedPosition.setV(value)
        return self._smoothedPosition
    end

    -- // give each vehicle a unique number
    self.serialNumber = 0.0

    -- // set a random "2D" heading: set local Up to global Y, then effectively
    -- // rotate about it by a random angle (pick random forward, derive side).
    self.randomizeHeadingOnXZPlane = function() 
        self.setUp(Vec3.up)
        self.setForward(RandomUnitVectorOnXZPlane())
        self.setSide(self.localRotateForwardToSide(self.forward()))
    end

    self.setHeading = function(heading) 
        self.setUp(Vec3.up)
        self.setForward( Vec3Set( math.cos(heading), 0.0, math.sin(heading) ))
        self.setSide(self.localRotateForwardToSide(self.forward()))
    end

    -- // measure path curvature (1/turning-radius), maintain smoothed version
    self.measurePathCurvature = function( elapsedTime )

        if (elapsedTime > 0) then 
            local dP = self._lastPosition.sub( self.position() )
            local dF = (self._lastForward.sub( self.forward() )).div( dP.length() )
            local lateral = dF.perpendicularComponent( self.forward() )
            local sign = -1.0
            if (lateral.dot(self.side()) < 0) then sign = 1.0 end
            self._curvature = lateral.length() * sign
            self._smoothedCurvature = blendIntoAccumulator(elapsedTime * 4.0, self._curvature, self._smoothedCurvature)
            self._lastForward = self.forward()
            self._lastPosition = self.position()
        end
    end
    return self
end

return SimpleVehicle