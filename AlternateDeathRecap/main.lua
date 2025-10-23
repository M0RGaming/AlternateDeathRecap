ADR = ADR or {}
ADR.name = "AlternateDeathRecap" 


--a = {}

local allowedResults = {
	[ACTION_RESULT_DOT_TICK] = "damage",
	[ACTION_RESULT_DOT_TICK_CRITICAL] = "damage",
	[ACTION_RESULT_CRITICAL_DAMAGE] = "damage",
	[ACTION_RESULT_DAMAGE] = "damage",
	[ACTION_RESULT_BLOCKED_DAMAGE] = "damage",
	[ACTION_RESULT_DAMAGE_SHIELDED] = "damage",
	[ACTION_RESULT_PRECISE_DAMAGE] = "damage",
	[ACTION_RESULT_WRECKING_DAMAGE] = "damage",
	[ACTION_RESULT_FALL_DAMAGE] = "damage",
	[ACTION_RESULT_FALLING] = "damage",

	[ACTION_RESULT_CRITICAL_HEAL] = "heal",
	[ACTION_RESULT_HEAL] = "heal",
	[ACTION_RESULT_HOT_TICK] = "heal",
	[ACTION_RESULT_HOT_TICK_CRITICAL] = "heal",
	--[ACTION_RESULT_HOT] = "heal",

	[ACTION_RESULT_ABSORBED] = "special",
	[ACTION_RESULT_HEAL_ABSORBED] = "special",
	[ACTION_RESULT_DODGED] = "special",
	[ACTION_RESULT_INTERRUPT] = "special",
	[ACTION_RESULT_REFLECTED] = "special",
	[ACTION_RESULT_ROOTED] = "special",
	[ACTION_RESULT_SILENCED] = "special",
	[ACTION_RESULT_SNARED] = "special",
	[ACTION_RESULT_STUNNED] = "special",
	[ACTION_RESULT_FEARED] = "special",

}



local lastResult = 0
function ADR.OnCombatEvent(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, _log, sourceUnitID, targetUnitID, abilityID, overflow)
	
	--a[#a+1] = {eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, _log, sourceUnitID, targetUnitID, abilityID, overflow}
	--Fix ^M or ^Mx or similar unwanted characters on the sourceName.
	--if string.find(sourceName, "^", 1, true) ~= nil then sourceName = string.sub(sourceName, 1, (string.find(sourceName, "^", 1, true) - 1)) end
	sourceName = zo_strformat(SI_UNIT_NAME, sourceName)

	--We don't want revive snare/stun events to be tracked.
	if string.find(string.lower(abilityName), "revive") ~= nil then return end
	--We only want to display this once, so only one type is being tracked with all other types returning here.
	if string.find(string.lower(abilityName), "break free") ~= nil and sourceType ~= COMBAT_UNIT_TYPE_PLAYER then return end
	--I don't know what this 0 damage attack is that I get from random bosses, but I don't want to see it.
	if string.find(string.lower(abilityName), "vigilance") ~= nil then return end
	

	if lastResult == ACTION_RESULT_DAMAGE_SHIELDED then -- next attack will be the thing which causes the sheild to take damage
		if ADR.attackList.size ~= 0 then
			--[[
			attackInfo = {
				resultType = result,
				attackName = abilityName,
				attackDamage = hitValue,
				attackOverflow = overflow,
				attackIcon = attack_icon,
				wasKillingBlow = false,
				lastUpdateAgoMS = GetGameTimeMilliseconds(),
				displayTimeMS = nil,
				attackerName = sourceName,
				currentHealth = health,
				currentMaxHealth = maxHealth,
			}
			--]]
			local attackData = ADR.attackList.data[ADR.attackList.back]
			attackData.attackName = string.format("%s (%s)", abilityName, attackData.attackName)
			lastResult = 0
			if hitValue == 0 then return end
		end
	end


	local resultType = allowedResults[result]
	if resultType == nil then return end

	lastResult = result
	

	local attack_icon = GetAbilityIcon(abilityID)
	
	local health, maxHealth = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_HEALTH)
	
	--d("Ability Pre everything "..abilityName.." with result ".. result.." and hitValue "..hitValue)	

	--track skills that cost health.
	--Doesn't track health-over-time skills.
	if sourceType == COMBAT_UNIT_TYPE_PLAYER then 
		if ADR.healthCostSkills[abilityName] == true then
			result = ACTION_RESULT_DAMAGE
			hitValue = GetAbilityCost(abilityID, COMBAT_MECHANIC_FLAGS_HEALTH, nil, "player")
		end
		
		--Only track one cast per skill.
		if ADR.lastCastTimes[abilityName] == nil or (GetGameTimeMilliseconds() - ADR.lastCastTimes[abilityName]) > 500 then -- imo this shouldnt be here, might mess with data
			ADR.lastCastTimes[abilityName] = GetGameTimeMilliseconds()
		else
			return
		end
	end
	

	--d("Ability Pre Filter "..abilityName.." with result".. result.." and hitValue "..hitValue)	
	--Don't track events with empty info.
	if sourceName == "" or
		abilityName == "" or
		attack_icon == "/esoui/art/icons/icon_missing.dds" then
			return
	end

	--d("Ability initial "..abilityName.." with result ".. result.." and hitValue "..hitValue)	
	
	local attackInfo = {
		resultType = result,
		attackName = abilityName,
		attackDamage = hitValue,
		attackOverflow = overflow,
		attackIcon = attack_icon,
		wasKillingBlow = false,
		lastUpdateAgoMS = GetGameTimeMilliseconds(),
		displayTimeMS = nil,
		attackerName = sourceName,
		currentHealth = health,
		currentMaxHealth = maxHealth,
	}

	if resultType == "damage" then
		if attackInfo.attackOverflow ~= 0 then
			attackInfo.wasKillingBlow = true
		end
	elseif (resultType == "heal" and hitValue == 0) then
		return
	elseif resultType == "special" then
		if not (result == ACTION_RESULT_ABSORBED  or 
			(result == ACTION_RESULT_HEAL_ABSORBED and ADR.savedVariables.trackHealAbsorb) or 
			(result == ACTION_RESULT_DODGED and ADR.savedVariables.trackDodged) or 
			(result == ACTION_RESULT_INTERRUPT and ADR.savedVariables.trackInterrupted) or
			result == ACTION_RESULT_REFLECTED or 
			(result == ACTION_RESULT_ROOTED and ADR.savedVariables.trackRooted) or 
			(result == ACTION_RESULT_SILENCED and ADR.savedVariables.trackSilenced) or 
			(result == ACTION_RESULT_SNARED and ADR.savedVariables.trackSnared) or 
			(result == ACTION_RESULT_STUNNED and ADR.savedVariables.trackStunned) or 
			(result == ACTION_RESULT_FEARED and ADR.savedVariables.trackFeared) ) then
				return
			end
	end
	ADR.EnqueueAttack(attackInfo)
	--ADR.EnqueueAttack(attackInfo)
	--ADR.EnqueueAttack(attackInfo) -- TODO REMOVE THESE EXTRAS
end
--[[
function ADR.setupRecap()
	-- ZO_DeathRecapScrollContainerScrollChildAttacks																				Type: Control
	--  ZO_DeathRecapScrollContainerScrollChildAttacks1																				Type:
	--		($parent)Icon								ZO_DeathRecapScrollContainerScrollChildAttacks1Icon							Type:
	--			($parent)Border							ZO_DeathRecapScrollContainerScrollChildAttacks1IconBorder					Type:
	--				($parent) KeyboardFrame				ZO_DeathRecapScrollContainerScrollChildAttacks1IconBorderKeyboardFrame		Type:
	--				($parent) GamepadFrame				ZO_DeathRecapScrollContainerScrollChildAttacks1IconBorderGamepadFrame		Type:
	--			($parent)BossBorder						ZO_DeathRecapScrollContainerScrollChildAttacks1IconBossBorder				Type:
	--				($parent) KeyboardFrame				ZO_DeathRecapScrollContainerScrollChildAttacks1IconBossBorderKeyboardFrame	Type:
	--				($parent) GamepadFrame				ZO_DeathRecapScrollContainerScrollChildAttacks1IconBossBorderGamepadFrame	Type:
	--		($parent)SkillStyle							ZO_DeathRecapScrollContainerScrollChildAttacks1SkillStyle					Type:
	--			($parent)Icon							ZO_DeathRecapScrollContainerScrollChildAttacks1SkillStyleIcon				Type:
	--		($parent)NumAttackHits						ZO_DeathRecapScrollContainerScrollChildAttacks1NumAttackHits				Type:
	--			($parent)Count							ZO_DeathRecapScrollContainerScrollChildAttacks1NumAttackHitsCount			Type: Label
	--			($parent)HitIcon						ZO_DeathRecapScrollContainerScrollChildAttacks1NumAttackHitsHitIcon			Type:
	--			($parent)KillIcon						ZO_DeathRecapScrollContainerScrollChildAttacks1NumAttackHitsKillIcon		Type:
	--		($parent)Text								ZO_DeathRecapScrollContainerScrollChildAttacks1Text							Type:
	--			($grandparent)DamageLabel				ZO_DeathRecapScrollContainerScrollChildAttacks1DamageLabel					Type:
	--			($grandparent)Damage					ZO_DeathRecapScrollContainerScrollChildAttacks1Damage						Type:
	--			($grandparent)AttackText				ZO_DeathRecapScrollContainerScrollChildAttacks1AttackText					Type:
	--				($parent) AttackerName				ZO_DeathRecapScrollContainerScrollChildAttacks1AttackTextAttackerName		Type:
	--				($parent) AttackName				ZO_DeathRecapScrollContainerScrollChildAttacks1AttackTextAttackName			Type:

	ADR.lastCastTimes = {}

	--wait for the controls to be made before modifying them.
	zo_callLater(function()
		--Skull icon.
		ZO_DeathRecapScrollContainerScrollChildAttacksKillingBlowIcon:SetHidden(true)

		--Hide preexisting compact text.
		for i = 1, 50 do
			local currentRow = ZO_DeathRecapScrollContainerScrollChildAttacks:GetNamedChild(tostring(i))
			if currentRow == nil then break end
			local compactText = currentRow:GetNamedChild("Compact")
			if compactText == nil then break end
			compactText:SetHidden(true)
		end

		local finalizedAttackList = ADR.GetOrderedList()
		
		--Update display times
		for k, v in ipairs(finalizedAttackList) do
			v.displayTimeMS = finalizedAttackList[#finalizedAttackList].lastUpdateAgoMS - v.lastUpdateAgoMS
		end
	
		for i = 1, #finalizedAttackList do
			local rowData = finalizedAttackList[i]

			local currentRow = ZO_DeathRecapScrollContainerScrollChildAttacks:GetNamedChild(tostring(i))
			
			if ADR.savedVariables.isCompact == false then
				--Default mode.
				currentRow:SetDimensionConstraints(nil, 64, nil, nil)

				--Change icon texture
				local attack_icon = currentRow:GetNamedChild("Icon")
				attack_icon:SetTexture(rowData.attackIcon)
				
				--Display timeline using these controls.
				local numAttackHits = currentRow:GetNamedChild("NumAttackHits")
				local attackCount = numAttackHits:GetNamedChild("Count")

				numAttackHits:SetHidden(false)
				if rowData.displayTimeMS ~= nil then 
					attackCount:SetHidden(false)
					attackCount:SetText("-"..tostring(zo_roundToNearest(rowData.displayTimeMS/1000, .01)).."s")
				else
					attackCount:SetHidden(true)
				end
				numAttackHits:GetNamedChild("HitIcon"):SetHidden(true)
				numAttackHits:GetNamedChild("KillIcon"):SetHidden(true)
				
				numAttackHits:ClearAnchors()
				numAttackHits:SetAnchor(RIGHT, attack_icon, LEFT, -15, -10)
				
				--HP display using new control.
				local health_display = GetControl(currentRow:GetName().."Health")
				if health_display == nil then
					health_display = CreateControl(currentRow:GetName().."Health", currentRow, CT_LABEL)
					health_display:SetHidden(false)
					health_display:SetFont("ZoFontGamepad22")
					health_display:SetColor(1, 0.25, 0.25, 1)
					health_display:SetAnchor(TOPRIGHT, attackCount, BOTTOMRIGHT, 0, -2)
				end
				health_display:SetHidden(false)
				health_display:SetText("HP: "..ZO_CommaDelimitDecimalNumber(rowData.currentHealth).."/"..ZO_CommaDelimitDecimalNumber(rowData.currentMaxHealth))
				
				--Set damage and label
				local damageLabel = currentRow:GetNamedChild("DamageLabel")
				local damageText = currentRow:GetNamedChild("Damage")
				if rowData.resultType == ACTION_RESULT_HEAL or
					rowData.resultType == ACTION_RESULT_HOT_TICK or
					rowData.resultType == ACTION_RESULT_HOT then
						damageLabel:SetText("HEAL")
						damageText:SetText(ZO_CommaDelimitNumber(rowData.attackDamage))
						damageText:SetColor(0, 1, 0, 1)
				elseif rowData.resultType == ACTION_RESULT_CRITICAL_HEAL or 
						rowData.resultType == ACTION_RESULT_HOT_TICK_CRITICAL then
							damageLabel:SetText("HEAL")
							damageText:SetText(ZO_CommaDelimitNumber(rowData.attackDamage).."!")
							damageText:SetColor(0, 1, 0, 1)
				elseif rowData.resultType == ACTION_RESULT_ABSORBED then
					damageLabel:SetText("ABSORB")
					damageText:SetText(ZO_CommaDelimitNumber(rowData.attackDamage))
					damageText:SetColor(0, 0, 1, 1)
				elseif rowData.resultType == ACTION_RESULT_HEAL_ABSORBED then
					damageLabel:SetText("HEAL ABSORB")
					damageText:SetText(ZO_CommaDelimitNumber(rowData.attackDamage)) 
					damageText:SetColor(0, 1, 1, 1)
				elseif rowData.resultType == ACTION_RESULT_DODGED or rowData.attackName == "Roll Dodge" then
					damageLabel:SetText("DODGE")
					damageText:SetText("")
				elseif rowData.resultType == ACTION_RESULT_ROOTED then
					damageLabel:SetText("ROOT")
					damageText:SetText("")
				elseif rowData.resultType == ACTION_RESULT_FEARED then
					damageLabel:SetText("FEARED")
					damageText:SetText("")
				elseif rowData.resultType == ACTION_RESULT_REFLECTED then
					damageLabel:SetText("REFLECT")
					damageText:SetText("")
				elseif rowData.resultType == ACTION_RESULT_INTERRUPT then
					damageLabel:SetText("INTERRUPT")
					damageText:SetText("")
				elseif rowData.resultType == ACTION_RESULT_SILENCED then
					damageLabel:SetText("SILENCED")
					damageText:SetText("")
				elseif rowData.resultType == ACTION_RESULT_SNARED then
					damageLabel:SetText("SNARED")
					damageText:SetText("")
				elseif rowData.resultType == ACTION_RESULT_STUNNED then
					damageLabel:SetText("STUNNED")
					damageText:SetText("")
				elseif rowData.attackName == "Break Free" then
					damageLabel:SetText("BREAK FREE")
					damageText:SetText("")
				elseif rowData.resultType == ACTION_RESULT_DAMAGE_SHIELDED then
					damageLabel:SetText("DMG")
					damageText:SetText("("..ZO_CommaDelimitNumber((rowData.attackDamage + rowData.attackOverflow))..")" )
					damageText:SetColor(1, 0, 0, 1)
				elseif rowData.resultType == ACTION_RESULT_BLOCKED_DAMAGE then
					damageLabel:SetText("DMG")
					damageText:SetText(ZO_CommaDelimitNumber(rowData.attackDamage + rowData.attackOverflow).."*" )
					damageText:SetColor(1, 0, 0, 1)
				elseif rowData.resultType == ACTION_RESULT_DOT_TICK_CRITICAL or
						rowData.resultType == ACTION_RESULT_CRITICAL_DAMAGE then
							damageLabel:SetText("DMG")
							damageText:SetText((rowData.attackDamage + rowData.attackOverflow).."!")
							damageText:SetColor(1, 0, 0, 1)
				else --regular damage.
					damageLabel:SetText("DMG")
					damageText:SetText(ZO_CommaDelimitNumber(rowData.attackDamage + rowData.attackOverflow))
					damageText:SetColor(1, 0, 0, 1)
				end
				
				local attackerName = currentRow:GetNamedChild("AttackText"):GetNamedChild("AttackerName")
				local attackName = currentRow:GetNamedChild("AttackText"):GetNamedChild("AttackName")
				
				attackName:ClearAnchors()
				attackName:SetAnchor(TOPLEFT, attackerName, BOTTOMLEFT, 0, 2)
				attackName:SetAnchor(TOPRIGHT, attackerName, BOTTOMRIGHT, 0, 2)
				attackName:SetText(rowData.attackName)
				attackerName:SetHidden(false)
				attackerName:SetText(rowData.attackerName)
					
				--avoid the need to wait for animations.
				attack_icon:SetAlpha(1)
				attack_icon:SetScale(1)
				attack_icon:SetHidden(false)
				currentRow:GetNamedChild("Text"):SetAlpha(1)
				currentRow:GetNamedChild("Text"):SetHidden(false)
				currentRow:GetNamedChild("Icon"):SetHidden(false)
				currentRow:GetNamedChild("NumAttackHits"):SetHidden(false)
		
			else
				--Compact mode.
				currentRow:SetDimensionConstraints(nil, nil, nil, 30)

				currentRow:GetNamedChild("Icon"):SetHidden(true)
				currentRow:GetNamedChild("NumAttackHits"):SetHidden(true)
				currentRow:GetNamedChild("Text"):SetHidden(true)

				local health_display = GetControl(currentRow:GetName().."Health")
				if health_display ~= nil then
					health_display:SetHidden(true)
				end

				local compactText = GetControl(currentRow:GetName().."Compact")
				local compactTextTimer, compactTextNumber, compactTextLabel, compactText_by, compactTextAttack, compactText_from, compactTextAttacker, compactTextHealth
				if compactText == nil then
					compactText = CreateControl(currentRow:GetName().."Compact", currentRow, CT_CONTROL)
					compactText:SetHidden(false)
					compactText:SetAnchor(TOPLEFT, currentRow, TOPLEFT, -10, 0)

					compactTextTimer = CreateControl(compactText:GetName().."Timer", compactText, CT_LABEL)
					compactTextTimer:SetAnchor(TOPLEFT, compactText, TOPLEFT, 0, 0)
					compactTextTimer:SetFont("ZoFontGamepad27")

					compactTextNumber = CreateControl(compactText:GetName().."Number", compactText, CT_LABEL)
					compactTextNumber:SetAnchor(TOPLEFT, compactTextTimer, TOPRIGHT, 8, 0)
					compactTextNumber:SetFont("ZoFontGamepad27")

					compactTextLabel = CreateControl(compactText:GetName().."Label", compactText, CT_LABEL)
					compactTextLabel:SetAnchor(TOPLEFT, compactTextNumber, TOPRIGHT, 8, 0)
					compactTextLabel:SetColor(197/255, 194/255, 158/255, 1)
					compactTextLabel:SetFont("ZoFontGamepad27")

					compactText_by = CreateControl(compactText:GetName().."By", compactText, CT_LABEL)
					compactText_by:SetAnchor(TOPLEFT, compactTextLabel, TOPRIGHT, 8, 0)
					compactText_by:SetFont("ZoFontGamepad27")
					compactText_by:SetText("by")

					compactTextAttack = CreateControl(compactText:GetName().."Attack", compactText, CT_LABEL)
					compactTextAttack:SetAnchor(TOPLEFT, compactText_by, TOPRIGHT, 8, 0)
					compactTextAttack:SetColor(197/255, 194/255, 158/255, 1)
					compactTextAttack:SetFont("ZoFontGamepad27")

					compactText_from = CreateControl(compactText:GetName().."From", compactText, CT_LABEL)
					compactText_from:SetAnchor(TOPLEFT, compactTextAttack, TOPRIGHT, 8, 0)
					compactText_from:SetFont("ZoFontGamepad27")
					compactText_from:SetText("from")

					compactTextAttacker = CreateControl(compactText:GetName().."Attacker", compactText, CT_LABEL)
					compactTextAttacker:SetAnchor(TOPLEFT, compactText_from, TOPRIGHT, 8, 0)
					compactTextAttacker:SetColor(197/255, 194/255, 158/255, 1)
					compactTextAttacker:SetFont("ZoFontGamepad27")

					compactTextHealth = CreateControl(compactText:GetName().."Health", compactText, CT_LABEL)
					compactTextHealth:SetAnchor(LEFT, compactTextAttacker, RIGHT, 8, 0)
					compactTextHealth:SetColor(1, 0.25, 0.25, 1)
					compactTextHealth:SetFont("ZoFontGamepad22")
				else
					compactTextTimer = GetControl(compactText:GetName().."Timer")
					compactTextNumber = GetControl(compactText:GetName().."Number")
					compactTextLabel = GetControl(compactText:GetName().."Label")
					compactText_by = GetControl(compactText:GetName().."By")
					compactTextAttack = GetControl(compactText:GetName().."Attack")
					compactText_from = GetControl(compactText:GetName().."From")
					compactTextAttacker = GetControl(compactText:GetName().."Attacker")
					compactTextHealth = GetControl(compactText:GetName().."Health")
				end
				compactText:SetHidden(false)

				compactTextTimer:SetText("-"..tostring(zo_roundToNearest(rowData.displayTimeMS/1000, .01)).."s: ")

				if rowData.resultType == ACTION_RESULT_HEAL or
					rowData.resultType == ACTION_RESULT_HOT_TICK or
					rowData.resultType == ACTION_RESULT_HOT then
						compactTextLabel:SetText("HEAL")
						compactTextNumber:SetText(ZO_CommaDelimitNumber(rowData.attackDamage))
						compactTextNumber:SetColor(0, 1, 0, 1)
				elseif rowData.resultType == ACTION_RESULT_CRITICAL_HEAL or 
						rowData.resultType == ACTION_RESULT_HOT_TICK_CRITICAL then
							compactTextLabel:SetText("HEAL")
							compactTextNumber:SetText(ZO_CommaDelimitNumber(rowData.attackDamage).."!")
							compactTextNumber:SetColor(0, 1, 0, 1)
				elseif rowData.resultType == ACTION_RESULT_ABSORBED then
					compactTextLabel:SetText("ABSORB")
					compactTextNumber:SetText(ZO_CommaDelimitNumber(rowData.attackDamage))
					compactTextNumber:SetColor(0, 0, 1, 1)
				elseif rowData.resultType == ACTION_RESULT_HEAL_ABSORBED then
					compactTextLabel:SetText("HEAL ABSORB")
					compactTextNumber:SetText(ZO_CommaDelimitNumber(rowData.attackDamage)) 
					compactTextNumber:SetColor(0, 1, 1, 1)
				elseif rowData.resultType == ACTION_RESULT_DODGED or rowData.attackName == "Roll Dodge" then
					compactTextLabel:SetText("DODGE")
					compactTextNumber:SetText("")
				elseif rowData.resultType == ACTION_RESULT_ROOTED then
					compactTextLabel:SetText("ROOT")
					compactTextNumber:SetText("")
				elseif rowData.resultType == ACTION_RESULT_FEARED then
					compactTextLabel:SetText("FEARED")
					compactTextNumber:SetText("")
				elseif rowData.resultType == ACTION_RESULT_REFLECTED then
					compactTextLabel:SetText("REFLECT")
					compactTextNumber:SetText("")
				elseif rowData.resultType == ACTION_RESULT_INTERRUPT then
					compactTextLabel:SetText("INTERRUPT")
					compactTextNumber:SetText("")
				elseif rowData.resultType == ACTION_RESULT_SILENCED then
					compactTextLabel:SetText("SILENCED")
					compactTextNumber:SetText("")
				elseif rowData.resultType == ACTION_RESULT_SNARED then
					compactTextLabel:SetText("SNARED")
					compactTextNumber:SetText("")
				elseif rowData.resultType == ACTION_RESULT_STUNNED then
					compactTextLabel:SetText("STUNNED")
					compactTextNumber:SetText("")
				elseif rowData.attackName == "Break Free" then
					compactTextLabel:SetText("BREAK FREE")
					compactTextNumber:SetText("")
				elseif rowData.resultType == ACTION_RESULT_DAMAGE_SHIELDED then
					compactTextLabel:SetText("DMG")
					compactTextNumber:SetText("("..ZO_CommaDelimitNumber((rowData.attackDamage + rowData.attackOverflow))..")" )
					compactTextNumber:SetColor(1, 0, 0, 1)
				elseif rowData.resultType == ACTION_RESULT_BLOCKED_DAMAGE then
					compactTextLabel:SetText("DMG")
					compactTextNumber:SetText(ZO_CommaDelimitNumber(rowData.attackDamage + rowData.attackOverflow).."*" )
					compactTextNumber:SetColor(1, 0, 0, 1)
				elseif rowData.resultType == ACTION_RESULT_DOT_TICK_CRITICAL or
						rowData.resultType == ACTION_RESULT_CRITICAL_DAMAGE then
							compactTextLabel:SetText("DMG")
							compactTextNumber:SetText((rowData.attackDamage + rowData.attackOverflow).."!")
							compactTextNumber:SetColor(1, 0, 0, 1)
				else --regular damage.
					compactTextLabel:SetText(" DMG ")
					compactTextNumber:SetText(ZO_CommaDelimitNumber(rowData.attackDamage + rowData.attackOverflow))
					compactTextNumber:SetColor(1, 0, 0, 1)
				end

				compactTextAttack:SetText(rowData.attackName)
				compactTextAttacker:SetText(rowData.attackerName)
				compactTextHealth:SetText("(HP: "..ZO_CommaDelimitDecimalNumber(rowData.currentHealth)..")")
			end
		end
		
		
		--Force the animation to start playing to avoid some weird, inconsistent visual bugs.
		DEATH:ToggleDeathRecap()
		DEATH:ToggleDeathRecap()
		
	end, 2500)
end
--]]





local ICON_ANIMATION_START_INDEX = 1
local ICON_ANIMATION_END_INDEX = 3
local STYLE_ANIMATION_START_INDEX = 4
local STYLE_ANIMATION_END_INDEX = 6
local TEXT_ANIMATION_INDEX = 7
local COUNT_ANIMATION_START_INDEX = 8
local COUNT_ANIMATION_END_INDEX = 10
local HEALTH_ANIMATION_START_INDEX = 11
local HEALTH_ANIMATION_END_INDEX = 13

-- Instead of SetCustomFactoryBehavior, override the main factory
local originalFactory = DEATH_RECAP.attackPool.m_Factory

DEATH_RECAP.attackPool:SetFactory(function(objectKey)
    -- Create the control using original factory - PASS THE POOL!
    local control = originalFactory(DEATH_RECAP.attackPool, objectKey)
    
    -- Only create timeline if control was created successfully
    if control then
        -- Create timeline ONLY for new objects
        control.timeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("AlternativeDeathRecapAttackAnimation")
        if control.timeline then
            local nestedTimeline = control.timeline:GetAnimationTimeline(1)
            if nestedTimeline then
                local iconTexture = control:GetNamedChild("Icon")
                local styleContainer = control:GetNamedChild("SkillStyle")
                local textContainer = control:GetNamedChild("Text")

                for i = ICON_ANIMATION_START_INDEX, ICON_ANIMATION_END_INDEX do
                    local animation = nestedTimeline:GetAnimation(i)
                    if animation then
                        animation:SetAnimatedControl(iconTexture)
                    end
                end
                for i = STYLE_ANIMATION_START_INDEX, STYLE_ANIMATION_END_INDEX do
                    local animation = nestedTimeline:GetAnimation(i)
                    if animation then
                        animation:SetAnimatedControl(styleContainer)
                    end
                end
                local textAnimation = nestedTimeline:GetAnimation(TEXT_ANIMATION_INDEX)
                if textAnimation then
                    textAnimation:SetAnimatedControl(textContainer)
                end
                if not nestedTimeline.isKillingBlow then
                    local numAttackHitsContainer = control:GetNamedChild("NumAttackHits")
                    for i = COUNT_ANIMATION_START_INDEX, COUNT_ANIMATION_END_INDEX do
                        local animation = nestedTimeline:GetAnimation(i)
                        if animation then
                            animation:SetAnimatedControl(numAttackHitsContainer)
                        end
                    end
                end
            end
        end
    end
    
    return control
end)

DEATH_RECAP.attackPool:SetCustomFactoryBehavior(function() end)







--[[
	
	
	____________    ____      ____            ____      ____    ________   __________
	MMMMMMMMMMMP   6MMMMb    6MMMMb\         6MMMMb/   6MMMMb   `MMMMMMMb. `MMMMMMMMM
	/       dMP   8P    Y8  6M'    `        8P    YM  8P    Y8   MM    `Mb  MM      \
	       dMP   6M      Mb MM             6M      Y 6M      Mb  MM     MM  MM
	      dMP    MM      MM YM.            MM        MM      MM  MM     MM  MM    ,
	     dMP     MM      MM  YMMMMb        MM        MM      MM  MM     MM  MMMMMMM
	    dMP      MM      MM      `Mb       MM        MM      MM  MM     MM  MM    `
	   dMP       MM      MM       MM       MM        MM      MM  MM     MM  MM
	  dMP        YM      M9       MM       YM      6 YM      M9  MM     MM  MM
	 dMP       /  8b    d8  L    ,M9        8b    d9  8b    d8   MM    .M9  MM      /
	dMMMMMMMMMMM   YMMMM9   MYMMMM9          YMMMM9    YMMMM9   _MMMMMMM9' _MMMMMMMMM
	
	
	
]]

-- DeathRecap:SetupAttacks
local function SetupAttacks(self) -- https://github.com/esoui/esoui/blob/1453053596e7f731ef854638c9975a4f474eba53/esoui/ingame/deathrecap/deathrecap.lua#L212
    local startAlpha = self:GetStartAlpha()
    self.attackPool:ReleaseAllObjects()
    self.killingBlowIcon:SetAlpha(startAlpha)


    ADR.lastCastTimes = {}
    local attacks = ADR.GetOrderedList()

    -- TODO: REMOVE THIS
    --[[
    for i,v in ipairs(attacks) do
    	attacks[i+#attacks] = v
    end
    --]]
    

    for k, v in ipairs(attacks) do
		v.displayTimeMS = attacks[#attacks].lastUpdateAgoMS - v.lastUpdateAgoMS
	end

    local prevAttackControl
    for i, rowData in ipairs(attacks) do
        local currentRow = self.attackPool:AcquireObject(i)
        local attackControl = currentRow
        local iconControl = attackControl:GetNamedChild("Icon")
        local attackTextControl = attackControl:GetNamedChild("AttackText")
        local attackNameControl = attackTextControl:GetNamedChild("AttackName")
        local damageControl = attackControl:GetNamedChild("Damage")
        local skillStyleControl = attackControl:GetNamedChild("SkillStyle")
        local skillStyleIconControl = skillStyleControl:GetNamedChild("Icon")
        local numAttackHitsContainer = attackControl:GetNamedChild("NumAttackHits")



        if ADR.savedVariables.isCompact == false then
			--Default mode.
			currentRow:SetDimensionConstraints(nil, 64, nil, nil)

			--Change icon texture
			local attack_icon = currentRow:GetNamedChild("Icon")
			attack_icon:SetTexture(rowData.attackIcon)
			
			--Display timeline using these controls.
			local numAttackHits = currentRow:GetNamedChild("NumAttackHits")
			local attackCount = numAttackHits:GetNamedChild("Count")

			numAttackHits:SetHidden(false)
			if rowData.displayTimeMS ~= nil then 
				attackCount:SetHidden(false)
				attackCount:SetText("-"..tostring(zo_roundToNearest(rowData.displayTimeMS/1000, .01)).."s")
			else
				attackCount:SetHidden(true)
			end
			numAttackHits:GetNamedChild("HitIcon"):SetHidden(true)
			numAttackHits:GetNamedChild("KillIcon"):SetHidden(true)
			
			numAttackHits:ClearAnchors()
			numAttackHits:SetAnchor(RIGHT, attack_icon, LEFT, -15, -10)
			
			--HP display using new control.
			local health_display = GetControl(currentRow:GetName().."Health")
			if health_display == nil then
				health_display = CreateControl(currentRow:GetName().."Health", currentRow, CT_LABEL)
				health_display:SetHidden(false)
				health_display:SetFont("ZoFontGamepad22")
				health_display:SetColor(1, 0.25, 0.25, 1)
				health_display:SetAnchor(TOPRIGHT, attackCount, BOTTOMRIGHT, 0, -2)
			end
			health_display:SetHidden(false)
			health_display:SetText("HP: "..ZO_CommaDelimitDecimalNumber(rowData.currentHealth).."/"..ZO_CommaDelimitDecimalNumber(rowData.currentMaxHealth))
			health_display:SetAlpha(startAlpha)
			if currentRow.timeline then
				local nestedTimeline = currentRow.timeline:GetAnimationTimeline(1)
				if nestedTimeline then
					for i = HEALTH_ANIMATION_START_INDEX, HEALTH_ANIMATION_END_INDEX do
				        local animation = nestedTimeline:GetAnimation(i)
				        if animation then
				        	animation:SetAnimatedControl(health_display)
				        end
				    end
				end
			end


			
			--Set damage and label
			local damageLabel = currentRow:GetNamedChild("DamageLabel")
			local damageText = currentRow:GetNamedChild("Damage")
			if rowData.resultType == ACTION_RESULT_HEAL or
				rowData.resultType == ACTION_RESULT_HOT_TICK or
				rowData.resultType == ACTION_RESULT_HOT then
					damageLabel:SetText("HEAL")
					damageText:SetText(ZO_CommaDelimitNumber(rowData.attackDamage))
					damageText:SetColor(0, 1, 0, 1)
			elseif rowData.resultType == ACTION_RESULT_CRITICAL_HEAL or 
					rowData.resultType == ACTION_RESULT_HOT_TICK_CRITICAL then
						damageLabel:SetText("HEAL")
						damageText:SetText(ZO_CommaDelimitNumber(rowData.attackDamage).."!")
						damageText:SetColor(0, 1, 0, 1)
			elseif rowData.resultType == ACTION_RESULT_ABSORBED then
				damageLabel:SetText("ABSORB")
				damageText:SetText(ZO_CommaDelimitNumber(rowData.attackDamage))
				damageText:SetColor(0, 0, 1, 1)
			elseif rowData.resultType == ACTION_RESULT_HEAL_ABSORBED then
				damageLabel:SetText("HEAL ABSORB")
				damageText:SetText(ZO_CommaDelimitNumber(rowData.attackDamage)) 
				damageText:SetColor(0, 1, 1, 1)
			elseif rowData.resultType == ACTION_RESULT_DODGED or rowData.attackName == "Roll Dodge" then
				damageLabel:SetText("DODGE")
				damageText:SetText("")
			elseif rowData.resultType == ACTION_RESULT_ROOTED then
				damageLabel:SetText("ROOT")
				damageText:SetText("")
			elseif rowData.resultType == ACTION_RESULT_FEARED then
				damageLabel:SetText("FEARED")
				damageText:SetText("")
			elseif rowData.resultType == ACTION_RESULT_REFLECTED then
				damageLabel:SetText("REFLECT")
				damageText:SetText("")
			elseif rowData.resultType == ACTION_RESULT_INTERRUPT then
				damageLabel:SetText("INTERRUPT")
				damageText:SetText("")
			elseif rowData.resultType == ACTION_RESULT_SILENCED then
				damageLabel:SetText("SILENCED")
				damageText:SetText("")
			elseif rowData.resultType == ACTION_RESULT_SNARED then
				damageLabel:SetText("SNARED")
				damageText:SetText("")
			elseif rowData.resultType == ACTION_RESULT_STUNNED then
				damageLabel:SetText("STUNNED")
				damageText:SetText("")
			elseif rowData.attackName == "Break Free" then
				damageLabel:SetText("BREAK FREE")
				damageText:SetText("")
			elseif rowData.resultType == ACTION_RESULT_DAMAGE_SHIELDED then
				damageLabel:SetText("SHIELDED")
				damageText:SetText("("..ZO_CommaDelimitNumber((rowData.attackDamage + rowData.attackOverflow))..")" )
				damageText:SetColor(1, 0, 0, 1)
			elseif rowData.resultType == ACTION_RESULT_BLOCKED_DAMAGE then
				damageLabel:SetText("BLOCKED")
				damageText:SetText(ZO_CommaDelimitNumber(rowData.attackDamage + rowData.attackOverflow).."*" )
				damageText:SetColor(1, 0, 0, 1)
			elseif rowData.resultType == ACTION_RESULT_DOT_TICK_CRITICAL or
					rowData.resultType == ACTION_RESULT_CRITICAL_DAMAGE then
						damageLabel:SetText("DOT")
						damageText:SetText((rowData.attackDamage + rowData.attackOverflow).."!")
						damageText:SetColor(1, 0, 0, 1)
			elseif rowData.resultType == ACTION_RESULT_DOT_TICK then -- dot
				damageLabel:SetText("DOT")
				damageText:SetText(ZO_CommaDelimitNumber(rowData.attackDamage + rowData.attackOverflow))
				damageText:SetColor(1, 0, 0, 1)
			else --regular damage.
				damageLabel:SetText("DMG")
				damageText:SetText(ZO_CommaDelimitNumber(rowData.attackDamage + rowData.attackOverflow))
				damageText:SetColor(1, 0, 0, 1)
			end
			
			local attackerName = currentRow:GetNamedChild("AttackText"):GetNamedChild("AttackerName")
			local attackName = currentRow:GetNamedChild("AttackText"):GetNamedChild("AttackName")
			
			attackName:ClearAnchors()
			attackName:SetAnchor(TOPLEFT, attackerName, BOTTOMLEFT, 0, 2)
			attackName:SetAnchor(TOPRIGHT, attackerName, BOTTOMRIGHT, 0, 2)
			attackName:SetText(rowData.attackName)
			attackerName:SetHidden(false)
			attackerName:SetText(rowData.attackerName)
				
			--avoid the need to wait for animations.
			--[[
			attack_icon:SetAlpha(1)
			attack_icon:SetScale(1)
			attack_icon:SetHidden(false)
			currentRow:GetNamedChild("Text"):SetAlpha(1)
			currentRow:GetNamedChild("Text"):SetHidden(false)
			currentRow:GetNamedChild("Icon"):SetHidden(false)
			currentRow:GetNamedChild("NumAttackHits"):SetHidden(false)
			--]]
		end

		skillStyleControl:SetAlpha(startAlpha)
        --skillStyleControl:SetHidden(false)

        iconControl:SetAlpha(startAlpha)
        attackControl:GetNamedChild("Text"):SetAlpha(startAlpha)
        numAttackHitsContainer:SetAlpha(startAlpha)
        --numAttackHits:SetHidden(false)





		--[[
        iconControl:SetTexture(attackInfo.attackIcon)
        attackNameControl:SetText(zo_strformat(SI_DEATH_RECAP_ATTACK_NAME, attackInfo.attackName))
        damageControl:SetText(zo_strformat(SI_NUMBER_FORMAT, attackInfo.attackDamage))

        local killingBlowOffsetX = 72
        if attackInfo.abilityFxIcon then
            skillStyleIconControl:SetTexture(attackInfo.abilityFxIcon)
            skillStyleControl:SetAlpha(startAlpha)
            skillStyleControl:SetHidden(false)
            killingBlowOffsetX = 32
        else
            skillStyleControl:SetHidden(true)
        end

        iconControl:SetAlpha(startAlpha)
        attackControl:GetNamedChild("Text"):SetAlpha(startAlpha)

        if attackInfo.numAttackHits > 1 then
            local numAttackHitsCountLabel = numAttackHitsContainer:GetNamedChild("Count")
            local numAttackHitsHitIcon = numAttackHitsContainer:GetNamedChild("HitIcon")
            local numAttackHitsKillIcon = numAttackHitsContainer:GetNamedChild("KillIcon")
            numAttackHitsContainer:SetAlpha(startAlpha)
            numAttackHitsContainer:SetHidden(false)
            numAttackHitsCountLabel:SetText(attackInfo.numAttackHits)
            if attackInfo.wasKillingBlow then
                numAttackHitsHitIcon:SetHidden(true)
                numAttackHitsKillIcon:SetHidden(false)
                self.killingBlowIcon:SetHidden(true)
            else
                numAttackHitsHitIcon:SetHidden(false)
                numAttackHitsKillIcon:SetHidden(true)
            end

            local anchorControl = iconControl
            if attackInfo.abilityFxIcon then
                anchorControl = skillStyleControl
            end
            numAttackHitsContainer:ClearAnchors()
            numAttackHitsContainer:SetAnchor(RIGHT, anchorControl, LEFT, -15)
        else
            numAttackHitsContainer:SetHidden(true)
            if attackInfo.wasKillingBlow then
                self.killingBlowIcon:SetHidden(false)
                self.killingBlowIcon:SetAnchor(CENTER, attackControl, TOPLEFT, killingBlowOffsetX, 32)
            end
        end

        local attackerNameControl = attackTextControl:GetNamedChild("AttackerName")
        local frameControl
        if DoesKillingAttackHaveAttacker(attackInfo.index) then
            local attackerRawName, attackerChampionPoints, attackerLevel, attackerAvARank, isPlayer, isBoss, alliance, minionName, attackerDisplayName = GetKillingAttackerInfo(attackInfo.index)
            local battlegroundTeam = GetKillingAttackerBattlegroundTeam(attackInfo.index)

            local attackerNameLine
            if isPlayer then
                local nameToShow
                if showBothPlayerNames then
                    nameToShow = ZO_GetPrimaryPlayerNameWithSecondary(attackerDisplayName, attackerRawName)
                else
                    nameToShow = ZO_GetPrimaryPlayerName(attackerDisplayName, attackerRawName)
                end

                if battlegroundTeam == BATTLEGROUND_TEAM_INVALID then
                    local coloredRankIconMarkup = ZO_GetColoredAvARankIconMarkup(attackerAvARank, alliance, 32)
                    if minionName == "" then
                        attackerNameLine = zo_strformat(SI_DEATH_RECAP_RANK_ATTACKER_NAME, coloredRankIconMarkup, attackerAvARank, nameToShow)
                    else
                        attackerNameLine = zo_strformat(SI_DEATH_RECAP_RANK_ATTACKER_NAME_MINION, coloredRankIconMarkup, attackerAvARank, nameToShow, minionName)
                    end
                else
                    local battlegroundTeamIconMarkup = ZO_GetBattlegroundIconMarkup(battlegroundTeam, 32)
                    if minionName == "" then
                        attackerNameLine = zo_strformat(SI_DEATH_RECAP_BATTLEGROUND_ALLIANCE_ATTACKER_NAME, battlegroundTeamIconMarkup, nameToShow)
                    else
                        attackerNameLine = zo_strformat(SI_DEATH_RECAP_BATTLEGROUND_ALLIANCE_ATTACKER_NAME_MINION, battlegroundTeamIconMarkup, nameToShow, minionName)
                    end
                end
            else
                if minionName == "" then
                    attackerNameLine = zo_strformat(SI_DEATH_RECAP_ATTACKER_NAME, attackerRawName)
                else
                    attackerNameLine = zo_strformat(SI_DEATH_RECAP_ATTACKER_NAME_MINION, attackerRawName, minionName)
                end
            end

            attackerNameControl:SetText(attackerNameLine)
            attackerNameControl:SetHidden(false)

            attackNameControl:ClearAnchors()
            attackNameControl:SetAnchor(TOPLEFT, attackerNameControl, BOTTOMLEFT, 0, 2)
            attackNameControl:SetAnchor(TOPRIGHT, attackerNameControl, BOTTOMRIGHT, 0, 2)

            frameControl = isBoss and iconControl:GetNamedChild("BossBorder") or iconControl:GetNamedChild("Border")
            frameControl:SetHidden(false)
        else
            attackerNameControl:SetHidden(true)

            attackNameControl:ClearAnchors()
            attackNameControl:SetAnchor(TOPLEFT)
            attackNameControl:SetAnchor(TOPRIGHT)
            
            frameControl = iconControl:GetNamedChild("Border")
            frameControl:SetHidden(false)
        end
        --]]

        if prevAttackControl then
            attackControl:SetAnchor(TOPLEFT, prevAttackControl, BOTTOMLEFT, 0, 10)
        else
            attackControl:SetAnchor(TOPLEFT, nil, TOPLEFT, 0, 0)
        end

        prevAttackControl = attackControl
    end

    --ZO_ScrollAnimation_MoveWindow(DEATH_RECAP.scrollContainer, 1000000)
    return true
end
























local ATTACK_ROW_ANIMATION_OVERLAP_PERCENT = 0.5
local HINT_ANIMATION_DELAY_MS = 300

local function instantAnimate(self)
    local delay = 0
    local lastRowDuration
    for attackRowIndex, attackControl in ipairs(self.attackPool:GetActiveObjects()) do
        local timeline = attackControl.timeline
        local isLastRow = (attackRowIndex == #self.attackPool:GetActiveObjects())
        local nestedTimeline = timeline:GetAnimationTimeline(1)
        local duration = nestedTimeline:GetDuration()
        timeline:SetAnimationTimelineOffset(nestedTimeline, delay)
        nestedTimeline.isKillingBlow = isLastRow
        timeline:PlayInstantlyToEnd()
        delay = delay + duration * ATTACK_ROW_ANIMATION_OVERLAP_PERCENT



        local skillStyleControl = attackControl:GetNamedChild("SkillStyle")
        local numAttackHitsContainer = attackControl:GetNamedChild("NumAttackHits")
        local health_display = GetControl(attackControl:GetName().."Health")

        attackControl:GetNamedChild("Icon"):SetAlpha(1)
        skillStyleControl:SetAlpha(1)
        attackControl:GetNamedChild("Text"):SetAlpha(1)
        numAttackHitsContainer:SetAlpha(1)
		health_display:SetAlpha(1)


        if isLastRow then
            lastRowDuration = duration
        end
    end

    local nestedKBTimeline = self.killingBlowTimeline:GetAnimationTimeline(1)
    self.killingBlowTimeline:SetAnimationTimelineOffset(nestedKBTimeline, zo_max(0, delay - lastRowDuration))
    self.killingBlowTimeline:PlayInstantlyToEnd()

    if GetNumTelvarStonesLost() > 0 then
        local nestedTelvarLossTimeline = self.telvarLossTimeline:GetAnimationTimeline(1)
        self.telvarLossTimeline:SetAnimationTimelineOffset(nestedTelvarLossTimeline, delay)
        self.telvarLossTimeline:PlayInstantlyToEnd()
    end
    
    local nestedTimeline = self.hintTimeline:GetAnimationTimeline(1)
    self.hintTimeline:SetAnimationTimelineOffset(nestedTimeline, delay + HINT_ANIMATION_DELAY_MS)
    self.hintTimeline:PlayInstantlyToEnd()
end



ZO_PreHook(DEATH_RECAP, "SetupAttacks", SetupAttacks)


local currentlyAnimating = false


local function animate(self) -- scroll the window to the bottom
	local delay = 0
	local extraDelay = 0
	local heightLeft = DEATH_RECAP.scrollContainer.scroll:GetHeight()

	for attackRowIndex, attackControl in ipairs(self.attackPool:GetActiveObjects()) do
		local timeline = attackControl.timeline
        local nestedTimeline = timeline:GetAnimationTimeline(1)
        local duration = nestedTimeline:GetDuration()
        delay = delay + duration * ATTACK_ROW_ANIMATION_OVERLAP_PERCENT
        if heightLeft > 0 then
        	heightLeft = heightLeft - attackControl:GetHeight()
        	extraDelay = extraDelay + duration * ATTACK_ROW_ANIMATION_OVERLAP_PERCENT
        end
        
	end
	--d("Time of "..delay)
	ADR.animation:SetDuration(delay + HINT_ANIMATION_DELAY_MS )

    ADR.timeline:SetAnimationOffset(ADR.animation, extraDelay/2)


	ADR.timeline:Stop()
	self.scrollContainer.animationStart = 0 --DEATH_RECAP.scrollContainer.scrollValue
	self.scrollContainer.animationTarget = 100
	ADR.timeline:PlayFromStart()
	self.scrollContainer.scrollValue = 100

	currentlyAnimating = true
	zo_callLater(function() currentlyAnimating = false end, delay + HINT_ANIMATION_DELAY_MS)
end

SecurePostHook(DEATH_RECAP, "Animate", animate)












local function scrollToEnd(self)
	--d(currentlyAnimating)
	if currentlyAnimating == false then -- idk, prob a better way to do this
		ZO_ScrollAnimation_MoveWindow(DEATH_RECAP.scrollContainer, 100)
	end
end

--SecurePostHook(DEATH_RECAP, "OnEffectivelyShown", scrollToEnd)

SecurePostHook(DEATH_RECAP, "RefreshVisibility", scrollToEnd)






function ADR.Initialize()

	ADR.defaults = {
		maxAttacks = 25,
		timeLength = 10,
		scrollSensitivityBoost = 0,
		isCompact = false,
		trackHealAbsorb = true,
		trackDodged = true,
		trackInterrupted = true,
		trackRooted = true,
		trackSilenced = true,
		trackSnared = true,
		trackStunned = true,
		trackFeared = true,
	}
	ADR.savedVariables = ZO_SavedVars:NewAccountWide("ADRSavedVariables", 1, nil, ADR.defaults, GetWorldName())

	--SETTINGS:


	-- TODO: Replace with LAM2 for PC
	if IsConsoleUI() then
		local settings = LibHarvensAddonSettings:AddAddon("Alternate Death Recap")

		local generalSection = {type = LibHarvensAddonSettings.ST_SECTION,label = "General",}
		local filterSection = {type = LibHarvensAddonSettings.ST_SECTION,label = "Filters",}

		local toggleCompact = {
	        type = LibHarvensAddonSettings.ST_CHECKBOX, --setting type
	        label = "Compact Mode", 
	        tooltip = "Replaces the default death recap format with a more compact version.",
	        default = ADR.defaults.isCompact,
	        setFunction = function(state) 
	            ADR.savedVariables.isCompact = state
	        end,
	        getFunction = function() 
	            return ADR.savedVariables.isCompact
	        end,
	        disable = function() return false end,
	    }

		local setMaxAttacks = {
	        type = LibHarvensAddonSettings.ST_SLIDER,
	        label = "Max Attacks",
	        tooltip = "Set the limit on how many attacks this addon will keep track of.",
	        setFunction = function(value)
				ADR.savedVariables.maxAttacks = value
				
				while ADR.attackList.size > ADR.savedVariables.maxAttacks do
					ADR.DequeueAttack()
				end
			end,
	        getFunction = function()
	            return ADR.savedVariables.maxAttacks
	        end,
	        default = 25,
	        min = 1,
	        max = 50,
	        step = 1,
	        unit = "", --optional unit
	        format = "%d", --value format
	        disable = function() return false end,
	    }

		local setMaxTime = {
	        type = LibHarvensAddonSettings.ST_SLIDER,
	        label = "Max Time",
	        tooltip = "The addon will only display attacks that occurred within the last X seconds.",
	        setFunction = function(value)
				ADR.savedVariables.timeLength = value
			end,
	        getFunction = function()
	            return ADR.savedVariables.timeLength
	        end,
	        default = 10,
	        min = 1,
	        max = 60,
	        step = 1,
	        unit = " sec", --optional unit
	        format = "%d", --value format
	        disable = function() return false end,
	    }

		local setSensitivity = {
	        type = LibHarvensAddonSettings.ST_SLIDER,
	        label = "Scroll Boost",
	        tooltip = "Increases the death recap's scrolling speed by X%.",
	        setFunction = function(value)
				ADR.savedVariables.scrollSensitivityBoost = value
			end,
	        getFunction = function()
	            return ADR.savedVariables.scrollSensitivityBoost
	        end,
	        default = 0,
	        min = 0,
	        max = 1000,
	        step = 10,
	        unit = "%", --optional unit
	        format = "%d", --value format
	        disable = function() return false end,
	    }

		local trackHealAbsorb = {
	        type = LibHarvensAddonSettings.ST_CHECKBOX, --setting type
	        label = "Heal Absorb", 
	        tooltip = "Only show this event in recap when this option is set to ON.",
	        default = ADR.defaults.trackHealAbsorb,
	        setFunction = function(state) 
	            ADR.savedVariables.trackHealAbsorb = state
	        end,
	        getFunction = function() 
	            return ADR.savedVariables.trackHealAbsorb
	        end,
	        disable = function() return false end,
	    }

		local trackDodged = {
	        type = LibHarvensAddonSettings.ST_CHECKBOX, --setting type
	        label = "Dodge", 
	        tooltip = "Only show this event in recap when this option is set to ON.",
	        default = ADR.defaults.trackDodged,
	        setFunction = function(state) 
	            ADR.savedVariables.trackDodged = state
	        end,
	        getFunction = function() 
	            return ADR.savedVariables.trackDodged
	        end,
	        disable = function() return false end,
	    }

		local trackInterrupted = {
	        type = LibHarvensAddonSettings.ST_CHECKBOX, --setting type
	        label = "Interrupted", 
	        tooltip = "Only show this event in recap when this option is set to ON.",
	        default = ADR.defaults.trackInterrupted,
	        setFunction = function(state) 
	            ADR.savedVariables.trackInterrupted = state
	        end,
	        getFunction = function() 
	            return ADR.savedVariables.trackInterrupted
	        end,
	        disable = function() return false end,
	    }

		local trackRooted = {
	        type = LibHarvensAddonSettings.ST_CHECKBOX, --setting type
	        label = "Rooted", 
	        tooltip = "Only show this event in recap when this option is set to ON.",
	        default = ADR.defaults.trackRooted,
	        setFunction = function(state) 
	            ADR.savedVariables.trackRooted = state
	        end,
	        getFunction = function() 
	            return ADR.savedVariables.trackRooted
	        end,
	        disable = function() return false end,
	    }

		local trackSnared = {
	        type = LibHarvensAddonSettings.ST_CHECKBOX, --setting type
	        label = "Snared", 
	        tooltip = "Only show this event in recap when this option is set to ON.",
	        default = ADR.defaults.trackSnared,
	        setFunction = function(state) 
	            ADR.savedVariables.trackSnared = state
	        end,
	        getFunction = function() 
	            return ADR.savedVariables.trackSnared
	        end,
	        disable = function() return false end,
	    }

		local trackSilenced = {
	        type = LibHarvensAddonSettings.ST_CHECKBOX, --setting type
	        label = "Silenced", 
	        tooltip = "Only show this event in recap when this option is set to ON.",
	        default = ADR.defaults.trackSilenced,
	        setFunction = function(state) 
	            ADR.savedVariables.trackSilenced = state
	        end,
	        getFunction = function() 
	            return ADR.savedVariables.trackSilenced
	        end,
	        disable = function() return false end,
	    }

		local trackStunned = {
	        type = LibHarvensAddonSettings.ST_CHECKBOX, --setting type
	        label = "Stunned", 
	        tooltip = "Only show this event in recap when this option is set to ON.",
	        default = ADR.defaults.trackStunned,
	        setFunction = function(state) 
	            ADR.savedVariables.trackStunned = state
	        end,
	        getFunction = function() 
	            return ADR.savedVariables.trackStunned
	        end,
	        disable = function() return false end,
	    }

		local trackFeared = {
	        type = LibHarvensAddonSettings.ST_CHECKBOX, --setting type
	        label = "Feared", 
	        tooltip = "Only show this event in recap when this option is set to ON.",
	        default = ADR.defaults.trackFeared,
	        setFunction = function(state) 
	            ADR.savedVariables.trackFeared = state
	        end,
	        getFunction = function() 
	            return ADR.savedVariables.trackFeared
	        end,
	        disable = function() return false end,
	    }

		settings:AddSettings({generalSection, toggleCompact, setMaxAttacks, setMaxTime, setSensitivity, filterSection, trackHealAbsorb, trackDodged, trackInterrupted, trackRooted, trackSnared, trackSilenced, trackStunned, trackFeared })
	else
		
	end

	ADR.lastCastTimes = {}
	GetNumKillingAttacks = function() 
		return ADR.attackList.size
	end
	
	ADR.healthCostSkills = {
		["Equilibrium"] = true,
		["Balance"] = true,
		["Spell Symmetry"] = true,
		["Blood Altar"] = true,
		["Sanguine Altar"] = true,
		["Overflowing Altar"] = true,
		["Eviscerate"] = true,
		["Blood for Blood"] = true,
		["Arterial Burst"] = true,
		["Expunge"] = true,
		["Hexproof"] = true,
		["Siphoning Strikes"] = true,
		["Siphoning Attacks"] = true,
		["Leeching Strikes"] = true,
	}
	
	SLASH_COMMANDS["/togglerecap"] = function()
		if DEATH_RECAP.animateOnShow == true then
			DEATH_RECAP.animateOnShow = nil
			instantAnimate(DEATH_RECAP)
		end
		DEATH:ToggleDeathRecap()
		ZO_ScrollAnimation_MoveWindow(DEATH_RECAP.scrollContainer, 100)
		--ZO_DeathRecap:SetHidden(not ZO_DeathRecap:IsHidden())
	end

	--EVENT_MANAGER:RegisterForEvent(ADR.name, EVENT_PLAYER_DEAD, ADR.setupRecap)
	
	--reset attack list on respawn.
	EVENT_MANAGER:RegisterForEvent(ADR.name, EVENT_PLAYER_ALIVE, function() 
		ADR.lastCastTimes = {}
		ADR.Reset()
	end)
	
	EVENT_MANAGER:RegisterForEvent(ADR.name, EVENT_COMBAT_EVENT, ADR.OnCombatEvent)
	EVENT_MANAGER:AddFilterForEvent(ADR.name, EVENT_COMBAT_EVENT, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

	if IsConsoleUI() then
		ZO_PreHook("ZO_ScrollRelative", function(target, verticalDelta, secondCall)
			--This is additional verticalDelta
			if ADR.savedVariables.scrollSensitivityBoost ~= 0 and secondCall == nil and target:GetName() == "ZO_DeathRecapScrollContainer" then
				ZO_ScrollRelative(target, (ADR.savedVariables.scrollSensitivityBoost*verticalDelta/100), true)
			end
		end)
	else
		DEATH_RECAP.scrollContainer:SetMouseEnabled(true)
		DEATH_RECAP.scrollContainer:SetHandler("OnMouseWheel", function(self, delta) ZO_ScrollRelative(DEATH_RECAP.scrollContainer, -delta*40) end)
	end

	local animation, timeline = ZO_CreateScrollAnimation(DEATH_RECAP.scrollContainer)
	ADR.animation = animation
	ADR.timeline = timeline
end
	
function ADR.OnAddOnLoaded(event, addonName)
	if addonName == ADR.name then
		ADR.Initialize()
		EVENT_MANAGER:UnregisterForEvent(ADR.name, EVENT_ADD_ON_LOADED)
	end
end

EVENT_MANAGER:RegisterForEvent(ADR.name, EVENT_ADD_ON_LOADED, ADR.OnAddOnLoaded)