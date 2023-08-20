
local gapJumpHull = Vector( 5, 5, 5 )
local down = Vector( 0, 0, -1 )
local vector_up = Vector( 0, 0, 1 )

local function TraceHit( tr )
    return tr.Hit-- or !tr.HitNoDraw and tr.HitTexture!="**empty**"
end

local function DirToPos( startPos, endPos )
    if not startPos then return end
    if not endPos then return end

    return ( endPos - startPos ):GetNormalized()

end

local _CurTime = CurTime

-- should we assume that we will break this upon doing our path?
function ENT:hitBreakable( traceStruct, traceResult, skipDistCheck )
    if traceResult.MatType == MAT_GLASS and ( skipDistCheck or traceResult.HitPos:DistToSqr( traceStruct.endpos ) < 75^2 ) then
        local potentialGlass = traceResult.Entity
        if IsValid( potentialGlass ) then
            local Class = potentialGlass:GetClass()
            local isSurf = Class == "func_breakable_surf"
            local hasHealth = isnumber( potentialGlass:Health() ) and potentialGlass:Health() < 2000

            local hpOrBreakableSurf = isSurf or hasHealth

            if hpOrBreakableSurf then
                return true

            else
                return false

            end
        -- we cant break it if its not an entity!
        else
            return nil

        end
    -- hey its breakable!
    elseif IsValid( traceResult.Entity ) and not traceResult.HitWorld and self:memorizedAsBreakable( traceResult.Entity ) then
        return true

    else
        return nil

    end
end


--[[------------------------------------
    Name: NEXTBOT:StuckCheck
    Desc: (INTERNAL) Updates bot stuck status.
    Arg1: 
    Ret1: 
--]]------------------------------------
function ENT:StuckCheck()
    if _CurTime() >= self.m_StuckTime then
        self.m_StuckTime = _CurTime() + math.Rand( 0.15, 0.50 )

        local pos = self:GetPos()

        if self.m_StuckPos ~= pos then
            self.m_StuckPos = pos
            self.m_StuckTime2 = 0

            if self.m_Stuck then
                self:OnUnStuck()
            end
        else
            local b1,b2 = self:GetCollisionBounds()

            if not self.loco:IsOnGround() or self.isUnstucking or self.loco:GetVelocity():Length2DSqr() < 5^2 then
                -- prevents getting stuck in air, and getting stuck in doors that slide into us
                b1.x = b1.x - 4
                b1.y = b1.y - 4
                b2.x = b2.x + 4
                b2.y = b2.y + 4

            end

            local tr = util.TraceHull( {
                start = pos,
                endpos = pos,
                filter = function( ent )
                    return ent ~= self and not self:StuckCheckShouldIgnoreEntity( ent )
                end,
                mask = self:GetSolidMask(),
                collisiongroup = self:GetCollisionGroup(),
                mins = b1,
                maxs = b2,
            } )

            if not self.m_Stuck then
                if TraceHit( tr ) then
                    self.m_StuckTime2 = self.m_StuckTime2 + math.Rand( 0.5, 0.75 )

                    if self.m_StuckTime2 >= 1 then -- changed from 5 to 1
                        self:OnStuck()
                    end
                else
                    self.m_StuckTime2 = 0
                end
            else
                if not TraceHit( tr ) then
                    self:OnUnStuck()
                end
            end
        end
    end
end

function ENT:GetFootstepSoundTime()
    local time = 400
    local speed = self.loco:GetVelocity():Length()

    time = time - ( speed * 0.6 )

    if self:IsCrouching() then
        time = time + 100
    end

    return time
end

--[[------------------------------------
    Name: NEXTBOT:ProcessFootsteps
    Desc: (INTERNAL) Called to update footstep data.
    Arg1: 
    Ret1: 
--]]------------------------------------
function ENT:ProcessFootsteps()
    if not self.loco:IsOnGround() then return end

    local time = self.m_FootstepTime
    local curspeed = self:GetCurrentSpeed()

    if curspeed > self.WalkSpeed * 0.5 and _CurTime() - time >= self:GetFootstepSoundTime() / 1000 then
        local walk = curspeed < self.RunSpeed

        local tr = util.TraceEntity( {
            start = self:GetPos(),
            endpos = self:GetPos() - Vector( 0, 0, 5 ),
            filter = self,
            mask = self:GetSolidMask(),
            collisiongroup = self:GetCollisionGroup(),
        }, self )

        local surface = util.GetSurfaceData( tr.SurfaceProps )
        local vol = 1
        if surface then
            local m = surface.material

            if m == MAT_CONCRETE then
                vol = walk and 0.8 or 1
            elseif m == MAT_METAL then
                vol = walk and 0.8 or 1
            elseif m == MAT_DIRT then
                vol = walk and 0.4 or 0.6
            elseif m == MAT_VENT then
                vol = 1
            elseif m == MAT_GRATE then
                vol = walk and 0.6 or 0.8
            elseif m == MAT_TILE then
                vol = walk and 0.8 or 1
            elseif m == MAT_SLOSH then
                vol = walk and 0.8 or 1
            end

        end

        self:MakeFootstepSound( vol, tr.SurfaceProps )
    end
end

function ENT:MakeFootstepSound( volume, surface, mul )
    mul = mul or 1
    local foot = self.m_FootstepFoot
    self.m_FootstepFoot = not foot
    self.m_FootstepTime = _CurTime()

    if not surface then
        local tr = util.TraceEntity( {
            start = self:GetPos(),
            endpos = self:GetPos() - Vector( 0, 0, 5 ),
            filter = self,
            mask = self:GetSolidMask(),
            collisiongroup = self:GetCollisionGroup(),
        }, self )

        surface = tr.SurfaceProps
    end

    -- do this before the surface check
    local intVolume = volume or 1
    local clompingLvl = 86
    if self:GetVelocity():LengthSqr() < self.RunSpeed^2 then
        clompingLvl = 76

    end
    clompingLvl = clompingLvl * mul

    self:EmitSound( "npc/zombie_poison/pz_left_foot1.wav", clompingLvl, math.random( 20, 30 ) / mul, intVolume / 1.5, CHAN_STATIC )

    if not surface then return end

    surface = util.GetSurfaceData( surface )
    if not surface then return end

    local sound = foot and surface.stepRightSound or surface.stepLeftSound

    if sound then
        local pos = self:GetPos()

        local filter = RecipientFilter()
        filter:AddAllPlayers()

        if not self:OnFootstep( pos, foot, sound, volume, filter ) then

            self.stepSoundPatches = self.stepSoundPatches or {}

            local stepSound = self.stepSoundPatches[sound]
            if not stepSound then
                stepSound = CreateSound( self, sound, filter )
                self.stepSoundPatches[sound] = stepSound
            end
            stepSound:Stop()
            stepSound:SetSoundLevel( 88 * mul )
            stepSound:PlayEx( intVolume, 85 * mul )

        end
    end

end

function ENT:isUnderWater()
    local currentNavArea = self:GetCurrentNavArea() 
    if not currentNavArea then return false end
    if not currentNavArea:IsValid() then return false end
    return currentNavArea:IsUnderwater()

end

function ENT:getCachedPathSegments()
    local path = self:GetPath()
    local pathEnd = path:GetEnd()
    local lastEnd = self.lastCachedPathEnd or Vector()
    if pathEnd == lastEnd then return self.cachedPathSegments end

    local segments = path:GetAllSegments()
    self.cachedPathSegments = segments
    self.lastCachedPathEnd = pathEnd
    return segments

end

function ENT:getMaxPathCurvature( passArea, extentDistance )

    if not self:PathIsValid() then return 0 end

    extentDistance = extentDistance or 400

    local myNavArea = passArea or self:GetCurrentNavArea()

    local maxCurvature = 0
    local pathSegs = self:getCachedPathSegments()
    local distance = 0
    local wasCurrentSegment = nil

    -- go until we get past extent distance

    for _, currSegment in ipairs( pathSegs ) do
        if currSegment.area == myNavArea or wasCurrentSegment then
            wasCurrentSegment = true

            distance = distance + currSegment.length
            if distance >= extentDistance then
                break

            end
            local absCurvature = math.abs( currSegment.curvature )
            if absCurvature > maxCurvature then
                maxCurvature = absCurvature
            end
        end
    end
    return maxCurvature

end

function ENT:GetNextPathArea( refArea, offset, visCheck )
    if not self:PathIsValid() then return end
    local targetReferenceArea = refArea or self:GetCurrentNavArea()
    if not targetReferenceArea then return end
    local pathSegs = self:getCachedPathSegments()
    local myPathPoint = self:GetPath():GetCurrentGoal()
    local myShootPos = self:GetShootPos()
    local goalArea = NULL
    local goalPathPoint = nil
    local isNextArea = nil
    for _, pathPoint in ipairs( pathSegs ) do -- find the real next area
        if isNextArea == true and pathPoint.area ~= myPathPoint.area then
            -- stop when next is not visible
            if visCheck and goalArea and not util.PosCanSeeComplex( myShootPos, pathPoint.pos + vector_up * 25, self ) then
                break

            end
            goalArea = pathPoint.area
            goalPathPoint = pathPoint
            if offset and offset >= 1 then
                offset = offset + -1
            else
                --debugoverlay.Cross( pathPoint.area:GetCenter(), 40, 0.1, Color( 0,0,255 ), true )
                break
            end
        elseif pathPoint.area == targetReferenceArea or pathPoint.area == myPathPoint.area then
            myPathPoint = pathPoint
            isNextArea = true
            --debugoverlay.Cross( pathPoint.area:GetCenter(), 0.1, 10, Color( 255,0,0 ), true )
        end
    end
    return goalArea, goalPathPoint
end

function ENT:ReallyAnger( time )
    local reallyAngryTime = self.terminator_ReallyAngryTime or _CurTime()
    self.terminator_ReallyAngryTime = math.max( reallyAngryTime + time, _CurTime() )

end

function ENT:IsReallyAngry()
    local reallyAngryTime = self.terminator_ReallyAngryTime or _CurTime()
    local checkIsReallyAngry = self.terminator_CheckIsReallyAngry or 0

    if checkIsReallyAngry < _CurTime() then
        self.terminator_CheckIsReallyAngry = _CurTime() + 1
        local enemy = self:GetEnemy()

        if enemy and enemy.isTerminatorHunterKiller then
            reallyAngryTime = reallyAngryTime + 60

        elseif self:Health() < ( self:GetMaxHealth() * 0.5 ) then
            reallyAngryTime = reallyAngryTime + 10

        elseif self.isUnstucking then
            reallyAngryTime = reallyAngryTime + 20

        elseif self:inSeriousDanger() then
            reallyAngryTime = reallyAngryTime + 60

        end
    end

    local reallyAngry = reallyAngryTime > _CurTime()
    self.terminator_ReallyAngryTime = math.max( reallyAngryTime, _CurTime() )

    return reallyAngry

end

function ENT:IsAngry()
    local permaAngry = self.terminator_PermanentAngry

    if permaAngry then return true end
    local angryTime = self.terminator_AngryTime or _CurTime()
    local checkIsAngry = self.terminator_CheckIsAngry or 0

    if checkIsAngry < _CurTime() then
        self.terminator_CheckIsAngry = _CurTime() + math.Rand( 0.9, 1.1 )
        local enemy = self:GetEnemy()

        if enemy and ( enemy.isTerminatorHunterKiller or enemy.terminator_CantConvinceImFriendly ) then
            self.terminator_PermanentAngry = true

        elseif self:Health() < ( self:GetMaxHealth() * 0.9 ) then
            self.terminator_PermanentAngry = true

        elseif self.isUnstucking then
            angryTime = angryTime + 6

        elseif self:inSeriousDanger() then
            angryTime = angryTime + math.random( 5, 15 )

        elseif self:getLostHealth() > 0.5 then
            angryTime = angryTime + math.random( 1, 10 )

        elseif enemy and ( not self.IsSeeEnemy or self.DistToEnemy > self.MoveSpeed * 3.5 ) then
            angryTime = angryTime + 1.1

        elseif not IsValid( enemy ) and self:GetPath() and self:GetPath():GetLength() > 1000 then
            angryTime = angryTime + 3

        elseif self.terminator_FellOffPath then
            angryTime = angryTime + 8
            self.terminator_FellOffPath = nil

        elseif self.DistToEnemy > 0 and self.terminator_AngryNotSeeing and self.terminator_AngryNotSeeing > 60 then
            self.terminator_PermanentAngry = true

        end

        if not self.IsSeeEnemy then
            local angrynotseeing_Increment = self.terminator_AngryNotSeeing or 0
            self.terminator_AngryNotSeeing = angrynotseeing_Increment + 1

        end
    end

    local angry = angryTime > _CurTime()
    self.terminator_AngryTime = math.max( angryTime, _CurTime() )

    return angry

end

function ENT:canDoRun()
    if not self:IsAngry() then return end
    if self.forcedShouldWalk and self.forcedShouldWalk > _CurTime() then return end
    if self.isInTheMiddleOfJump then return end
    local nearObstacleBlockRunning = self.nearObstacleBlockRunning or 0
    if nearObstacleBlockRunning > _CurTime() and not self.IsSeeEnemy then return end
    local area = self:GetCurrentNavArea()
    if not area then return end
    if area:HasAttributes( NAV_MESH_AVOID ) then return end
    if area:HasAttributes( NAV_MESH_CLIFF ) then return end
    if area:HasAttributes( NAV_MESH_TRANSIENT ) then return end
    if area:HasAttributes( NAV_MESH_CROUCH ) then return end
    local nextArea = self:GetNextPathArea()
    if self:getMaxPathCurvature( area, self.MoveSpeed ) > 0.45 then return end
    if self:confinedSlope( area, nextArea ) == true then return end
    if not nextArea then return true end
    if not nextArea:IsValid() then return true end
    local myPos = self:GetPos()
    if myPos:DistToSqr( nextArea:GetClosestPointOnArea( myPos ) ) > ( self.MoveSpeed * 1.25 ) ^ 2 then return true end
    if nextArea:HasAttributes( NAV_MESH_AVOID ) then return end
    if nextArea:HasAttributes( NAV_MESH_CLIFF ) then return end
    if nextArea:HasAttributes( NAV_MESH_TRANSIENT ) then return end
    if nextArea:HasAttributes( NAV_MESH_CROUCH ) then return end
    local minSizeNext = math.min( nextArea:GetSizeX(), nextArea:GetSizeY() )
    if minSizeNext < 25 then return end
    return true

end

function ENT:shouldDoWalk()
    if self.forcedShouldWalk and self.forcedShouldWalk > _CurTime() then return true end
    local area = self:GetCurrentNavArea()
    if not area then return end
    if not area:IsValid() then return end
    local minSize = math.min( area:GetSizeX(), area:GetSizeY() )
    if minSize < 45 then return true end
    local nextArea = self:GetNextPathArea()
    if self:confinedSlope( area, nextArea ) then return true end
    if self:getMaxPathCurvature( area, self.WalkSpeed, true ) > 0.85 then return true end
    if not nextArea then return end
    if not nextArea:IsValid() then return end
    return true

end

local Squared60 = 60^2
local sideOffs = 8
local aboveHead = 70
local belowHead = 40

local headclearanceOffsets = {
    Vector( sideOffs, sideOffs, aboveHead ),
    Vector( -sideOffs, sideOffs, aboveHead ),
    Vector( -sideOffs, -sideOffs, aboveHead ),
    Vector( sideOffs, -sideOffs, aboveHead ),
    Vector( sideOffs, sideOffs, belowHead ),
    Vector( -sideOffs, sideOffs, belowHead ),
    Vector( -sideOffs, -sideOffs, belowHead ),
    Vector( sideOffs, -sideOffs, belowHead ),

}

function ENT:ShouldCrouch()
    if not self.CanCrouch then return false end

    if self:IsControlledByPlayer() then
        if self:ControlPlayerKeyDown( IN_DUCK ) then
            return true
        end

        return false
    else
        if self.overrideCrouch and self.overrideCrouch > _CurTime() then return true end

        if self.m_Jumping then return true end

        local myPos = self:GetPos()

        local blockedCount = 0
        for _, check in ipairs( headclearanceOffsets ) do
            --debugoverlay.Cross( myPos + check, 1, 0.1 )
            if not util.IsInWorld( myPos + check ) then
                blockedCount = blockedCount + 1

            end
            if blockedCount >= 2 then
                self.overrideCrouch = _CurTime() + 0.5 -- dont check as soon!
                return true

            end
        end

        if not self:UsingNodeGraph() and self:PathIsValid() then
            local currArea = self:GetCurrentNavArea()
            local nextArea, goalPathPoint = self:GetNextPathArea()
            if currArea and currArea:IsValid() and currArea:HasAttributes( NAV_MESH_CROUCH ) then
                self.overrideCrouch = _CurTime() + 0.5
                return true
            elseif nextArea and nextArea:IsValid() and nextArea:HasAttributes( NAV_MESH_CROUCH ) and goalPathPoint.pos:DistToSqr( myPos ) < Squared60 then
                self.overrideCrouch = _CurTime() + 0.5
                return true
            end
        end

        local hasToCrouchToSee = self:HasToCrouchToSeeEnemy()

        if hasToCrouchToSee then return hasToCrouchToSee end

        return self:RunTask( "ShouldCrouch" ) or false
    end
end

local fivePositiveZ = Vector( 0,0,5 )
local fiftyZOffset = Vector( 0,0,50 )
local hullSizeMul = 0.75
local vector25Z = Vector( 0, 0, 25 )

-- rewrite this because the old logic was not working
-- return 0 when no blocker
-- returns 1 when its blocked but it can jump over
-- returns 2 when it should take a step back
local function GetJumpBlockState( self, dir, goal )

    local enemy = self:GetEnemy()
    local pos = self:GetPos()
    local b1,b2 = self:GetCollisionBounds()
    local step = self.loco:GetStepHeight()
    local mask = self:GetSolidMask()
    local cgroup = self:GetCollisionGroup()

    b1.x = b1.x * hullSizeMul
    b1.y = b1.y * hullSizeMul
    b2.x = b2.x * hullSizeMul
    b2.y = b2.y * hullSizeMul

    b1.z = b1.z * 0.25
    b2.z = b2.z * 0.25

    local distToTrace = ( pos - goal ):Length2D()
    distToTrace = math.Clamp( distToTrace, 15, 50 )

    local defEndPos = pos + dir * distToTrace

    -- do a trace in the dir we goin, likely flattened direction to next segment
    -- starts even more traces if this trace hits something
    local dirConfig = {
        start = pos,
        endpos = defEndPos,
        mins = b1,
        maxs = b2,
        filter = self,
        mask = mask,
        collisiongroup = cgroup,
    }

    local dirResult = util.TraceHull( dirConfig )

    -- final trace to see if a jump at height will actually take us all the way to goal
    -- needed to determine height to jump to when encountering obstacle
    local finalCheckConfig = {
        mins = b1,
        maxs = b2,
        filter = self,
        mask = mask,
        collisiongroup = cgroup,
    }

    local finalCheckResult

    -- do a trace from our pos to the jump offset's starting pos
    local vertConfig = {
        start = pos + fiftyZOffset,
        endpos = pos + fiftyZOffset,
        mins = b1,
        maxs = b2,
        filter = self,
        mask = mask,
        collisiongroup = cgroup,
    }
    local vertResult = nil

    local didSight = nil
    local sightResult

    -- if there's nothing to jump up to then just rely on dirResult
    -- this was added to detect if we're underneath like a overhanging ledge or catwalk we have to jump onto
    if goal.z > pos.z + 50 then
        didSight = true
        local sightConfig = {
            start = pos + fiftyZOffset,
            endpos = goal + fiftyZOffset,
            mins = b1,
            maxs = b2,
            filter = self,
            mask = mask,
            collisiongroup = cgroup,
        }

        sightResult = util.TraceHull( sightConfig )

    end

    local isObstacleToJumpOver

    -- we got up to enemy, act like nothing is there!
    if dirResult.Hit and IsValid( enemy ) and dirResult.Entity == enemy then
        return 0

    end

    if dirResult.Hit or ( didSight and sightResult.Hit ) then
        local maxjump = self.MaxJumpToPosHeight * 2

        local i = 0

        local offset = Vector( 0, 0, i )
        local goalWithOverriddenZ = Vector( goal.x, goal.y, 0 )

        while i <= maxjump do

            i = math.Round( math.min( i + step * 0.75, maxjump ) )

            offset.z = i
            local newEndPos = defEndPos + offset
            local newStartPos = pos + offset

            vertConfig.endPos = newStartPos
            vertResult = util.TraceHull( vertConfig )
            -- vertConfig goes from the last start of the can step check, to the next start, so it checks if there's vertical space
            vertConfig.start = newStartPos

            if vertResult.Hit and not self:hitBreakable( vertConfig, vertResult ) then
                local color = Color( 255, 255, 255, 25 )
                if vertResult.Hit then color = Color( 255,0,0, 25 ) end
                debugoverlay.Box( vertResult.HitPos, vertConfig.mins, vertConfig.maxs, 4, color )
                return 2 -- step back bot!
            end

            dirConfig.start = newStartPos
            dirConfig.endpos = newEndPos

            dirResult = util.TraceHull( dirConfig )

            local hitThingWeCanBreak = self:hitBreakable( dirConfig, dirResult )

            local color = Color( 255, 255, 255, 25 )
            if dirResult.Hit then color = Color( 255,0,0, 25 ) end
            debugoverlay.Box( dirResult.HitPos, dirConfig.mins, dirConfig.maxs, 1, color )

            -- final check!
            goalWithOverriddenZ.z = math.max( dirConfig.start.z, goal.z + 20 )
            finalCheckConfig.start = newStartPos
            finalCheckConfig.endpos = goalWithOverriddenZ

            finalCheckResult = util.TraceHull( finalCheckConfig )

            -- if we are above the goal or, if we can see it
            -- stops bot from jumping in hallways
            local thisCheckCanCompleteJump = newStartPos.z >= goal.z or not finalCheckResult.Hit

            if dirResult.Hit and not hitThingWeCanBreak then
                isObstacleToJumpOver = true

            elseif thisCheckCanCompleteJump then
                if isObstacleToJumpOver then
                    return 1, dirConfig.start, i

                else
                    return 0

                end
            end

            if i >= maxjump then break end
        end

        return 2 -- step back bot!
    end

    return 0
end

function ENT:ChooseBasedOnVisible( check, potentiallyVisible )
    local b1, b2 = self:GetCollisionBounds()
    local mask = self:GetSolidMask()
    local collisiongroup = nil
    local filterTbl = table.Copy( self:GetChildren() )
    table.insert( filterTbl, self )

    collisiongroup = self:GetCollisionGroup()

    local theTrace = {
        filter = filterTbl,
        start = self:GetPos(),
        mins = b1 * 0.5,
        maxs = b2 * 0.5,
        endpos = nil,
        mask = mask,
        collisiongroup = collisiongroup,
    }

    for index, potentialVisible in ipairs( potentiallyVisible ) do
        if potentialVisible then
            theTrace.endpos = potentialVisible
            local result = util.TraceHull( theTrace )
            local hitBreakable = self:hitBreakable( theTrace, result )
            if not result.Hit or hitBreakable then
                --debugoverlay.Line( check, potentialVisible, 1, Color( 255,255,255 ), true )
                return potentialVisible, index, hitBreakable
            end
        end
    end
    return nil

end

local sideMul = 0.1 --  strafe mul for when bot is stepping back to find better jump spot 
local moveScale = 40
local cheats = GetConVar( "sv_cheats" )

function ENT:EntIsInMyWay( ent, tolerance, aheadSegment )
    local myPos = self:GetPos()
    local segmentAheadOfMe = aheadSegment
    if not istable( segmentAheadOfMe ) then
        _, segmentAheadOfMe = self:GetNextPathArea( self:GetTrueCurrentNavArea() )

    end
    if not istable( segmentAheadOfMe ) then return end -- we tried

    local angleToAhead = DirToPos( myPos, segmentAheadOfMe.pos ):Angle()
    local entsNearestPosToMe = ent:NearestPoint( self:GetShootPos() )
    local bearingToEnt = util.terminator_BearingToPos( myPos, angleToAhead, entsNearestPosToMe, angleToAhead )
    bearingToEnt = math.abs( bearingToEnt )

    if bearingToEnt > tolerance then
        return true, bearingToEnt

    end
    return false, bearingToEnt

end

--[[------------------------------------
    Name: NEXTBOT:MoveAlongPath
    Desc: (INTERNAL) Process movement along path.
    Arg1: bool | lookatgoal | Should bot look at goal while moving.
    Ret1: bool | Path was completed right now
    overriden to fuck with the broken jumping, hopefully making it more reliable.
--]]------------------------------------
function ENT:MoveAlongPath( lookatgoal )
    local path = self:GetPath()

    if self.DrawPath:GetBool() and cheats:GetBool() == true then
        path:Draw()

    end

    local myPos = self:GetPos()
    local myArea = self:GetTrueCurrentNavArea()
    local _, aheadSegment = self:GetNextPathArea( myArea ) -- top of the jump
    local currSegment = path:GetCurrentGoal() -- maybe bottom of the jump, paths are stupid

    if not aheadSegment then
        aheadSegment = currSegment
    end

    if not currSegment then return false end

    local seg1sType = aheadSegment.type
    local seg2sType = currSegment.type

    local laddering = seg1sType == 4 or seg2sType == 4 or seg1sType == 5 or seg2sType == 5
    local disrespecting = self:GetCachedDisrespector()
    local speedToStopLookingFarAhead = 30^2
    if IsValid( disrespecting ) and self:EntIsInMyWay( disrespecting, 140, aheadSegment ) then
        speedToStopLookingFarAhead = 100^2

    end
    local movingSlow = self.loco:GetVelocity():LengthSqr() < speedToStopLookingFarAhead

    if ( lookatgoal or movingSlow ) and self:PathIsValid() then
        local ang
        local lookAtPos = aheadSegment.pos
        if not self:IsOnGround() or movingSlow then
            if IsValid( disrespecting ) then
                lookAtPos = self:getBestPos( disrespecting )
                --debugoverlay.Cross( lookAtPos, 10, 10, color_white, true )

            else
                lookAtPos = aheadSegment.pos

            end
        elseif lookAtPos:DistToSqr( myPos ) < 200^2 then
            -- attempt to look farther ahead
            local _, segmentAheadOfUs = self:GetNextPathArea( myArea, 3, true )
            if segmentAheadOfUs then
                lookAtPos = segmentAheadOfUs.pos

            end
        end
        ang = ( lookAtPos - self:GetShootPos() ):Angle()
        local notADramaticHeightChange = ( lookAtPos.z > myPos.z + -100 ) or ( lookAtPos.z < myPos.z + 100 )
        if notADramaticHeightChange and not laddering and not IsValid( disrespecting ) then
            ang.p = 0

        end

        self:SetDesiredEyeAngles( ang )

    end

    if laddering and self:TermHandleLadder( aheadSegment, currSegment ) then
        return

    end

    if self.terminator_HandlingLadder then
        self:ExitLadder( aheadSegment.pos )

    end
    self.terminator_HandlingLadder = nil
    local checkTolerance = self.PathGoalTolerance * 4

    --figuring out what kind of terrian we passing

    -- check if normal path is actually gap
    local reallyJustAGap = nil
    local middle = ( aheadSegment.pos + currSegment.pos ) / 2
    if seg2sType == 0 then
        local floorTraceDat = {
            start = middle + vector_up * 50,
            endpos = middle + down * 125,
            maxs = gapJumpHull,
            mins = -gapJumpHull,
        }

        local result = util.TraceHull( floorTraceDat )
        local lowestSegmentsZ = math.min( currSegment.pos.z, aheadSegment.pos.z )

        if not result.Hit then
            reallyJustAGap = true

        elseif result.HitPos.z < lowestSegmentsZ + -self.loco:GetStepHeight() * 2 then
            reallyJustAGap = true
            --debugoverlay.Cross( aheadSegment.pos, 10, 10, color_white, true )
            --debugoverlay.Cross( middle, 10, 10, color_white, true )
            --debugoverlay.Cross( result.HitPos, 10, 10, color_white, true )

        end
        -- if hit but started solid?
        if result.StartSolid then
            reallyJustAGap = nil

        end

    end

    -- check if dropping down is actually a gap
    local droppingType = seg1sType == 1 or seg2sType == 1
    local dropIsReallyJustAGap = nil
    if droppingType then
        local _, jumpBottomSeg = self:GetNextPathArea( myArea, 1 )
        local _, segAfterTheDrop = self:GetNextPathArea( myArea, 2 )
        if jumpBottomSeg and segAfterTheDrop then
            local middleWeighted = ( currSegment.pos + ( jumpBottomSeg.pos * 0.5 ) ) / 1.5

            local floorTraceDat = {
                start = middleWeighted + vector_up * 10,
                endpos = middleWeighted + down * 3000,
                filter = self,
                maxs = gapJumpHull,
                mins = -gapJumpHull,
            }

            local result = util.TraceHull( floorTraceDat )
            local hitBelowDest = result.HitPos.z < ( segAfterTheDrop.pos.z + -65 )

            --debugoverlay.Line( floorTraceDat.start, result.HitPos, 10, color_white, true )
            --debugoverlay.Cross( segAfterTheDrop.pos, 10, 10 )

            if hitBelowDest and not result.StartSolid then
                dropIsReallyJustAGap = true
                aheadSegment = segAfterTheDrop
                self.wasADropTypeInterpretedAsAGap = true

            end
            if self.loco:IsOnGround() and myPos.z < segAfterTheDrop.pos.z + 25 and self.wasADropTypeInterpretedAsAGap then
                self:GetPath():Invalidate()

            end
        end
    end

    -- check if jumping over a gap is ACTUALLY jumping over a gap
    local realGapJump = nil
    if seg1sType == 3 or seg2sType == 3 then
        local trStart = middle + vector_up
        trStart.z = math.max( currSegment.pos.z, aheadSegment.pos.z )
        local floorTraceDat = {
            start = trStart,
            endpos = middle + down * 40,
            maxs = gapJumpHull,
            mins = -gapJumpHull,
        }

        local result = util.TraceHull( floorTraceDat )
        --debugoverlay.Cross( middle, 10, 1, color_white, true )

        if not result.Hit then
            realGapJump = true

        end
        -- if hit but started solid?
        if result.StartSolid then
            realGapJump = nil

        end

        if result.HitPos.z < aheadSegment.pos.z + -self.loco:GetStepHeight() then
            realGapJump = true

        end
    end

    local sqrDistToGoal = myPos:DistToSqr( currSegment.pos )
    local closeToGoal = sqrDistToGoal < ( checkTolerance ^ 2 )
    local validDroptypeInterpretedAsGap = dropIsReallyJustAGap and ( sqrDistToGoal < ( checkTolerance * 3 ) ^ 2 )
    local gapping = realGapJump or reallyJustAGap or validDroptypeInterpretedAsGap
    if gapping then
        checkTolerance = checkTolerance * 0.25

    end

    local doPathUpdate = nil
    local isHandlingJump = false
    local doingJump = nil

    local jumptype = seg1sType == 2 or seg2sType == 2 or realGapJump or reallyJustAGap or validDroptypeInterpretedAsGap
    local droptype = droppingType and not dropIsReallyJustAGap

    local good = self:PathIsValid() and not self:UsingNodeGraph() and self.loco:IsOnGround()
    local areaSimple = self:GetCurrentNavArea()

    local myHeightToNext = aheadSegment.pos.z - myPos.z
    local jumpableHeight = myHeightToNext < self.MaxJumpToPosHeight

    if areaSimple and good then
        -- Jump support for navmesh PathFollower

        local tryingToJumpUpStairs = areaSimple:HasAttributes( NAV_MESH_STAIRS ) and math.abs( myHeightToNext ) < 35
        local blockJump = areaSimple:HasAttributes( NAV_MESH_NO_JUMP ) or tryingToJumpUpStairs or prematureGapJump

        if IsValid( areaSimple ) and jumpableHeight and not blockJump and ( self.nextPathJump or 0 ) < _CurTime() then
            local dir = aheadSegment.pos-myPos
            dir.z = 0
            dir:Normalize()

            local jumpstate, jumpBlockerJumpOver, jumpingHeight = GetJumpBlockState( self, dir, aheadSegment.pos, droptype )

            self.moveAlongPathJumpingHeight = jumpingHeight or self.moveAlongPathJumpingHeight
            self.jumpBlockerJumpOver = jumpBlockerJumpOver or self.jumpBlockerJumpOver

            if gapping and aheadSegment then
                jumpingHeight = ( currSegment.pos - aheadSegment.pos ):Length2D() / 1.5
                --debugoverlay.Line( currSegment.pos, aheadSegment.pos, 10, color_white, true )

            end
            if jumptype and not jumpingHeight then
                jumpingHeight = myHeightToNext

            end
            if jumpingHeight and myHeightToNext then
                jumpingHeight = math.Clamp( jumpingHeight, myHeightToNext, math.huge )

            end

            --print( myHeightToNext, self.loco:GetStepHeight() )
            --print( jumpstate, jumptype, areaSimple:HasAttributes( NAV_MESH_JUMP ), droptype and jumpstate == 1, self.m_PathJump and jumpstate == 1, jumpstate == 2 )
            if
                jumptype or                                                      -- jump segment
                areaSimple:HasAttributes( NAV_MESH_JUMP ) or                           -- jump area
                droptype and jumpstate == 1 or
                self.m_PathJump and jumpstate == 1 or
                jumpstate == 2
            then
                local beenCloseToTheBottomOfTheJump = closeToGoal or self.beenCloseToTheBottomOfTheJump
                self.beenCloseToTheBottomOfTheJump = beenCloseToTheBottomOfTheJump

                -- obstacle, we have to move around if we want to go past it
                if jumpstate == 2 then
                    if math.random( 0, 100 ) > 80 then
                        sideMul = -sideMul -- jiggle this around a bit\
                        moveScale = self:GetRangeTo( currSegment.pos ) * math.Rand( 0.7, 1.2 )

                    end

                    local movingDir = dir + ( self:GetRight() * sideMul )

                    self.m_PathJump = true

                    self:Approach( myPos + -movingDir * moveScale )
                    doingJump = true

                -- nothing is stopping us from jumping!
                elseif jumpstate == 1 or ( ( gapping or jumptype ) and beenCloseToTheBottomOfTheJump ) or ( droptype and jumpstate == 1 ) then
                    -- Performing jump

                    self.m_PathJump = false
                    self.loco:SetVelocity( vector_origin )

                    self:Jump( jumpingHeight )

                    local ang = self:GetAngles()
                    doPathUpdate = true
                    self:SetAngles( ang )
                end

                -- Trying deal with jump, don't update path
                isHandlingJump = true
                doingJump = closeToGoal
            elseif
                self.m_PathJump and jumpstate == 0
            then
                self.m_PathJump = false

            end
        end
    end

    local jumpApproach = nil
    -- off ground
    if not self.loco:IsOnGround() and aheadSegment then
        if self:IsJumping() then
            local nextPathArea = self:GetNextPathArea( self:GetTrueCurrentNavArea() )

            if nextPathArea and nextPathArea:IsValid() then
                local nextAreaCenter = nextPathArea:GetCenter() + ( fivePositiveZ * 2 )
                local aheadSegmentsPos = aheadSegment.pos
                local closestPoint = nil
                local closestPointForgiving = nil
                local jumpingDestinationOffset = nil
                local destinationRelativeToBot = nil
                local validJumpablePathRelative = nil
                local validJumpableHeightOffset = self.moveAlongPathJumpingHeight
                if math.max( nextPathArea:GetSizeX(), nextPathArea:GetSizeY() ) > 35 then
                    aheadSegmentsPos = nil
                    closestPoint = nextPathArea:GetClosestPointOnArea( myPos )
                    closestPointForgiving = closestPoint + vector25Z
                    if ( nextAreaCenter.z - 20 ) < myPos.z then
                        destinationRelativeToBot = Vector( nextAreaCenter.x, nextAreaCenter.y, myPos.z )

                    end
                end
                if validJumpableHeightOffset then
                    local offset = Vector( 0, 0, validJumpableHeightOffset * 1.5 )
                    validJumpablePathRelative = aheadSegment.pos + offset
                    validJumpableBotRelative = myPos + offset
                    jumpingDestinationOffset = nextAreaCenter + offset
                end

                -- build choose table, smaller num ones are checked first
                -- each check here was added to fix bot traversing some kind of jump shape
                local toChoose = {}
                table.insert( toChoose, aheadSegmentsPos )
                table.insert( toChoose, nextAreaCenter )
                table.insert( toChoose, closestPoint )
                table.insert( toChoose, closestPointForgiving )
                table.insert( toChoose, jumpingDestinationOffset )
                table.insert( toChoose, destinationRelativeToBot )
                table.insert( toChoose, validJumpableBotRelative )
                table.insert( toChoose, validJumpablePathRelative )

                local nextPos, indexThatWasVisible, hitBreakable = self:ChooseBasedOnVisible( myPos, toChoose )
                --debugoverlay.Cross( closestPoint, 10, 10, Color( 255, 255, 255 ), true )
                --debugoverlay.Cross( nextAreaCenter, 10, 10, Color( 255, 255, 255 ), true )
                --debugoverlay.Cross( validJumpable, 10, 10, Color( 255, 255, 255 ), true )

                if nextPos then
                    --debugoverlay.Cross( nextPathArea:GetCenter(), 10, 10, Color( 255, 255, 255 ), true )
                    --debugoverlay.Cross( nextPathArea:GetCenter(), 0.5, 20, Color( 255, 255, 255 ), true )

                    local subtProduct = nextPos - myPos
                    local dir = ( subtProduct ):GetNormalized()
                    local dist = subtProduct:Length()
                    local myVel = self.loco:GetVelocity()
                    local subtFlattened = subtProduct
                    subtFlattened.z = 0
                    local dist2d = subtFlattened:Length2D()

                    local dirProportional = dir * math.Clamp( self.RunSpeed, self.RunSpeed / 6, dist2d * 2 )

                    myVel.x = dirProportional.x
                    myVel.y = dirProportional.y
                    if dir.z < -0.75 then
                        myVel.z = math.Clamp( myVel.z, -math.huge, myVel.z * 0.9 )

                    end

                    self.OverrideCrouch = _CurTime() + 1.5

                    local beginSetposCrouchJump = indexThatWasVisible <= 4 and nextPathArea:HasAttributes( NAV_MESH_CROUCH ) and not hitBreakable
                    local justSetposUsThere = ( self.WasSetposCrouchJump or beginSetposCrouchJump ) and myPos:DistToSqr( nextPathArea:GetClosestPointOnArea( myPos ) ) < 40^2

                    -- i HATE VENTS!
                    if justSetposUsThere then
                        local setPosDist = math.Clamp( dist2d, 15, 35 )
                        self:SetPos( myPos + dir * setPosDist )
                        self.loco:SetVelocity( dir )
                        self.WasSetposCrouchJump = true

                    else
                        self.loco:SetVelocity( myVel )

                    end
                else
                    jumpApproach = true

                end
            else
                jumpApproach = true

            end
        else
            jumpApproach = true

        end
    elseif not isHandlingJump and self.loco:IsOnGround() then
        self.WasSetposCrouchJump = nil
        self.wasADropTypeInterpretedAsAGap = nil
        doPathUpdate = true
        --debugoverlay.Cross( aheadSegment.pos, 100, 0.1, color_white, true )

    elseif isHandlingJump and not droptype and self.loco:IsOnGround() then
        doPathUpdate = true

    end

    if doPathUpdate then
        local distAhead = myPos:DistToSqr( currSegment.pos )

        -- blegh
        local catchupAfterAJump = aheadSegment.type ~= 0 and distAhead < myPos:DistToSqr( aheadSegment.pos ) and aheadSegment.length^2 < distAhead and util.PosCanSee( self:GetShootPos(), currSegment.pos )

        -- don't backtrack, we're already here!
        if catchupAfterAJump then
            self.BiggerGoalTolerance = true
            path:SetGoalTolerance( 200000 )

        elseif self.BiggerGoalTolerance then
            self.BiggerGoalTolerance = nil
            path:SetGoalTolerance( self.PathGoalTolerance )

        end

        local ang = self:GetAngles()
        path:Update( self )
        -- if this doesnt run then bot always looks toward next path seg, doesn't aim at ply
        self:SetAngles( ang )

        local phys = self:GetPhysicsObject()
        if IsValid( phys ) then
            phys:SetAngles( angle_zero )

        end

        -- detect when bot falls down and we need to repath
        local maxHeightChange = math.max( math.abs( currSegment.pos.z - aheadSegment.pos.z ), self.loco:GetMaxJumpHeight() * 1.5 )
        local changeToSegment = math.abs( myPos.z - currSegment.pos.z )

        if changeToSegment > maxHeightChange * 2 then
            --print( "invalid", changeToSegment, maxHeightChange * 2 )
            self.terminator_FellOffPath = true
            self:GetPath():Invalidate()

        end
    end


    if jumpApproach == true then
        if closeToGoal then
            doingJump = true

        end

        -- not doing dropdown, cancel the non-z parts of my vel pls
        local myVel = self.loco:GetVelocity()
        local product = -myVel * 0.2
        product.z = 0

        -- doing drop down, please approach the dropdown
        if droptype and util.PosCanSeeComplex( myPos, currSegment.pos, self ) then
            --debugoverlay.Line( myPos, currSegment.pos, 0.2 )
            product1 = myPos - currSegment.pos
            product1.z = 0
            product = -product1:GetNormalized() * math.Clamp( product1:Length() * 2, 0, 200 )

        end
        self.loco:SetVelocity( myVel + product )

    end

    local oldPathSegment = self.oldWasClosePathSegment
    if oldPathSegment ~= aheadSegment then
        self.oldWasClosePathSegment = aheadSegment
        self.beenCloseToTheBottomOfTheJump = nil

    end

    self.isInTheMiddleOfJump = doingJump

    local range = self:GetRangeTo( self:GetPathPos() )

    if not path:IsValid() and range <= self.m_PathOptions.tolerance or range < self.PathGoalToleranceFinal then
        path:Invalidate()
        return true -- reached end
    elseif path:IsValid() then
        return nil -- not at end, stuck detection is done elsewhere
    end

    return false
end

-- GPT4 func
local function SnapToLadderAxis( ladderBottom, ladderTop, point )
    -- Calculate the ladder's direction vector
    local ladderDirection = ( ladderTop - ladderBottom ):GetNormalized()

    -- Calculate the vector from the bottom of the ladder to the point
    local bottomToPoint = point - ladderBottom

    -- Project the bottomToPoint vector onto the ladderDirection vector
    local projectedVector = ladderDirection * bottomToPoint:Dot( ladderDirection )

    -- Calculate the snapped position by adding the projected vector to the bottom of the ladder
    local snappedPosition = ladderBottom + projectedVector

    return snappedPosition
end

local function Dist2d( pos1, pos2 )
    local subtProduct = pos1 - pos2
    return subtProduct:Length2D()

end

function ENT:TermHandleLadder( aheadSegment, currSegment )

    -- bot is not falling!
    local wasHandlingLadder = self.terminator_HandlingLadder

    local myPos = self:GetPos()
    local goingUp = aheadSegment.type == 4 or currSegment.type == 4
    local goingDown = aheadSegment.type == 5 or currSegment.type == 5

    local ladder = aheadSegment.ladder
    ladder = ladder or currSegment.ladder

    local top = ladder:GetTop()
    local bottom = ladder:GetBottom()
    local laddersNormalOffset = ladder:GetNormal() * 16
    local closestToLadderPos = SnapToLadderAxis( bottom + laddersNormalOffset, top + laddersNormalOffset, myPos )

    local laddersUp = ( top - bottom ):GetNormalized()
    local dist2DToLadder = Dist2d( myPos, closestToLadderPos )

    local ladderClimbTarget
    if goingUp then
        ladderClimbTarget = closestToLadderPos + laddersUp * 150
        if dist2DToLadder < 30 then
            self.terminator_HandlingLadder = true
            self.loco:Jump() -- if we are on ground, jump
            if wasHandlingLadder and myPos.z > top.z + -25 then
                local ladderExit = self:GetNextPathArea()
                if not ladderExit or not IsValid( ladderExit ) then
                    ladderExit = ladder:GetTopForwardArea()

                end
                if not ladderExit or not IsValid( ladderExit ) then
                    ladderExit = self:GetPos()

                end
                self:ExitLadder( ladderExit )
                return false

            elseif not wasHandlingLadder then
                self:EnterLadder( ladder )

            end

        end
    elseif goingDown then
        ladderClimbTarget = closestToLadderPos + -laddersUp * 150
        if dist2DToLadder < 30 then
            self.terminator_HandlingLadder = true
            self.loco:Jump() -- if we are on ground, jump

            local recalculate = nil
            local madFastDrop = self.IsSeeEnemy and self:IsReallyAngry() and myPos.z < bottom.z + 2000
            if madFastDrop then
                recalculate = myPos:Distance( bottom ) / 200

            end

            if wasHandlingLadder and ( myPos.z < bottom.z + 25 or madFastDrop ) then
                self:ExitLadder( ladder:GetBottomArea(), recalculate )
                return false

            elseif not wasHandlingLadder then
                self:EnterLadder( ladder )

            end

        end
    else
        ladderClimbTarget = closestToLadderPos

    end

    local dir = ( ladderClimbTarget - myPos ):GetNormalized()
     -- in the ladder
    if wasHandlingLadder then
        self.jumpingPeak = self:GetPos()
        self.overrideCrouch = _CurTime() + 1
        local vel = dir * self.WalkSpeed * 1.5

        self.loco:SetVelocity( vel )

    -- snap onto the ladder
    elseif dist2DToLadder < 50 and not wasHandlingLadder then
        self.jumpingPeak = self:GetPos()
        self:SetPos( closestToLadderPos )
        self.loco:SetVelocity( vector_origin )

    -- walk to the ladder
    else
        self:GotoPosSimple( closestToLadderPos, 10 )

    end

    local nextLadderSound = self.nextLadderSound or 0
    ladderClimbTarget = ladderClimbTarget

    if wasHandlingLadder and nextLadderSound < _CurTime() then
        self.nextLadderSound = _CurTime() + 0.5
        self:EmitSound( "player/footsteps/ladder" .. math.random( 1, 4 ) .. ".wav", 94, math.random( 70, 80 ) )
        util.ScreenShake( myPos, 0.5, 20, 0.1, 1000 )

    end

    return true

end

function ENT:HandlePathRemovedWhileOnladder()
    if not self.terminator_HandlingLadder then return end
    if self:PathIsValid() then return end
    self:ExitLadder( self:GetPos() )

end


-- easy alias for approach
function ENT:GotoPosSimple( pos, distance )
    if distance ~= math.huge and self:NearestPoint( pos ):DistToSqr( pos ) > distance^2 then
        local myPos = self:GetPos()
        local dir = DirToPos( myPos, pos )
        local jumpstate, _, jumpingHeight = GetJumpBlockState( self, dir, pos, false )
        if self.loco:IsOnGround() and ( jumpstate == 1 or jumpstate == 2 ) then
            jumpingHeight = jumpingHeight or 64
            self:Jump( jumpingHeight + 20 )
            return

        end

        self.loco:Approach( pos, 10000 )
        --debugoverlay.Cross( pos, 10, 1, color_white, true )

    end
end

function ENT:EnterLadder()
    self.preLadderGravity = self.loco:GetGravity()

    self.loco:SetGravity( 0 )

    self:EmitSound( "player/footsteps/ladder" .. math.random( 1, 4 ) .. ".wav", 98, math.random( 60, 70 ) )
    util.ScreenShake( self:GetPos(), 10, 20, 0.2, 1000 )

end

function ENT:ExitLadder( exit, recalculate )
    local pos
    if isvector( exit ) then
        pos = exit

    elseif IsValid( exit ) then
        pos = exit:GetClosestPointOnArea( self:GetPos() )

    end

    if not pos then return end

    recalculate = recalculate or 0.5

    self.terminator_HandlingLadder = nil

    --debugoverlay.Cross( pos, 100, 1, color_white, true )

    self.nextNewPath = _CurTime() + recalculate
    self.needsPathRecalculate = true

    local myPos = self:GetPos()
    local desiredPos = Vector( myPos.x, myPos.y, math.max( myPos.z + 15, pos.z + 35 ) )

    local b1, b2 = self:GetCollisionBounds()
    local mask = self:GetSolidMask()
    local cgroup = self:GetCollisionGroup()

    local findHighestClearPos = {
        start = myPos,
        endpos = desiredPos,
        mins = b1,
        maxs = b2,
        filter = self,
        mask = mask,
        collisiongroup = cgroup,
    }

    local clearResult = util.TraceHull( findHighestClearPos )

    self:SetPos( clearResult.HitPos )
    self.loco:SetVelocity( vector_up )

    local ladderExitVel = ( pos - clearResult.HitPos ):GetNormalized()
    ladderExitVel.z = 0
    ladderExitVel = ladderExitVel * math.random( 280 + -40, 280 )
    timer.Simple( 0, function()
        if not IsValid( self ) then return end
        self.loco:SetGravity( self.preLadderGravity or 600 )
        self.loco:SetVelocity( ladderExitVel )

    end )

    self:GetPath():Invalidate()

    self:EmitSound( "player/footsteps/ladder" .. math.random( 1, 4 ) .. ".wav", 98, math.random( 60, 70 ) )
    util.ScreenShake( self:GetPos(), 10, 20, 0.2, 1000 )

end

--[[------------------------------------
    Name: NEXTBOT:Jump
    Desc: Use this to make bot jump.
    Arg1: 
    Ret1: 
--]]------------------------------------
function ENT:Jump( height )
    if not self.loco:IsOnGround() then return end

    if height then
        -- jump a bit higher than we need ta
        height = height + 20

    else
        ErrorNoHaltWithStack( "TERMINATOR JUMPED WITH NO HEIGHT" )

    end

    height = math.Clamp( height, 0, self.JumpHeight )

    local vel = self.loco:GetVelocity()
    vel.z = ( 2.5 * self.loco:GetGravity() * height ) ^ 0.4986

    local pos = self:GetPos()

    self.loco:Jump()
    self.loco:SetVelocity( vel )
    --self:SetPos(util.TraceHull({start = pos,endpos = pos+Vector(0,0,self.StepHeight),mask = self:GetSolidMask(),mins = b1,maxs = b2,filter = self}).HitPos)

    self:SetupActivity()

    self:SetupCollisionBounds()
    self:MakeFootstepSound( 1, nil, 1.05 )

    if self.ReallyStrong then
        self:EmitSound( "physics/metal/metal_canister_impact_soft2.wav", 80, 40, 0.6, CHAN_STATIC )
        self:EmitSound( "physics/flesh/flesh_impact_hard1.wav", 80, 50, 0.6, CHAN_STATIC )
        util.ScreenShake( pos, 1, 20, 0.1, 600 )

    end

    self.m_Jumping = true

    self:RunTask( "OnJump" )
end

local airSoundPath = "ambient/wind/wind_rooftop1.wav"

function StartFallingSound( falling )
    local timerName = "terminator_falling_manage_sound_" .. falling:GetCreationID()
    falling:StopSound( airSoundPath )
    timer.Remove( timerName )

    local filterAll = RecipientFilter()
    filterAll:AddAllPlayers()

    local airSound = CreateSound( falling, airSoundPath, filterAll )
    airSound:SetSoundLevel( 85 )
    airSound:PlayEx( 1, 150 )

    falling.terminator_playingFallingSound = true

    falling:CallOnRemove( "terminator_stopwhooshsound", function() falling:StopSound( airSoundPath ) end )

    local StopAirSound = function()
        timer.Remove( timerName )
        if not IsValid( falling ) then return end
        falling:StopSound( airSoundPath )
        falling.terminator_playingFallingSound = nil

    end

    timer.Create( timerName, 0, 0, function()
        if not IsValid( falling ) then StopAirSound() return end
        if not airSound:IsPlaying() then StopAirSound() return end
        local vel = falling:FallHeight()
        local pitch = 30 + ( vel / 20 )
        local volume = vel / 1000
        if falling.loco:IsOnGround() then StopAirSound() return end
        airSound:ChangePitch( pitch )
        airSound:ChangeVolume( volume )

    end )
end

function ENT:DoJumpPeak( myPos )
    local jumpingPeak = self.jumpingPeak
    if not jumpingPeak then
        jumpingPeak = myPos
        self.jumpingPeak = myPos

    end
    if self:GetPos().z > jumpingPeak.z then
        self.jumpingPeak = myPos

    end
end

function ENT:FallHeight()
    if not self.jumpingPeak then return 0 end
    return math.abs( self.jumpingPeak.z - self:GetPos().z )

end

function ENT:OnLeaveGround( ent )
    self:DoJumpPeak( self:GetPos() )

end

function ENT:HandleInAir()
    local myPos = self:GetPos()
    self:DoJumpPeak( myPos )

    if self:FallHeight() > 200 and not self.terminator_playingFallingSound then
        StartFallingSound( self )

    end

    local waterLevel = self:WaterLevel()
    local oldLevel = self.oldJumpingWaterLevel or 0
    if oldLevel ~= waterLevel then
        self.oldJumpingWaterLevel = waterLevel
        if oldLevel == 0 then

            local traceStruc = {
                start = self.jumpingPeak,
                endpos = myPos,
                mask = MASK_WATER

            }

            local waterResult = util.TraceLine( traceStruc )
            local watersSurface = Vector( myPos.x, myPos.y, waterResult.HitPos.z )

            local scale = self:FallHeight() / 18

            local sploosh = EffectData()
            sploosh:SetScale( math.Clamp( scale, 10, 20 ) )
            sploosh:SetOrigin( watersSurface )
            util.Effect( "watersplash", sploosh )

            local level = math.Clamp( 65 + ( scale / 1.5 ), 65, 100 )
            local pitch = math.Clamp( 120 + -( scale * 1.5 ), 60, 120 )

            sound.Play( "ambient/water/water_splash1.wav", watersSurface, level, pitch )

            if scale > 20 then
                util.ScreenShake( self:GetPos(), 4, 20, 0.1, 800 )
                sound.Play( "weapons/underwater_explode3.wav", watersSurface, level, pitch + -20, 0.5 )
                sound.Play( "physics/surfaces/underwater_impact_bullet1.wav", watersSurface, level, pitch + -20, 0.5 )

            end
        end
    end
end

local vecDown = Vector( 0, 0, -1 )

--[[------------------------------------
    NEXTBOT:OnLandOnGround
    Some functional with jumps
--]]------------------------------------
function ENT:OnLandOnGround( ent )
    if self.m_Jumping then
        self.m_Jumping = false
        self.nextPathJump = _CurTime() + 0.15

        -- Restoring from jump

        if not self:IsPostureActive() then
            self:SetupActivity()
        end

        self:SetupCollisionBounds()

    end

    local myPos = self:GetPos()
    local fallHeight = self:FallHeight()

    local mins, maxs = self:GetCollisionBounds()
    local killScale = 5
    local killBoxScale = 0.5

    local fellOnSky = util.QuickTrace( myPos + vector_up * 25, down * 200, self ).HitSky

    -- wow we really fell far
    if fallHeight > 2000 or fellOnSky and fallHeight > 500 then
        self:LethalFallDamage()
        killScale = 100
        killBoxScale = 20

    elseif fallHeight >= 50 and self.ReallyStrong then
        local layer = self:AddGesture( self:TranslateActivity( ACT_LAND ) )

        if fallHeight >= 500 then
            self:EmitSound( "physics/metal/metal_canister_impact_soft2.wav", 100, 60, 1, CHAN_STATIC )
            self:EmitSound( "physics/metal/metal_computer_impact_bullet2.wav", 100, 30, 1, CHAN_STATIC )
            util.ScreenShake( self:GetPos(), 16, 20, 0.4, 3000 )

            for _ = 1, 6 do
                self:EmitSound( table.Random( self.Whaps ), 75, math.random( 115, 120 ) )

            end
            killScale = 50
            killBoxScale = 4

        elseif fallHeight >= 250 then
            self:MakeFootstepSound( 1 )
            self:EmitSound( "physics/metal/metal_canister_impact_soft2.wav", 84, 90, 1, CHAN_STATIC )
            self:EmitSound( "physics/metal/metal_computer_impact_bullet2.wav", 84, 40, 0.6, CHAN_STATIC )
            util.ScreenShake( self:GetPos(), 4, 20, 0.1, 800 )

            self:SetLayerPlaybackRate( layer, 0.2 )
            self:SetLayerWeight( layer, 100 )
            killScale = 40
            killBoxScale = 1.5

        else
            self:MakeFootstepSound( 1 )
            self:EmitSound( "physics/metal/metal_canister_impact_soft2.wav", 80, 40, 0.3, CHAN_STATIC )
            self:EmitSound( "physics/flesh/flesh_impact_hard1.wav", 80, 40, 0.3, CHAN_STATIC )
            util.ScreenShake( self:GetPos(), 0.5, 20, 0.1, 600 )

            self:SetLayerPlaybackRate( layer, 1 )
            killScale = 20
            killBoxScale = 0.8

        end
    end

    if self.ReallyStrong then

        maxs = maxs * killBoxScale
        mins = mins * killBoxScale

        local toKill = ents.FindAlongRay( myPos, myPos + vecDown * killScale, mins, maxs )
        for _, entToKill in ipairs( toKill ) do
            if entToKill == self then continue end
            local damage = killScale * 5

            if ent.huntersglee_breakablenails and damage < 250 then continue end

            local dmg = DamageInfo()
            dmg:SetAttacker( self )
            dmg:SetInflictor( self )
            dmg:SetDamageType( DMG_CLUB )
            dmg:SetDamage( damage )
            dmg:SetDamageForce( vecDown * killScale * 10 )
            entToKill:TakeDamageInfo( dmg )

        end
        -- useful! keeping it!
        --debugoverlay.Box( myPos + vecDown * killScale, mins, maxs, 1, color_white )

    end

    self.jumpingPeak = nil
    self:RunTask( "OnLandOnGround", ent )

end

function ENT:LethalFallDamage()
    if self.ReallyStrong then

        self:EmitSound( "physics/metal/metal_canister_impact_soft2.wav", 150, 60, 1, CHAN_STATIC )
        self:EmitSound( "physics/metal/metal_computer_impact_bullet2.wav", 150, 30, 1, CHAN_STATIC )
        util.ScreenShake( self:GetPos(), 16, 20, 0.4, 3000 )
        util.ScreenShake( self:GetPos(), 1, 20, 2, 8000 )

        for _ = 1, 6 do
            self:EmitSound( table.Random( self.Chunks ), 100, math.random( 115, 120 ) )
            self:EmitSound( table.Random( self.Whaps ), 75, math.random( 115, 120 ) )

        end
    end

    self:TakeDamage( math.huge )

end


function ENT:Approach( pos )
    self.loco:Approach( pos, 1 )
end

--[[------------------------------------
    Name: NEXTBOT:SwitchCrouch
    Desc: (INTERNAL) Change crouch status.
    Arg1: bool | crouch | Should change from stand to crouch, otherwise change from crouch to stand
    Ret1: 
    Overriden to change step height between crouch/standing, prevents bot from sticking to ceiling.
--]]------------------------------------
function ENT:SwitchCrouch( crouch )

    self:SetCrouching( crouch )
    self:SetupCollisionBounds()

    if crouch then
        self.StepHeight = self.CrouchingStepHeight

    elseif not crouch then
        self.StepHeight = self.StandingStepHeight

    end

    self.loco:SetStepHeight( self.StepHeight )

end

-- good for approaching enemy from multiple angles
function ENT:GetPathHalfwayPoint()
    local myPos = self:GetPos()
    if not self:PathIsValid() then return myPos end

    local pathSegs = self:getCachedPathSegments()
    if not pathSegs then return myPos end

    local middlePathSegIndex = math.Round( #pathSegs / 2 )
    local middlePathSeg = pathSegs[ middlePathSegIndex ]
    return middlePathSeg.pos, middlePathSeg

end

-- used in tasks to not call a fail if bot is unstucking
function ENT:primaryPathIsValid()
    if self.isUnstucking then return true end -- dont start new paths
    -- behave normally
    return self:PathIsValid()

end

hook.Add("OnPhysgunPickup","terminatorNextBotResetPhysgunned",function(ply,ent)
    if ent.SBAdvancedNextBot and ent.isTerminatorHunterBased then
        ent.m_Physguned = true
        ent.loco:SetGravity(0)
        ent.lastGroundLeavingPos = ent:GetPos()
    end
end)

hook.Add("PhysgunDrop","terminatorNextBotResetPhysgunned",function(ply,ent)
    if ent.SBAdvancedNextBot and ent.isTerminatorHunterBased then
        ent.m_Physguned = false
        ent.loco:SetGravity(ent.DefaultGravity)
        ent.lastGroundLeavingPos = ent:GetPos()
    end
end)


-- flanking!
local function bearingToPos( pos1, ang1, pos2, ang2 )
    local localPos = WorldToLocal( pos1, ang1, pos2, ang2 )
    local bearing = 180 / math.pi * math.atan2( localPos.y, localPos.x )

    return bearing

end

local hunterIsFlanking
local flankingAvoidAreas

function ENT:AddAreasToFlank( areas, mul )
    for _, avoid in ipairs( areas ) do
        flankingAvoidAreas[ avoid:GetID() ] = mul
        --debugoverlay.Cross( avoid:GetCenter(), 10, 10, color_white, true )

    end
end

function ENT:SetupFlankingPath( destination, areaToFlankAround, flankAvoidRadius )
    if not isvector( destination ) then return end
    flankingAvoidAreas = flankingAvoidAreas or {}
    hunterIsFlanking = true

    if flankAvoidRadius then
        self:flankAroundArea( areaToFlankAround, flankAvoidRadius )

    else
        self:flankAroundCorridorBetween( self:GetPos(), areaToFlankAround:GetCenter() )

    end
    if IsValid( self:GetEnemy() ) then
        self:FlankAroundEasyEntraceToThing( areaToFlankAround:GetCenter(), self:GetEnemy() )

    end
    self:SetupPath2( destination )
    self:endFlankPath()

end

function ENT:flankAroundArea( bubbleArea, bubbleRadius )
    bubbleRadius = math.Clamp( bubbleRadius, 0, 3000 )
    local bubbleCenter = bubbleArea:GetCenter()

    local areas = navmesh.Find( bubbleCenter, bubbleRadius, self.JumpHeight, self.JumpHeight )
    self:AddAreasToFlank( areas, 25 )

end

function ENT:flankAroundCorridorBetween( bubbleStart, bubbleDestination )
    local offsetDirection = DirToPos( bubbleStart, bubbleDestination )
    local offsetDistance = bubbleStart:Distance( bubbleDestination )
    local bubbleRadius = math.Clamp( offsetDistance * 0.45, 0, 2000 )
    local offset = offsetDirection * ( offsetDistance * 0.6 )
    local bubbleCenter = bubbleStart + offset

    local firstBubbleAreas = navmesh.Find( bubbleCenter, bubbleRadius, self.JumpHeight, self.JumpHeight )
    self:AddAreasToFlank( firstBubbleAreas, 25 )

end

function ENT:FlankAroundEasyEntraceToThing( bubbleStart, thing )
    local bubbleDestination = thing:GetPos()
    local offsetDirection = DirToPos( bubbleStart, bubbleDestination )
    local offsetDistance = bubbleStart:Distance( bubbleDestination )

    local secondBubbleAreas = navmesh.Find( bubbleDestination, math.Clamp( offsetDistance * 0.5, 100, 500 ), self.JumpHeight, self.JumpHeight )
    local secondBubbleAreasClipped = {}

    local bitInFrontOffset = offsetDirection * 100
    local positveSideOfPlane = bubbleDestination + bitInFrontOffset
    local negativeSideOfPlane = bubbleStart + bitInFrontOffset + -offsetDirection * offsetDistance

    -- make sure we at least try to avoid going right in front of them
    for _, area in ipairs( secondBubbleAreas ) do
        local areasCenter = area:GetCenter()
        local distToPositive = areasCenter:DistToSqr( positveSideOfPlane )
        local distToNegative = areasCenter:DistToSqr( negativeSideOfPlane )

        if distToPositive < distToNegative then
            table.insert( secondBubbleAreasClipped, area )
            --debugoverlay.Cross( area:GetCenter(), 10, 10, color_white, true )

        end
    end

    self:AddAreasToFlank( secondBubbleAreasClipped, 100 )
end

function ENT:endFlankPath()
    self.flankBubbleCenter = nil
    self.flankBubbleSizeSqr = nil
    hunterIsFlanking = nil
    flankingAvoidAreas = nil
end

--local function isCachedTraversable( area )

function ENT:NavMeshPathCostGenerator( path, area, from, ladder, _, len )
    if not IsValid( from ) then return 0 end
    if not self.loco:IsAreaTraversable( area ) then return -1 end

    local dist = 0
    local addedCost = 0
    local costSoFar = from:GetCostSoFar() or 0

    if IsValid( ladder ) then
        local cost = ladder:GetLength()
        return cost
    elseif len > 0 then
        dist = len
    else
        dist = from:GetCenter():Distance( area:GetCenter() )
    end


    if hunterIsFlanking and flankingAvoidAreas and flankingAvoidAreas[ area:GetID() ] then
        dist = dist * flankingAvoidAreas[ area:GetID() ]
        --debugoverlay.Cross( area:GetCenter(), 10, 10, color_white, true )
    end

    if area:HasAttributes( NAV_MESH_CROUCH ) then
        if hunterIsFlanking then
            -- vents?
            dist = dist * 0.5
        else
            -- its cool when they crouch so dont punish it much
            dist = dist * 1.1
        end
    end

    if area:HasAttributes( NAV_MESH_OBSTACLE_TOP ) then
        dist = dist * 2 -- these usually look goofy
    end

    local sizeX = area:GetSizeX()
    local sizeY = area:GetSizeY()

    if sizeX < 26 or sizeY < 26 then
        -- generator often makes small 1x1 areas with this attribute, on very complex terrain
        if area:HasAttributes( NAV_MESH_NO_MERGE ) then
            dist = dist * 8
        else
            dist = dist * 1.25
        end
    end
    if sizeX > 151 and sizeY > 151 and not hunterIsFlanking then --- mmm very simple terrain
        dist = dist * 0.6
    elseif sizeX > 76 and sizeY > 76 then -- this makes us prefer paths thru simple terrain
        dist = dist * 0.8
    end

    if area:HasAttributes( NAV_MESH_JUMP ) then
        dist = dist * 1.5
    end

    if area:HasAttributes( NAV_MESH_AVOID ) then
        dist = dist * 20
    end

    if from then
        local nav2Id = area:GetID()
        if not istable( navExtraDataHunter.nav1Id ) then goto skipShitConnectionDetection end
        if not navExtraDataHunter.nav1Id.shitConnnections then goto skipShitConnectionDetection end
        if navExtraDataHunter.nav1Id.shitConnnections[nav2Id] then
            addedCost = 1500
            dist = dist * 10
            if not navExtraDataHunter.nav1Id.superShitConnnections then goto skipSuperShitConnectionDetection end
            if navExtraDataHunter.nav1Id.superShitConnnections[nav2Id] then
                addedCost = 180000
            end
            ::skipSuperShitConnectionDetection::
        end
        ::skipShitConnectionDetection::
    end

    if area:HasAttributes( NAV_MESH_TRANSIENT ) then
        dist = dist * 2
    end

    if area:IsUnderwater() then
        dist = dist * 2
    end

    local cost = dist + addedCost + costSoFar

    local deltaZ = from:ComputeAdjacentConnectionHeightChange( area )
    local stepHeight = self.loco:GetStepHeight()
    local jumpHeight = self.loco:GetMaxJumpHeight()
    if deltaZ >= stepHeight then
        if deltaZ >= jumpHeight then return -1 end
        if deltaZ > stepHeight * 4 then
            if hunterIsFlanking then
                cost = cost * 6

            else
                cost = cost * 8

            end
        elseif deltaZ > stepHeight * 2 then
            if hunterIsFlanking then
                cost = cost * 4

            else
                cost = cost * 6

            end
        else
            if hunterIsFlanking then
                cost = cost * 1.5

            else
                cost = cost * 2

            end
        end
    elseif deltaZ <= -self.loco:GetDeathDropHeight() then
        cost = cost * 50000

    elseif deltaZ <= -jumpHeight then
        cost = cost * 4

    elseif deltaZ <= -stepHeight * 3 then
        if hunterIsFlanking then
            cost = cost * 2

        else
            cost = cost * 3

        end
    elseif deltaZ <= -stepHeight then
        if hunterIsFlanking then
            cost = cost * 1.2

        else
            cost = cost * 2

        end
    end

    return cost
end

--[[------------------------------------
    Name: NEXTBOT:SetupPath
    Desc: Creates new PathFollower object and computes path to goal. Invalidates old path.
    Arg1: Vector | pos | Goal position.
    Arg2: (optional) table | options | Table with options:
        `mindist` - SetMinLookAheadDistance
        `tolerance` - SetGoalTolerance
        `generator` - Custom cost generator
        `recompute` - recompute path every x seconds
    Ret1: any | PathFollower object if created succesfully, otherwise false
--]]------------------------------------
function ENT:SetupPath( pos, options )
    self:GetPath():Invalidate()

    options = options or {}
    options.mindist = options.mindist or self.PathMinLookAheadDistance
    options.tolerance = options.tolerance or self.PathGoalTolerance
    options.recompute = options.recompute or self.PathRecompute

    if not options.generator and not self:UsingNodeGraph() then
        options.generator = function( area, from, ladder, elevator, len )
            return self:NavMeshPathCostGenerator( self:GetPath(), area, from, ladder, elevator, len )
        end
    end

    local path = self:UsingNodeGraph() and self:NodeGraphPath() or Path( "Follow" )
    self.m_Path = path

    path:SetMinLookAheadDistance( options.mindist )
    path:SetGoalTolerance( options.tolerance )

    self.m_PathOptions = options
    self.m_PathPos = pos

    if not self:ComputePath( pos, options.generator ) then
        path:Invalidate()
        return false

    end

    return path

end

--[[------------------------------------
    Name: NEXTBOT:ComputePath
    Desc: (INTERNAL) Computes path to goal.
    Arg1: Vector | pos | Goal position.
    Arg2: (optional) function | generator | Custom cost generator for A* algorithm
    Ret1: bool | Path generated succesfully
--]]------------------------------------
function ENT:ComputePath( pos, generator )
    local path = self:GetPath()

    if path:Compute( self, pos, generator ) then
        local ang = self:GetAngles()
        -- path update makes bot look forward on the path
        path:Update( self )
        self:SetAngles( ang )

        return path:IsValid()
    end

    return false

end

function ENT:NotOnNavmesh()
    return not navmesh.GetNearestNavArea( self:GetPos(), false, 25, false, false, -2 ) and self:IsOnGround()

end