if GetObjectName(myHero) ~= "Galio" then return end
---------------------------------------------------------------------------
-----------------------------	   MENU		-----------------------------------
---------------------------------------------------------------------------
Galio = MenuConfig("Galio", "Galio")

Galio:Menu("Keys", "Keys")
Galio.Keys:Key("Combo", "Combo", string.byte(" "))
Galio.Keys:Key("Harass", "Harass", string.byte("X"))
Galio.Keys:DropDown("Priority", "Harass Priority", 6, {"QWE", "EQW", "QE", "WE", "Q", "E"})

Galio:Menu("Spells", "Spells")
--TODO need to impliment
Galio.Spells:Boolean("3R", "R to atleast 3 enemies", true)
Galio.Spells.Boolean("WOM", "Casts W on only Galio", false)


Galio:Menu("Draw", "Drawings")
Galio.Draw:Boolean("Draw", "Draw", true)
Galio.Draw:Boolean("DQ", "Draw Q", true)
Galio.Draw:Boolean("DW", "Draw W", false)
Galio.Draw:Boolean("DE", "Draw E", true)
Galio.Draw:Boolean("DR", "Draw R", false)

Galio:Menu("KS", "Killstuff")
Galio.KS:Boolean("KS", "Killsteal", true)
Galio.KS:Boolean("Ignite","Auto-Ignite", true)


local Enemies = {}
local myHero = GetMyHero()
local galioQCastRange = 940 --Q Cast Range
local galioQSpellRange = 235 --Q Spell Range(Hitbox Range)
local galioWCastRange = 800 --W Cast Range
local galioECastRange = 1180 -- E Cast Range
local galioRCastRange = 600 -- R Cast Range
local galioRSpellRange = 575 -- R Spell Range, decreased range when channel is not completed
local igniteCastRange = 650 -- Ignite Cast Range
local QRDY, WRDY, ERDY, RRDY, IRDY = 0, 0, 0, 0, 0 -- Flags to keep tack of spell cooldowns
local QDmg, EDmg, RDmg, AP, xIgnite = 0, 0, 0, 0, 0, 0 -- Damage done by spells


-- initializes Flags to keep tack of spell cooldowns
local function GetSpellCD()
	QRDY = GetCastLevel(myHero, _Q) > 0 and CanUseSpell(myHero, _Q) == 0 and 1 or 0
	WRDY = GetCastLevel(myHero, _W) > 0 and CanUseSpell(myHero, _W) == 0 and 1 or 0
	ERDY = GetCastLevel(myHero, _E) > 0 and CanUseSpell(myHero, _E) == 0 and 1 or 0
	RRDY = GetCastLevel(myHero, _R) > 0 and CanUseSpell(myHero, _R) == 0 and 1 or 0
end
-- Checks Ignite CD
local function GetIgniteCD()
	IRDY = Ignite and CanUseSpell(myHero, Ignite) == 0 and 1 
	or 0
end

local function Round(val, decimal)
	return decimal and math.floor( (val * 10 ^ decimal) + 0.5) / (10 ^ decimal) 
	or math.floor(val + 0.5)
end

local function Mana(mq,mw,me,mr)
	local Qmana = 5 * GetCastLevel(myHero, _E) + 55
	local Wmana = 60
	local Emana = 5 * GetCastLevel(myHero, _E) + 55
	local Rmana = 100
	return Qmana * mq + Wmana * mw + Emana * me + Rmana * mr < GetCurrentMana(myHero) and 1 or 0
end

-- function to calculate Spell damage
local function Damage()
	AP = GetBonusAP(myHero)
	QDmg = GetCastLevel(myHero,_Q) * 55 + 25 + .60 * AP
	EDmg = GetCastLevel(myHero,_E) * 15 + 45 + .50 * AP
  local numOfHits = NumOfHits();
	RDmg = GetCastLevel(myHero,_R) * 100 + 100 + .60 * AP + numOfHits * GetCastLevel(myHero,_R) * 10 + 10 * 0.06*AP
	xIgnite = (GetLevel(myHero) * 20 + 50) * IRDY
end

--Number of hits taken by Galio when he is channeling his ult
--TODO needs to implement
local function NumOfHits()
  return 3
end

--Counts the enemeys in range from a unit(Default: myHero). Used for calculating no of enemies for casting R
local function CountEnemyHeroInRange(object, range)
	object = object or myHero
	local eEnemies = {}
	for i = 0, #Enemies do
		local enemy = Enemies[i]
		if enemy and enemy ~= object and not IsDead(enemy) and GetDistance(object, enemy) <= range then
			table.insert(eEnemies, enemy)
		end
	end
	return #eEnemies
end


local function IsIgnited(o)
	return GotBuff(o, "summonerdot") ~= 0 and 1 
	or 0
end

local function IsOrWillBeIgnited(o)
	return IRDY == 1 and 1 
	or IsIgnited(o) == 1 and 1 
	or 0
end

--Casts Q on a uint
local function doQ(o)
	if GetDistance(o) < galioQCastRange then
		local QPred = GetPredictionForPlayer(GetOrigin(myHero), o ,GetMoveSpeed(o) ,1532, 250 + GetLatency(), galioQCastRange-5, 75, true, true)
		if QPred.HitChance == 1 then
			CastSkillShot(_Q, QPred.PredPos)
		end
	end
end
--Casts W on a uint
local function doW(o)
  if Galio.Spells.WOM:Value() then
    CastSpell(_W)
	elseif GetDistance(o) < galioWCastRange then
		CastTargetSpell(o, _W)
	end
end

--Casts E on a unit
local function doE(o)
  if GetDistance(o) < galioECastRange then
		local QPred = GetPredictionForPlayer(GetOrigin(myHero), o ,GetMoveSpeed(o) ,1532, 250 + GetLatency(), galioECastRange-5, 75, true, false)
		if QPred.HitChance == 1 then
			CastSkillShot(_Q, QPred.PredPos)
		end
	end
end
--Casts R 
local function dooR(o)
	if GetDistance(o) < galioRSpellRange then
		CastSpell(_R)
	end
end
--Checks if Q can hit the unit
local function QCanHit(unit)
	local QPred = GetPredictionForPlayer(GetOrigin(myHero),unit,GetMoveSpeed(unit),1532,250 + GetLatency(),galioQCastRange - 5,75,true,true)
	local CollisionE = Collision(galioQCastRange - 5 , 1532, 250 + GetLatency(), 75)
	local CollisionCheck, Objects = CollisionE:__GetMinionCollision(myHero,Point(QPred.PredPos.x, QPred.PredPos.z),ENEMY)
	if QPred.PredPos and QPred.HitChance == 1 then
		if not CollisionCheck then
			return true
		else
			return false
		end
	else
		return false
	end
end

-- Draws Circles
OnDraw(function(myHero)
	if Galio.Draw.Draw:Value() then
		dQ = QRDY == 1 and Galio.Draw.DQ:Value() and galioQCastRange or 0
		dW = WRDY == 1 and Galio.Draw.DW:Value() and galioWCastRange or 0
		dE = ERDY == 1 and Galio.Draw.DE:Value() and galioECastRange or 0
		dR = RRDY == 1 and Galio.Draw.DR:Value() and galioRCastRange or 0
		if dQ ~= 0 then DrawCircle(GetOrigin(myHero), dQ, 0, 0, 0xffff0000) end
		if dW ~= 0 then DrawCircle(GetOrigin(myHero), dW, 0, 0, 0xffff0000) end
		if dE ~= 0 then DrawCircle(GetOrigin(myHero), dE, 0, 0, 0xffff0000) end
		if dR ~= 0 then DrawCircle(GetOrigin(myHero), dR, 0, 0, 0xffff0000) end
  end
end


OnTick(function(myHero)
	Enemies = GetEnemyHeroes()
	target = GetCurrentTarget()
	range = (QRDY > 0 and (target and QCanHit(target) or true) and QRDY * galioQCastRange) or (ERDY > 0 and ERDY * galioECastRange) or (RRDY > 0 and RRDY * galioRCastRange) or (IRDY * igniteCastRange) or 0 
	resetVariables()
	if Galio.Keys.Combo:Value() then
		Combo()
	elseif Galio.Keys.Harass:Value() then
		Harass()
	end
	if Galio.KS.Ignite:Value() then
		AutoIgnite()
	end
end)

-- AutoIgnite when target is killable
local function AutoIgnite()
	for i = 1, #Enemies do
		local Target = Enemies[i]
		if ValidTarget(Target) then
			local HP = GetCurrentHP(Target)
			if HP <= xIgnite and GetDistance(Target) <= 600 then
				if QRDY == 1 and HP <= QDmg then
					doQ(Target)    
				elseif ERDY == 1 and HP <= EDmg then
					doE(Target)
				else
					if IRDY == 1 then
						CastTargetSpell(Target, Ignite)
					end
				end
			end
		end
	end
end

-- Harass based on priority
local function Harass()
	if ValidTarget(target) then
		if GetDistance(target) < range then
			if Galio.Keys.Priority:Value() == 1 then
				doQ(target)
				CastSpell(_W)	
        doE(target)
			elseif Galio.Keys.Priority:Value() == 2 then
				doE(target)
        doQ(target)
				CastSpell(_W)	
			elseif Galio.Keys.Priority:Value() == 3 then
				doQ(target)    
        doE(target)
			elseif Galio.Keys.Priority:Value() == 4 then
				CastSpell(_W)	
        doE(target)
			elseif Galio.Keys.Priority:Value() == 5 then
				doQ(target)  
			elseif Galio.Keys.Priority:Value() == 6 then
				doE(target)
			end
		end
	end
end

local function Combo()
	if ValidTarget(target) then
		if GetDistance(target) < range then
			myRange = 1180
			local DIST = GetDistance(target)
			if DIST < range then
				local armor = GetMagicResist(target)
			  	local hp = GetCurrentHP(target)
			  	local mhp = GetMaxHP(target)
			  	local hpreg = GetHPRegen(target) * (1 - (IsOrWillBeIgnited(target) * .5))
				local Health = hp * ((100 + ((armor - GetMagicPenFlat(myHero)) * GetMagicPenPercent(myHero))) * .01) + hpreg * 6 + GetMagicShield(target)
				local maxHealth = mhp * ((100 + ((armor - GetMagicPenFlat(myHero)) * GetMagicPenPercent(myHero))) * .01) + hpreg * 6 + GetMagicShield(target)
        --TODO needs to implement
				local TotalDamage = 0;
        local TotalDamageNoR = 0;
        local TotalDamageNoRNoIgnite = 0;
				if Health < TotalDamageNoR then
					if ERDY == 1 then doE(target) end
					if QRDY == 1 then doQ(target) end
					if WRDY == 1 then doW(target) end
					if Galio.KS.Ignite:Value() and Health > TotalDamageNoRNoIgnite and DIST < 650 then
						CastTargetSpell(target, Ignite)
					end
				elseif Health < TotalDamage then
					if ERDY == 1 then doE(target) end
					if QRDY == 1 then doQ(target) end
					if WRDY == 1 then doW(target) end
					if Galio.KS.Ignite:Value() and Health > TotalDamageNoIgnite and DIST < 650 then
						CastTargetSpell(target, Ignite)
					end
			end
		end
	end
end
print("Galio loaded")	