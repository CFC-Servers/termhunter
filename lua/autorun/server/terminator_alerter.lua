if not SERVER then return end

local function sqrDistLessThan( Dist1, Dist2 )
    Dist2 = Dist2 ^ 2
    return Dist1 < Dist2
end

local function terminatorsSendSoundHint( thing, src, range, valuable )
    if not range then return end
    if range < 200 then return end -- dont waste perf on useless sounds!
    if not src then return end
    for _ = 1, 10 do
        if IsValid( thing ) and thing.GetParent and IsValid( thing:GetParent() ) then
            thing = thing:GetParent()

        else
            break

        end
    end
    local thingInternal = thing or NULL
    if thingInternal.usedByTerm then return end
    local terms = ents.FindByClass( "sb_advanced_nextbot_terminator_hunter*" )
    --[[
    if thing and not thing.isTerminatorHunterChummy then
        debugoverlay.Sphere( src, range, math.Clamp( range / 1000, 0.5, 10 ) )

        print( thing, range )

    end--]]

    for _, currTerm in pairs( terms ) do
        if IsValid( thing ) and currTerm.isTerminatorHunterChummy == thing.isTerminatorHunterChummy then goto nextSoundHintPlease end
        local distToSrc = currTerm:GetPos():DistToSqr( src )
        local isMe = thing == currTerm
        if sqrDistLessThan( distToSrc, range ) and not isMe then
            --debugoverlay.Line( currTerm:GetPos(), src, 10, Vector(255,255,255), true )

            currTerm:SaveSoundHint( src, valuable, thing )

        end
        ::nextSoundHintPlease::

    end
end

local squareVarQuiet = 1.5
local squareVarLoud = 1.65

local customRanges = {
    ["weapon_pistol"] = 7000,
    ["weapon_357"] = 8000,
    ["weapon_smg1"] = 7000,
    ["weapon_ar2"] = 8000,
    ["weapon_shotgun"] = 8000,
}

local function bulletFireThink( entity, data )
    if not IsValid( entity ) then return end

    local range = nil
    local weap = nil
    if entity:IsNPC() or entity:IsPlayer() then
        weap = entity:GetActiveWeapon()
    end
    local customRange = nil
    if IsValid( weap ) then
        customRange = customRanges[ weap:GetClass() ]
    end
    if customRange then
        range = customRange
    elseif not customRange then
        local dmg = 60
        if data.Damage > 0 then
            dmg = math.Round( data.Damage )
        end
        local num = 1
        if data.Num > 1 then
            num = math.Clamp( data.Num / 2, 1, math.huge )
        end
        local totalDmg = dmg * num
        range = math.Clamp( totalDmg * 200, 3000, 10000 ) -- bigger gunz are louder
    end

    local src = data.Src
    terminatorsSendSoundHint( entity, src, range, true )

end
hook.Add( "EntityFireBullets", "straw_termalerter_firebullets", bulletFireThink )



-- stick our fingers in emithint
sound._EmitHint = sound._EmitHint or sound.EmitHint
sound.EmitHint = function( ... )
    hook.Run( "StrawSoundEmitHint", ... )
    return sound._EmitHint( ... )
end

local function soundHintThink( hint, pos, volume, _, owner )

    local combat = bit.band( hint, SOUND_COMBAT ) > 0
    local danger = bit.band( hint, SOUND_DANGER ) > 0

    if not combat and not danger then return end

    local radius = volume * 5 -- example, 600 to 3000 radius

    local valuable = nil
    if owner and owner:IsPlayer() then
        valuable = true
    end

    terminatorsSendSoundHint( owner, pos, radius, valuable )

end
hook.Add( "StrawSoundEmitHint", "straw_termalerter_soundhint", soundHintThink )


-- bl damage
util._NextBotHook_BlastDamage = util._NextBotHook_BlastDamage or util.BlastDamage
util.BlastDamage = function( ... )
    hook.Run( "StrawBlastDamage", ... )
    return util._NextBotHook_BlastDamage( ... )
end

local function blastDamageHintThink( _, attacker, damageOrigin, damageRadius, damage )

    local radiusComponent = damageRadius * 0.2
    local volume = math.Clamp( damage * radiusComponent, 1000, 10000 )

    terminatorsSendSoundHint( attacker, damageOrigin, volume, true )

end
hook.Add( "StrawBlastDamage", "straw_termalerter_blastdamage", blastDamageHintThink )


-- bl damage info
util._NextBotHook_BlastDamageInfo = util._NextBotHook_BlastDamageInfo or util.BlastDamageInfo
util.BlastDamageInfo = function( ... )
    hook.Run( "StrawBlastDamageInfo", ... )
    return util._NextBotHook_BlastDamageInfo( ... )
end

local function blastDamageInfoHintThink( dmg, damageOrigin, damageRadius )

    local damage = dmg:GetDamage()
    local radiusComponent = damageRadius * 0.2
    local volume = math.Clamp( damage * radiusComponent, 1000, 10000 )

    terminatorsSendSoundHint( attacker, damageOrigin, volume, true )

end

hook.Add( "StrawBlastDamageInfo", "straw_termalerter_blastdamageinfo", blastDamageInfoHintThink )



-- env_explosion reading
local function explosionHintThink( entity )
    if not IsValid( entity ) then return end
    if entity:GetClass() ~= "env_explosion" then return end

    timer.Simple( engine.TickInterval(), function()

        if not IsValid( entity ) then return end
        local keys = entity:GetKeyValues()

        local damage = keys["iMagnitude"] or 0
        local radius = damage
        if keys["iRadiusOverride"] or 0 > 0 then
            radius = keys["iRadiusOverride"]
        end
        local pos = entity:GetPos()

        local radiusComponent = radius * 0.2
        local volume = math.Clamp( damage * radiusComponent, 1000, 10000 )

        terminatorsSendSoundHint( attacker, pos, volume, true )

    end )
end

hook.Add( "OnEntityCreated", "straw_termalerter_explosioninfo", explosionHintThink )


local function handleNormalSound( ent, pos, level, name )
    if pos == Vector() then return end

    local squareInternal = squareVarQuiet
    if level and level >= 80 then
        squareInternal = squareVarLoud
    end

    local volume = ( level^squareInternal )
    volume = math.Clamp( volume, 5, 18000 ) -- exponential?
    --print( volume, class, soundLvl2 )

    terminatorsSendSoundHint( ent, pos, volume, false )

end

-- fingies be stucketh
sound._StrawTakeoverPlay = sound._StrawTakeoverPlay or sound.Play
sound.Play = function( ... )
    hook.Run( "StrawSoundPlayHook", ... )
    return sound._StrawTakeoverPlay( ... )
end

local function soundPlayThink( name, pos, level, _, volume )

    if not name then return end
    if not pos then return end

    volume = volume or 1
    level = level or 75

    local volumeAdjusted = level * volume
    timer.Simple( engine.TickInterval(), function()
        handleNormalSound( nil, pos, volumeAdjusted, name )
    end )

end

hook.Add( "StrawSoundPlayHook", "straw_termalerter_soundplayhook", soundPlayThink )



-- sound reading!?!??
local function emitSoundThink( soundDat )
    local entity = soundDat.Entity
    if not IsValid( entity ) then return end
    local class = entity:GetClass()
    local valid = nil
    if string.StartWith( class, "item" ) then valid = true end
    if string.StartWith( class, "prop" ) then valid = true end
    if string.StartWith( class, "player" ) then valid = true end
    if string.StartWith( class, "func" ) then valid = true end
    if entity.IsNPC and entity:IsNPC() then valid = true end
    if entity.IsNextBot and entity:IsNextBot() then valid = true end
    if entity.IsWeapon and entity:IsWeapon() then valid = true end
    if not valid then return end

    timer.Simple( engine.TickInterval(), function()

        if not IsValid( entity ) then return end
        local soundLvl = soundDat.SoundLevel * soundDat.Volume

        local pos = entity:GetPos()
        handleNormalSound( entity, pos, soundLvl, soundDat.SoundName )

    end )
end

hook.Add( "EntityEmitSound", "straw_termalerter_soundinfo", emitSoundThink )