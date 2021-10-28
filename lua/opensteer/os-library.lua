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
-- //
-- // SteerLibraryMixin
-- //
-- // This mixin (class with templated superclass) adds the "steering library"
-- // functionality to a given base class.  SteerLibraryMixin assumes its base
-- // class supports the AbstractVehicle interface.
-- //
-- // 10-04-04 bk:  put everything into the OpenSteer namespace
-- // 02-06-03 cwr: create mixin (from "SteerMass")
-- // 06-03-02 cwr: removed TS dependencies
-- // 11-21-01 cwr: created
-- //
-- //
-- // ----------------------------------------------------------------------------

local Vec3 = require("lua.opensteer.os-vec")

local PathIntersection = function(self) 
    self.intersect = 0
    self.distance = Number.MAX_VALUE
    self.surfacePoint = Vec3()
    self.surfaceNormal = Vec3()
    self.obstacle = SphericalObstacle()
end 

-- // ----------------------------------------------------------------------------
-- // Assign SteerLibrary functions to a mover object

function SteerLibrary( mover ) 

    -- // initial state of wander behavior
    -- // Wander behavior
    mover.WanderSide = 0.0
    mover.WanderUp = 0.0

    -- // -------------------------------------------------- steering behaviors

    mover.steerForWander = function(dt) 

        -- // random walk WanderSide and WanderUp between -1 and +1
        local speed = 12.0 * dt -- // maybe this (12) should be an argument?
        mover.WanderSide = scalarRandomWalk(mover.WanderSide, speed, -1, 1)
        mover.WanderUp   = scalarRandomWalk(mover.WanderUp,   speed, -1, 1)

        -- // return a pure lateral steering vector: (+/-Side) + (+/-Up)
        return (mover.side().mult(mover.WanderSide)).add(mover.up().mult(mover.WanderUp))
    end

    -- // Seek behavior
    mover.steerForSeek = function(target) 

        local desiredVelocity = target.sub( mover.position() )
        return desiredVelocity.sub( mover.velocity() )
    end

    -- // Flee behavior
    mover.steerForFlee = function(target) 

        local desiredVelocity = mover.position.sub(target)
        return desiredVelocity.sub( mover.velocity() )
    end

    -- // xxx proposed, experimental new seek/flee [cwr 9-16-02]
    mover.xxxsteerForFlee = function(target) 
        -- //  const Vec3 offset = position - target
        local offset = mover.position().sub( target )
        local desiredVelocity = offset.truncateLength (mover.maxSpeed ()) -- //xxxnew
        return desiredVelocity.sub( mover.velocity() )
    end

    mover.xxxsteerForSeek = function(target) 
        -- //  const Vec3 offset = target - position
        local offset = target.sub( mover.position() )
        local desiredVelocity = offset.truncateLength (mover.maxSpeed ()) -- //xxxnew
        return desiredVelocity.sub( mover.velocity() )
    end

    -- // Path Following behaviors
    mover.steerToFollowPath = function( direction, predictionTime, path) 

        -- // our goal will be offset from our path distance by this amount
        local pathDistanceOffset = direction * predictionTime * mover.speed()

        -- // predict our future position
        local futurePosition = mover.predictFuturePosition(predictionTime)

        -- // measure distance along path of our current and predicted positions
        local nowPathDistance = path.mapPointToPathDistance(mover.position())
        local futurePathDistance = path.mapPointToPathDistance(futurePosition)

        -- // are we facing in the correction direction?
        local rightway = (nowPathDistance > futurePathDistance)
        if (pathDistanceOffset > 0.0) then rightway = (nowPathDistance < futurePathDistance)  end

        -- // find the point on the path nearest the predicted future position
        -- // XXX need to improve calling sequence, maybe change to return a
        -- // XXX special path-defined object which includes two Vec3s and a 
        -- // XXX bool (onPath,tangent (ignored), withinPath)
        tangent = Vec3()
        local outside = 0.0
        local res = path.mapPointToPath(futurePosition, tangent, outside)

        -- // no steering is required if (a) our future position is inside
        -- // the path tube and (b) we are facing in the correct direction
        if ((res.outside < 0.0) and (rightway == true)) then 
            -- // all is well, return zero steering
            return Vec3_zero
        else 
            -- // otherwise we need to steer towards a target point obtained
            -- // by adding pathDistanceOffset to our current path position

            local targetPathDistance = nowPathDistance + pathDistanceOffset
            local target = path.mapPathDistanceToPoint(targetPathDistance)
        
            drawTarget(target.x, target.z, 2.0)
            
            -- // return steering to seek target on path
            return mover.steerForSeek(target)
        end
    end

    mover.steerToStayOnPath = function(predictionTime, path) 
        -- // predict our future position
        local futurePosition = mover.predictFuturePosition(predictionTime)

        -- // find the point on the path nearest the predicted future position
        local tangent = Vec3()
        local outside = 0.0
        local res = path.mapPointToPath(futurePosition, tangent, outside) 

        if (res.outside < 0.0) then
            -- // our predicted future position was in the path,
            -- // return zero steering.
            return Vec3_zero
        else 
            -- // our predicted future position was outside the path, need to
            -- // steer towards it.  Use onPath projection of futurePosition
            -- // as seek target
            return mover.steerForSeek(res.onPath)
        end
    end

    -- // ------------------------------------------------------------------------
    -- // Obstacle Avoidance behavior
    -- //
    -- // Returns a steering force to avoid a given obstacle.  The purely
    -- // lateral steering force will turn our vehicle towards a silhouette edge
    -- // of the obstacle.  Avoidance is required when (1) the obstacle
    -- // intersects the vehicle's current path, (2) it is in front of the
    -- // vehicle, and (3) is within minTimeToCollision seconds of travel at the
    -- // vehicle's current velocity.  Returns a zero vector value (Vec3::zero)
    -- // when no avoidance is required.


    mover.steerToAvoidObstacle = function( minTimeToCollision, obstacle) 
        local avoidance = obstacle.steerToAvoid(mover, minTimeToCollision)    
        return avoidance
    end

    -- // avoids all obstacles in an ObstacleGroup
    mover.steerToAvoidObstacles = function( minTimeToCollision, obstacles) 
        
        local avoidance = Vec3()
        local nearest = new PathIntersection()
        local next = new PathIntersection()
        local minDistanceToCollision = minTimeToCollision * mover.speed()
    
        next.intersect = false
        nearest.intersect = false
    
        -- // test all obstacles for intersection with my forward axis,
        -- // select the one whose point of intersection is nearest
        for k,okey in pairs(obstacles) do

            local obst = obstacles[okey]
            -- // xxx this should be a generic call on Obstacle, rather than
            -- // xxx this code which presumes the obstacle is spherical
            next = mover.findNextIntersectionWithSphere(obst, next)
            if ((nearest.intersect == false) or ((next.intersect ~= false) and (next.distance < nearest.distance))) then
                nearest = next
            end
        end
    
        -- // when a nearest intersection was found
        if ((nearest.intersect ~= false) and (nearest.distance < minDistanceToCollision)) then
            -- // compute avoidance steering force: take offset from obstacle to me,
            -- // take the component of that which is lateral (perpendicular to my
            -- // forward direction), set length to maxForce, add a bit of forward
            -- // component (in capture the flag, we never want to slow down)
            local offset = mover.position().sub( nearest.obstacle.center )
            avoidance = offset.perpendicularComponent(mover.forward())
            avoidance = avoidance.normalize()
            avoidance = avoidance.mult(mover.maxForce())
            avoidance = avoidance.add(mover.forward().mult( mover.maxForce () * 0.75) )
        end
    
        return avoidance
    end


    -- // ------------------------------------------------------------------------
    -- // Unaligned collision avoidance behavior: avoid colliding with other
    -- // nearby vehicles moving in unconstrained directions.  Determine which
    -- // (if any) other other vehicle we would collide with first, then steers
    -- // to avoid the site of that potential collision.  Returns a steering
    -- // force vector, which is zero length if there is no impending collision.


    mover.steerToAvoidNeighbors = function( minTimeToCollision, others) 

        -- // first priority is to prevent immediate interpenetration
        local separation = mover.steerToAvoidCloseNeighbors(0.0, others)
        if (separation.neq(Vec3_zero)) then return separation end

        -- // otherwise, go on to consider potential future collisions
        local steer = 0
        local threat = undefined

        -- // Time (in seconds) until the most immediate collision threat found
        -- // so far.  Initial value is a threshold: don't look more than this
        -- // many frames into the future.
        local minTime = minTimeToCollision

        -- // xxx solely for annotation
        local xxxThreatPositionAtNearestApproach = Vec3()
        local xxxOurPositionAtNearestApproach = Vec3()

        -- // for each of the other vehicles, determine which (if any)
        -- // pose the most immediate threat of collision.
        for k,v in pairs(others) do
            
            local other = v
            if(other.mover ~= mover) then
                -- // avoid when future positions are this close (or less)
                local collisionDangerThreshold = mover.radius() * 2

                -- // predicted time until nearest approach of "this" and "other"
                local time = mover.predictNearestApproachTime(other)

                -- // If the time is in the future, sooner than any other
                -- // threatened collision...
                if ((time >= 0) and (time < minTime)) then
                    -- // if the two will be close enough to collide,
                    -- // make a note of it
                    if (mover.computeNearestApproachPositions (other, time) < collisionDangerThreshold) then 
                        minTime = time
                        threat = other
                        xxxThreatPositionAtNearestApproach = mover.hisPositionAtNearestApproach
                        xxxOurPositionAtNearestApproach = mover.ourPositionAtNearestApproach
                    end
                end
            end
        end

        -- // if a potential collision was found, compute steering to avoid
        if (threat) then
            -- // parallel: +1, perpendicular: 0, anti-parallel: -1
            local parallelness = mover.forward().dot(threat.mover.forward())
            local angle = 0.707

            if (parallelness < -angle) then 
                -- // anti-parallel "head on" paths:
                -- // steer away from future threat position
                local offset = xxxThreatPositionAtNearestApproach.sub( mover.position() )
                local sideDot = offset.dot(mover.side())
                steer = 1.0 
                if(sideDot > 0) then steer = -1.0 end
            else 
                if (parallelness > angle) then
                    -- // parallel paths: steer away from threat
                    local offset = threat.mover.position().sub( mover.position() )
                    local sideDot = offset.dot(mover.side())
                    steer = 1.0 
                    if(sideDot > 0) then steer = -1.0 end
                else 
                    -- // perpendicular paths: steer behind threat
                    -- // (only the slower of the two does this)
                    if (threat.mover.speed() <= mover.speed())  then
                        local sideDot = mover.side().dot(threat.mover.velocity())
                        steer = 1.0 
                        if(sideDot > 0) then steer = -1.0 end
                    end
                end
            end
        end

        return mover.side().mult(steer)
    end


    -- // Given two vehicles, based on their current positions and velocities,
    -- // determine the time until nearest approach
    mover.predictNearestApproachTime = function(otherVehicle) 

        -- // imagine we are at the origin with no velocity,
        -- // compute the relative velocity of the other vehicle
        local myVelocity = mover.velocity()
        local otherVelocity = otherVehicle.mover.velocity()
        local relVelocity = otherVelocity.sub( myVelocity )
        local relSpeed = relVelocity.length()

        -- // for parallel paths, the vehicles will always be at the same distance,
        -- // so return 0 (aka "now") since "there is no time like the present"
        if (relSpeed == 0) then return 0 end

        -- // Now consider the path of the other vehicle in this relative
        -- // space, a line defined by the relative position and velocity.
        -- // The distance from the origin (our vehicle) to that line is
        -- // the nearest approach.

        -- // Take the unit tangent along the other vehicle's path
        local relTangent = relVelocity.div(relSpeed)

        -- // find distance from its path to origin (compute offset from
        -- // other to us, find length of projection onto path)
        local relPosition = mover.position().sub( otherVehicle.mover.position() )
        local projection = relTangent.dot(relPosition)

        return projection / relSpeed
    end

    -- // Given the time until nearest approach (predictNearestApproachTime)
    -- // determine position of each vehicle at that time, and the distance
    -- // between them
    mover.computeNearestApproachPositions = function( otherVehicle, time) 

        local    myTravel = mover.forward().mult( mover.speed () * time )
        local otherTravel = otherVehicle.mover.forward().mult( otherVehicle.mover.speed() * time )
    
        local    myFinal = mover.position().add( myTravel )
        local otherFinal = otherVehicle.mover.position().add( otherTravel )
    
        -- // xxx for annotation
        mover.ourPositionAtNearestApproach = myFinal
        mover.hisPositionAtNearestApproach = otherFinal
    
        return Vec3_distance(myFinal, otherFinal)
    end

    -- /// XXX globals only for the sake of graphical annotation
    mover.hisPositionAtNearestApproach = Vec3()
    mover.ourPositionAtNearestApproach = Vec3()

    -- // ------------------------------------------------------------------------
    -- // avoidance of "close neighbors" -- used only by steerToAvoidNeighbors
    -- //
    -- // XXX  Does a hard steer away from any other agent who comes withing a
    -- // XXX  critical distance.  Ideally this should be replaced with a call
    -- // XXX  to steerForSeparation.

    mover.steerToAvoidCloseNeighbors = function( minSeparationDistance, others)
        -- // for each of the other vehicles...
        for k,v in pairs(others) do
            local other = v
            if (other.mover ~= mover)  then
                local sumOfRadii = mover.radius() + other.mover.radius()
                local minCenterToCenter = minSeparationDistance + sumOfRadii
                local offset = other.mover.position().sub( mover.position() )
                local currentDistance = offset.length()

                if (currentDistance < minCenterToCenter) then
                    return (offset.neg()).perpendicularComponent(mover.forward())
                end
            end
        end

        -- // otherwise return zero
        return Vec3_zero
    end


    -- // ------------------------------------------------------------------------
    -- // used by boid behaviors

    mover.inBoidNeighborhood = function( otherVehicle, minDistance, maxDistance, cosMaxAngle) 
        
        if (otherVehicle.mover == mover) then
            return false
        else 
            local offset = otherVehicle.mover.position().sub( mover.position() )
            local distanceSquared = offset.lengthSquared()
    
            -- // definitely in neighborhood if inside minDistance sphere
            if (distanceSquared < (minDistance * minDistance)) then 
                return true
            else 
                -- // definitely not in neighborhood if outside maxDistance sphere
                if (distanceSquared > (maxDistance * maxDistance))  then
                    return false
                else 
                    -- // otherwise, test angular offset from forward axis
                    local unitOffset = offset.divV( math.sqrt(distanceSquared) )
                    local forwardness = mover.forward().dot(unitOffset)
                    return forwardness > cosMaxAngle
                end
            end
        end
    end

    -- // ------------------------------------------------------------------------
    -- // Separation behavior -- determines the direction away from nearby boids

    mover.steerForSeparation = function( maxDistance, cosMaxAngle, flock) 

        -- // steering accumulator and count of neighbors, both initially zero
        local steering = Vec3()
        local neighbors = 0

        -- // for each of the other vehicles...        
        for i=0, flock.length-1 do
            local otherVehicle = flock[i]
            if (mover.inBoidNeighborhood (otherVehicle, mover.radius()*3, maxDistance, cosMaxAngle)) then
                -- // add in steering contribution
                -- // (opposite of the offset direction, divided once by distance
                -- // to normalize, divided another time to get 1/d falloff)
                local offset = otherVehicle.mover.position().sub( mover.position() )
                local distanceSquared = offset.dot(offset)
                steering = steering.add(offset.div(-distanceSquared))

                -- // count neighbors
                neighbors=neighbors+1
            end
        end

        -- // divide by neighbors, then normalize to pure direction
        -- // bk: Why dividing if you normalize afterwards?
        -- //     As long as normilization tests for @c 0 we can just call normalize
        -- //     and safe the branching if.
        -- /*
        -- if (neighbors > 0) then
        --     steering /= neighbors
        --     steering = steering.normalize()
        -- end
        -- */
        steering = steering.normalize()
        return steering
    end


    -- // ------------------------------------------------------------------------
    -- // Alignment behavior

    mover.steerForAlignment = function( maxDistance, cosMaxAngle, flock) 

        -- // steering accumulator and count of neighbors, both initially zero
        local steering = Vec3()
        local neighbors = 0

        -- // for each of the other vehicles...
        for i=0, flock.length-1 do
            local otherVehicle = flock[i]
            if (mover.inBoidNeighborhood (otherVehicle, mover.radius()*3, maxDistance, cosMaxAngle))  then
                -- // accumulate sum of neighbor's heading
                steering = steering.add(otherVehicle.mover.forward())
                -- // count neighbors
                neighbors=neighbors+1
            end
        end

        -- // divide by neighbors, subtract off current heading to get error-
        -- // correcting direction, then normalize to pure direction
        if (neighbors > 0) then steering = ((steering.div(neighbors)).sub(mover.forward())).normalize() end
        return steering
    end

    -- // ------------------------------------------------------------------------
    -- // Cohesion behavior

    mover.steerForCohesion = function( maxDistance, cosMaxAngle, flock) 

        -- // steering accumulator and count of neighbors, both initially zero
        local steering = Vec3()
        local neighbors = 0

        -- // for each of the other vehicles...
        for i=0,flock.length-1 do
            local otherVehicle = flock[i]
            if (mover.inBoidNeighborhood (otherVehicle, mover.radius()*3, maxDistance, cosMaxAngle)) then
                -- // accumulate sum of neighbor's positions
                steering = steering.add(otherVehicle.mover.position())

                -- // count neighbors
                neighbors=neighbors+1
            end
        end

        -- // divide by neighbors, subtract off current position to get error-
        -- // correcting direction, then normalize to pure direction
        if (neighbors > 0) then steering = ((steering.div(neighbors)).sub(mover.forward())).normalize() end

        return steering
    end

    -- // ------------------------------------------------------------------------
    -- // pursuit of another vehicle (& version with ceiling on prediction time)

    mover.steerForPursuit = function( quarry)
        return steerForPursuit (quarry, Number.MAX_VALUE)
    end

    mover.steerForPursuit = function( quarry, maxPredictionTime ) 
        
        -- // offset from this to quarry, that distance, unit vector toward quarry
        local offset = quarry.position().sub( mover.position() )
        local distance = offset.length()
        local unitOffset = offset.dinv( distance )

        -- // how parallel are the paths of "this" and the quarry
        -- // (1 means parallel, 0 is pependicular, -1 is anti-parallel)
        local parallelness = mover.forward().dot(quarry.forward())

        -- // how "forward" is the direction to the quarry
        -- // (1 means dead ahead, 0 is directly to the side, -1 is straight back)
        local forwardness = mover.forward().dot(unitOffset)

        local directTravelTime = distance / mover.speed()
        local f = intervalComparison(forwardness,  -0.707, 0.707)
        local p = intervalComparison(parallelness, -0.707, 0.707)

        local timeFactor = 0 -- // to be filled in below

        -- // Break the pursuit into nine cases, the cross product of the
        -- // quarry being [ahead, aside, or behind] us and heading
        -- // [parallel, perpendicular, or anti-parallel] to us.
        if(f==1) then 
            if(p == 1) then          -- // ahead, parallel
                timeFactor = 4
            elseif(p==0) then        -- // ahead, perpendicular
                timeFactor = 1.8
            elseif(p==-1) then       -- // ahead, anti-parallel
                timeFactor = 0.85
            end

        elseif (f==0) then 
            
            if(p==1) then        -- // aside, parallel
                timeFactor = 1
            elseif(p ==0) then           -- // aside, perpendicular
                timeFactor = 0.8
            elseif(p == -1) then          -- // aside, anti-parallel
                timeFactor = 4
            end
            
        elseif(f == -1) then
            if(p == 1) then           -- // behind, parallel
                timeFactor = 0.5
            elseif(p == 0) then           -- // behind, perpendicular
                timeFactor = 2
            elseif(p == -1) then          -- // behind, anti-parallel
                timeFactor = 2
            end
        end

        -- // estimated time until intercept of quarry
        local et = directTravelTime * timeFactor

        -- // xxx experiment, if kept, this limit should be an argument
        local etl = et
        if (et > maxPredictionTime) then etl = maxPredictionTime end 

        -- // estimated position of quarry at intercept
        local target = quarry.predictFuturePosition(etl)

        -- // annotation
        -- //this->annotationLine (position(), target, gaudyPursuitAnnotation ? color : gGray40)

        return mover.steerForSeek(target)
    end

    -- // ------------------------------------------------------------------------
    -- // evasion of another vehicle

    mover.steerForEvasion = function( menace, maxPredictionTime) 

        -- // offset from this to menace, that distance, unit vector toward menace
        local offset = mover.menace.position.sub( mover.position )
        local distance = offset.length()

        local roughTime = distance / menace.speed()
        local predictionTime = roughTime
        if(roughTime > maxPredictionTime) then predictionTime = maxPredictionTime end

        local target = menace.predictFuturePosition(predictionTime)
        return steerForFlee (target)
    end

    -- // ------------------------------------------------------------------------
    -- // tries to maintain a given speed, returns a maxForce-clipped steering
    -- // force along the forward/backward axis

    mover.steerForTargetSpeed = function(targetSpeed) 
        local mf = mover.maxForce()
        local speedError = targetSpeed - mover.speed()
        return mover.forward().mult( clip(speedError, -mf, mf) )    
    end

    mover.findNextIntersectionWithSphere = function( obs ) 
        -- // xxx"SphericalObstacle& obs" should be "const SphericalObstacle&
        -- // obs" but then it won't let me store a pointer to in inside the
        -- // PathIntersection

        -- // This routine is based on the Paul Bourke's derivation in:
        -- //   Intersection of a Line and a Sphere (or circle)
        -- //   http:-- //www.swin.edu.au/astronomy/pbourke/geometry/sphereline/

        local b, c, d, p, q, s = nil
        local lc = Vec3()
        local intersection = new PathIntersection()

        -- // initialize pathIntersection object
        intersection.intersect = false
        intersection.obstacle = obs

        -- // find "local center" (lc) of sphere in boid's coordinate space
        lc = mover.localizePosition(obs.center)

        -- // computer line-sphere intersection parameters
        b = -2.0 * lc.z
        c = square(lc.x) + square(lc.y) + square(lc.z) - square(obs.radius + mover.radius())
        d = (b * b) - (4.0 * c)

        -- // when the path does not intersect the sphere
        if (d < 0.0) then return intersection end

        -- // otherwise, the path intersects the sphere in two points with
        -- // parametric coordinates of "p" and "q".
        -- // (If "d" is zero the two points are coincident, the path is tangent)
        s = math.sqrt(d)
        p = (-b + s) / 2.0
        q = (-b - s) / 2.0

        -- // both intersections are behind us, so no potential collisions
        if ((p < 0.0) and (q < 0.0)) then return intersection end 

        -- // at least one intersection is in front of us
        intersection.intersect = true
        if((p > 0.0) and (q > 0.0)) then
            -- // both intersections are in front of us, find nearest one
            intersection.distance =  q
            if (p < q) then intersection.distance = p end
        else 
            -- // otherwise only one intersections is in front, select it
            intersection.distance = q
            if (p > 0.0) then intersection.distance = p end
        end
        return intersection
    end

    -- // ----------------------------------------------------------- utilities
    -- // XXX these belong somewhere besides the steering library
    -- // XXX above AbstractVehicle, below SimpleVehicle
    -- // XXX ("utility vehicle"?)

    -- // xxx cwr experimental 9-9-02 -- names OK?
    mover.isAhead = function(target)  return isAhead(target, 0.707) end
    mover.isAside = function(target)  return isAside (target, 0.707) end
    mover.isBehind = function(target) return isBehind (target, -0.707) end

    mover.isAhead = function(target, cosThreshold) 
        local targetDirection = target.sub( mover.position()).normalize()
        return mover.forward().dot(targetDirection) > cosThreshold
    end
    mover.isAside = function(target, cosThreshold) 
        local targetDirection = target.sub( mover.position () ).normalize ()
        local dp = mover.forward().dot(targetDirection)
        return (dp < cosThreshold) and (dp > -cosThreshold)
    end
    mover.isBehind = function( target, cosThreshold) 
        local targetDirection = target.sub( mover.position()).normalize ()
        return mover.forward().dot(targetDirection) < cosThreshold
    end
end

return SteerLibrary

