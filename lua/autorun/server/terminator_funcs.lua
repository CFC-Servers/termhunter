
local negativeFiveHundredZ = Vector( 0,0,-500 )

terminator_Extras.getNearestNavFloor = function( pos )
    if not pos then return NULL end
    local Dat = {
        start = pos,
        endpos = pos + negativeFiveHundredZ,
        mask = MASK_SOLID
    }
    local Trace = util.TraceLine( Dat )
    if not Trace.HitWorld then return NULL end
    local navArea = navmesh.GetNearestNavArea( Trace.HitPos, false, 2000, false, true, -2 )
    if not navArea then return NULL end
    if not navArea:IsValid() then return NULL end
    return navArea
end

terminator_Extras.getNearestNav = function( pos )
    if not pos then return NULL end
    local Dat = {
        start = pos,
        endpos = pos + negativeFiveHundredZ,
        mask = MASK_SOLID
    }
    local Trace = util.TraceLine( Dat )
    if not Trace.Hit then return NULL end
    local navArea = navmesh.GetNearestNavArea( pos, false, 2000, false, true, -2 )
    if not navArea then return NULL end
    if not navArea:IsValid() then return NULL end
    return navArea
end

terminator_Extras.getNearestPosOnNav = function( pos )
    local result = { pos = nil, area = NULL }
    if not pos then return result end

    local navFound = terminator_Extras.getNearestNav( pos )

    if not navFound then return result end
    if not navFound:IsValid() then return result end

    result = { pos = navFound:GetClosestPointOnArea( pos ), area = navFound }
    return result

end

terminator_Extras.dirToPos = function( startPos, endPos )
    if not startPos then return end
    if not endPos then return end

    return ( endPos - startPos ):GetNormalized()

end

local nookDirections = {
    Vector( 1, 0, 0 ),
    Vector( -1, 0, 0 ),
    Vector( 0, 1, 0 ),
    Vector( 0, -1, 0 ),
    Vector( 0, 0, 1 ),
    Vector( 0, 0, -1 ),
}

terminator_Extras.GetNookScore = function( pos, distance, overrideDirections )
    local directions = overrideDirections or nookDirections
    distance = distance or 800
    local facesBlocked = 0
    for _, direction in ipairs( directions ) do
        local traceData = {
            start = pos,
            endpos = pos + direction * distance,
            mask = MASK_SOLID_BRUSHONLY,

        }

        local trace = util.TraceLine( traceData )
        if not trace.Hit then continue end

        facesBlocked = facesBlocked + math.abs( trace.Fraction - 1 )

    end

    return facesBlocked

end

terminator_Extras.BearingToPos = function( pos1, ang1, pos2, ang2 )
    local localPos = WorldToLocal( pos1, ang1, pos2, ang2 )
    local bearing = 180 / math.pi * math.atan2( localPos.y, localPos.x )

    return bearing

end

terminator_Extras.PosCanSee = function( startPos, endPos, mask )
    if not startPos then return end
    if not endPos then return end

    mask = mask or terminator_Extras.LineOfSightMask

    local trData = {
        start = startPos,
        endpos = endPos,
        mask = mask,
    }
    local trace = util.TraceLine( trData )
    return not trace.Hit, trace

end

terminator_Extras.PosCanSeeComplex = function( startPos, endPos, filter, mask )
    if not startPos then return end
    if not endPos then return end

    local filterTbl = {}
    local collisiongroup = nil

    if IsValid( filter ) then
        filterTbl = table.Copy( filter:GetChildren() )
        table.insert( filterTbl, filter )

        collisiongroup = filter:GetCollisionGroup()

    end

    if not mask then
        mask = bit.bor( CONTENTS_SOLID, CONTENTS_HITBOX )

    end

    local traceData = {
        filter = filterTbl,
        start = startPos,
        endpos = endPos,
        mask = mask,
        collisiongroup = collisiongroup,
    }
    local trace = util.TraceLine( traceData )
    return not trace.Hit, trace

end