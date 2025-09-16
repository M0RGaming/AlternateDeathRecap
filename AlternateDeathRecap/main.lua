ADR = ADR or {}
ADR.name = "AlternateDeathRecap" 

function ADR.OnCombatEvent(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, _log, sourceUnitID, targetUnitID, abilityID, overflow)
	
	--Fix ^M or ^Mx or similar unwanted characters on the sourceName.
	if string.find(sourceName, "^", 1, true) ~= nil then sourceName = string.sub(sourceName, 1, (string.find(sourceName, "^", 1, true) - 1)) end
	--We don't want revive snare/stun events to be tracked.
	if string.find(string.lower(abilityName), "revive") ~= nil then return end
	--We only want to display this once, so only one type is being tracked with all other types returning here.
	if string.find(string.lower(abilityName), "break free") ~= nil and sourceType ~= COMBAT_UNIT_TYPE_PLAYER then return end
	
	local attack_icon = GetAbilityIcon(abilityID)
	
	local health, maxHealth = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_HEALTH)
	
	--track skills that cost health.
	--Doesn't track health-over-time skills.
	if sourceType == COMBAT_UNIT_TYPE_PLAYER then 
		if ADR.healthCostSkills[abilityName] == true then
			result = ACTION_RESULT_DAMAGE
			hitValue = GetAbilityCost(abilityID, COMBAT_MECHANIC_FLAGS_HEALTH, nil, "player")
		end
		
		--Only track one cast per skill.
		if ADR.lastCastTimes[abilityName] == nil or (GetGameTimeMilliseconds() - ADR.lastCastTimes[abilityName]) > 500 then
			ADR.lastCastTimes[abilityName] = GetGameTimeMilliseconds()
		else
			return
		end
	end
	
	--Don't track events with empty info.
	if sourceName == "" or
		abilityName == "" or
		attack_icon == "/esoui/art/icons/icon_missing.dds" then
			return
	end
		
	
	if result == ACTION_RESULT_DOT_TICK or
		result == ACTION_RESULT_DOT_TICK_CRITICAL  or
		result == ACTION_RESULT_CRITICAL_DAMAGE or
		result == ACTION_RESULT_DAMAGE or
		result == ACTION_RESULT_BLOCKED_DAMAGE or
		result == ACTION_RESULT_DAMAGE_SHIELDED or
		result == ACTION_RESULT_PRECISE_DAMAGE or
		result == ACTION_RESULT_WRECKING_DAMAGE or 
		result == ACTION_RESULT_FALL_DAMAGE or 
		result == ACTION_RESULT_FALLING then
		
			local attackInfo =
			{
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
			
			if attackInfo.attackOverflow ~= 0 then
				attackInfo.wasKillingBlow = true
			end
			
			ADR.EnqueueAttack(attackInfo)
			
	elseif hitValue ~= 0 and
		(result == ACTION_RESULT_CRITICAL_HEAL or 
		result == ACTION_RESULT_HEAL or
		result == ACTION_RESULT_HOT_TICK or
		result == ACTION_RESULT_HOT_TICK_CRITICAL or
		result == ACTION_RESULT_HOT) then
				
			--incoming healing (No overflow)
			
			local attackInfo =
			{
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
			
			ADR.EnqueueAttack(attackInfo)
			
	elseif result == ACTION_RESULT_ABSORBED  or 
			result == ACTION_RESULT_HEAL_ABSORBED or 
			result == ACTION_RESULT_DODGED or 
			result == ACTION_RESULT_INTERRUPT or
			result == ACTION_RESULT_REFLECTED or 
			result == ACTION_RESULT_ROOTED or 
			result == ACTION_RESULT_SILENCED or 
			result == ACTION_RESULT_SNARED or 
			result == ACTION_RESULT_STUNNED or 
			result == ACTION_RESULT_FEARED then
			
		local attackInfo =
		{
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
		
		ADR.EnqueueAttack(attackInfo)
	end
end

function ADR.Initialize()
	
	ADR.lastCastTimes = {}
	GetNumKillingAttacks = function() return ADR.attackList.size end
	
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
		ZO_DeathRecap:SetHidden(not ZO_DeathRecap:IsHidden())
	end
	
  --[[ZO_DeathRecapScrollContainerScrollChildAttacks																				Type: Control
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
	--				($parent) AttackName				ZO_DeathRecapScrollContainerScrollChildAttacks1AttackTextAttackName			Type:]]
	EVENT_MANAGER:RegisterForEvent(ADR.name, EVENT_PLAYER_DEAD, function() 
		ADR.lastCastTimes = {}

		--wait for the controls to be made before modifying them.
		zo_callLater(function()
			local finalizedAttackList = ADR.GetOrderedList()
			
			--Update display times
			for k, v in ipairs(finalizedAttackList) do
				v.displayTimeMS = finalizedAttackList[#finalizedAttackList].lastUpdateAgoMS - v.lastUpdateAgoMS
			end
		
			for i = 1, #finalizedAttackList do
				local rowData = finalizedAttackList[i]

				local currentRow = ZO_DeathRecapScrollContainerScrollChildAttacks:GetNamedChild(tostring(i))
				
				--Change icon texture
				local attack_icon = currentRow:GetNamedChild("Icon")
				attack_icon:SetTexture(rowData.attackIcon)
				
				--Display timeline using these controls.
				local numAttackHits = currentRow:GetNamedChild("NumAttackHits")
				local attackCount = numAttackHits:GetNamedChild("Count")
				if rowData.wasKillingBlow == false then
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
				end
				
				--HP display using new control.
				local health_display = GetControl(currentRow:GetName().."Health")
				if health_display == nil then
					health_display = CreateControl(currentRow:GetName().."Health", currentRow, CT_LABEL)
					health_display:SetHidden(false)
					health_display:SetFont("ZoFontGamepad22")
					health_display:SetColor(1, 0.25, 0.25, 1)
					health_display:SetAnchor(TOPRIGHT, attackCount, BOTTOMRIGHT, 0, -2)
				end
				health_display:SetText("HP: "..ZO_CommaDelimitDecimalNumber(rowData.currentHealth).."/"..ZO_CommaDelimitDecimalNumber(rowData.currentMaxHealth))
				if rowData.wasKillingBlow then health_display:SetHidden(true) end
				
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
			
			end
			
			
			--Force the animation to start playing to avoid some weird, inconsistent visual bugs.
			DEATH:ToggleDeathRecap()
			DEATH:ToggleDeathRecap()
			
		end, 2500)
	end)
	
	--reset attack list on respawn.
	EVENT_MANAGER:RegisterForEvent(ADR.name, EVENT_PLAYER_ALIVE, function() 
		ADR.lastCastTimes = {}
		ADR.Reset()
	end)
	
	EVENT_MANAGER:RegisterForEvent(ADR.name, EVENT_COMBAT_EVENT, ADR.OnCombatEvent)
	EVENT_MANAGER:AddFilterForEvent(ADR.name, EVENT_COMBAT_EVENT, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
end
	
function ADR.OnAddOnLoaded(event, addonName)
	if addonName == ADR.name then
		ADR.Initialize()
		EVENT_MANAGER:UnregisterForEvent(ADR.name, EVENT_ADD_ON_LOADED)
	end
end

EVENT_MANAGER:RegisterForEvent(ADR.name, EVENT_ADD_ON_LOADED, ADR.OnAddOnLoaded)