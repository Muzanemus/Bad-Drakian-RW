// Adapted from Rivermist Hollow (AGPL-3.0), revision 8dba961e768e.
// Source: code/datums/rage/werewolf_rage.dm and code/modules/antagonists/villain/werewolf/.
// https://github.com/sheetofseaweed/Rivermist-Hollow-Vanderlin/tree/8dba961e768ecf8b9cbbc7b8199372f6a9fead96

/datum/antagonist/werewolf/proc/grant_curse_powers()
	if(!owner?.current || length(curse_spells))
		return
	var/list/powers = is_moonkissed ? list(/obj/effect/proc_holder/spell/self/moonkissed) : list(/obj/effect/proc_holder/spell/self/werewolf_form, /obj/effect/proc_holder/spell/self/moon_journal)
	for(var/power in powers)
		var/obj/effect/proc_holder/spell/spell = new power
		curse_spells += spell
		owner.AddSpell(spell, owner.current)
	bind_curse_body(owner.current)
	owner.current.grant_language(/datum/language/beast)
	if(!is_moonkissed)
		setup_contracts()

/datum/antagonist/werewolf/on_body_transfer(mob/living/old_body, mob/living/new_body)
	. = ..()
	if(old_body)
		UnregisterSignal(old_body, list(COMSIG_MOB_APPLY_DAMGE, COMSIG_MOB_ADD_STRESS, COMSIG_LIVING_COMBAT_KILL))
	// A possession/admin mind transfer must not leave a suspended human trapped
	// in an abandoned beast, nor carry the beast's skill floors to the new body.
	if(istype(old_body, /mob/living/carbon/human/species/werewolf))
		var/mob/living/carbon/human/species/werewolf/beast = old_body
		var/mob/living/carbon/human/original = beast.stored_mob
		if(original && new_body != original)
			beast.stored_mob = null
			original.notransform = FALSE
			REMOVE_TRAIT(original, TRAIT_NOSLEEP, REF(src))
			original.forceMove(get_turf(beast))
			original.regenerate_icons()
			if(ishuman(new_body))
				var/mob/living/carbon/human/H = new_body
				H.ensure_skills().known_skills = beast.stored_skills.Copy()
				H.ensure_skills().skill_experience = beast.stored_experience.Copy()
			remove_beast_powers(beast)
			transformed = FALSE
			transforming = FALSE
			untransforming = FALSE
			if(!beast.mind)
				qdel(beast)
	if(moonkissed_shifted)
		unshift_moonkissed(old_body)
	sync_moon_writs(new_body)
	if(contract_party)
		old_body?.verbs -= /mob/living/proc/review_patron_contract
		new_body?.verbs |= /mob/living/proc/review_patron_contract
	bind_curse_body(new_body)

/datum/antagonist/werewolf/proc/bind_curse_body(mob/living/body)
	active_body_ref = WEAKREF(body)
	if(body)
		body.faction |= "wolves"
	if(!is_moonkissed && body)
		RegisterSignal(body, COMSIG_MOB_APPLY_DAMGE, PROC_REF(on_curse_damage), override = TRUE)
		RegisterSignal(body, COMSIG_MOB_ADD_STRESS, PROC_REF(on_curse_stress), override = TRUE)
		RegisterSignal(body, COMSIG_LIVING_COMBAT_KILL, PROC_REF(on_werewolf_kill), override = TRUE)

/datum/antagonist/werewolf/proc/on_curse_damage(mob/living/source, damage, damage_type)
	SIGNAL_HANDLER
	if(source.stat == DEAD || damage <= 0 || !(damage_type in list(BRUTE, BURN)))
		return
	update_rage(max(1, damage / 2))

/datum/antagonist/werewolf/proc/on_curse_stress(mob/living/carbon/source, datum/stressevent/event)
	SIGNAL_HANDLER
	if(source.stat == DEAD || !event)
		return
	update_rage(event.stressadd * 0.1 * (1 + source.get_stress_amount() / 15))

/datum/antagonist/werewolf/proc/update_rage(amount)
	if(is_moonkissed)
		return
	var/mob/living/body = owner?.current
	if(amount > 0 && body?.has_status_effect(/datum/status_effect/debuff/werewolf_silver_bane))
		amount *= 0.25
	rage = clamp(rage + amount, 0, 150)

/datum/antagonist/werewolf/proc/spend_rage(amount, mob/user)
	if(!transformed || owner?.current != user || rage < amount)
		to_chat(user, span_warning("I need [amount] rage in beast form. Current rage: [round(rage, 0.1)]."))
		return FALSE
	update_rage(-amount)
	return TRUE

/datum/antagonist/werewolf/proc/grant_beast_powers(mob/living/carbon/human/body)
	var/list/powers = list(/obj/effect/proc_holder/spell/self/howl/moonbound, /obj/effect/proc_holder/spell/self/claws/moonbound, /obj/effect/proc_holder/spell/invoked/werewolf/woundlick, /obj/effect/proc_holder/spell/self/terrifying_howl, /obj/effect/proc_holder/spell/invoked/werewolf/lunge, /obj/effect/proc_holder/spell/invoked/werewolf/throw_target, /obj/effect/proc_holder/spell/self/keen_nose, /obj/effect/proc_holder/spell/invoked/voluntary_bite, /obj/effect/proc_holder/spell/invoked/werewolf/dig_lair)
	for(var/power in powers)
		var/obj/effect/proc_holder/spell/spell = new power
		beast_spells += spell
		body.AddSpell(spell)

/datum/antagonist/werewolf/proc/remove_beast_powers(mob/living/body)
	for(var/obj/effect/proc_holder/spell/spell as anything in beast_spells)
		body?.mob_spell_list -= spell
		qdel(spell)
	beast_spells.Cut()

/datum/antagonist/werewolf/proc/cleanup_curse()
	if(cleaning_curse)
		return
	cleaning_curse = TRUE
	var/mob/living/carbon/human/body = owner?.current
	reset_moon_pressure()
	if(transformed && istype(body))
		var/mob/living/carbon/human/original = body.stored_mob
		if(original)
			REMOVE_TRAIT(original, TRAIT_NOSLEEP, REF(src))
		INVOKE_ASYNC(body, TYPE_PROC_REF(/mob/living/carbon/human, werewolf_untransform))
		transformed = FALSE
		body = owner?.current
	if(body)
		body.faction -= "wolves"
		body.remove_language(/datum/language/beast)
		UnregisterSignal(body, list(COMSIG_MOB_APPLY_DAMGE, COMSIG_MOB_ADD_STRESS, COMSIG_LIVING_COMBAT_KILL))
		if(is_moonkissed)
			unshift_moonkissed(body)
	for(var/obj/effect/proc_holder/spell/spell as anything in curse_spells)
		owner?.spell_list -= spell
		qdel(spell)
	curse_spells.Cut()
	remove_beast_powers(body)
	teardown_contracts()
	for(var/obj/item/quest_writ/writ as anything in moon_writs.Copy())
		if(writ.assigned_quest)
			qdel(writ.assigned_quest)
		qdel(writ)
	moon_writs.Cut()
	cleanup_lair()
	active_body_ref = null

/datum/antagonist/werewolf/Destroy()
	cleanup_curse()
	return ..()

/datum/status_effect/debuff/werewolf_silver_bane
	id = "werewolf_silver_bane"
	duration = 30 SECONDS
	alert_type = null
	status_type = STATUS_EFFECT_REFRESH
	effectedstats = list(STATKEY_STR = -2, STATKEY_PER = -2, STATKEY_INT = -2, STATKEY_CON = -2, STATKEY_WIL = -2, STATKEY_SPD = -2, STATKEY_LCK = -2)
	var/stacks = 1
	var/overwhelmed = FALSE

/datum/status_effect/debuff/werewolf_silver_bane/on_apply()
	. = ..()
	var/datum/antagonist/werewolf/W = owner.mind?.has_antag_datum(/datum/antagonist/werewolf)
	W?.update_rage(-5)

/datum/status_effect/debuff/werewolf_silver_bane/refresh(mob/living/new_owner)
	. = ..()
	if(overwhelmed)
		return
	stacks = min(stacks + 1, 6)
	var/datum/antagonist/werewolf/W = owner.mind?.has_antag_datum(/datum/antagonist/werewolf)
	W?.update_rage(-5)
	if(stacks == 6)
		overwhelmed = TRUE
		addtimer(CALLBACK(src, PROC_REF(end_overwhelm)), 8 SECONDS)
		owner.Immobilize(4.5 SECONDS)
		owner.Stun(2.25 SECONDS)

/datum/status_effect/debuff/werewolf_silver_bane/proc/end_overwhelm()
	qdel(src)

/obj/item/clothing/neck/roguetown/moonshackle
	name = "moonshackle collar"
	desc = "A heavy silver collar engraved to keep the beast bound in mortal flesh."
	icon = 'icons/roguetown/clothing/neck.dmi'
	mob_overlay_icon = 'icons/roguetown/clothing/onmob/neck.dmi'
	icon_state = "feldcollar"
	item_state = "feldcollar"
	sellprice = 180
	smeltresult = /obj/item/ingot/silver
	max_integrity = 300

/obj/item/clothing/neck/roguetown/moonshackle/equipped(mob/living/user, slot)
	. = ..()
	if(slot == SLOT_NECK)
		ADD_TRAIT(user, TRAIT_WEREWOLF_TRANSFORMATION_SUPPRESSED, REF(src))

/obj/item/clothing/neck/roguetown/moonshackle/dropped(mob/user)
	REMOVE_TRAIT(user, TRAIT_WEREWOLF_TRANSFORMATION_SUPPRESSED, REF(src))
	return ..()

/datum/anvil_recipe/armor/silver/moonshackle
	name = "Moonshackle collar (+1 Silver, Diamond, Ruby, Sapphire)"
	req_bar = /obj/item/ingot/silver
	additional_items = list(/obj/item/ingot/silver, /obj/item/roguegem/diamond, /obj/item/roguegem/ruby, /obj/item/roguegem/blue)
	created_item = /obj/item/clothing/neck/roguetown/moonshackle
	appro_skill = /datum/skill/craft/blacksmithing
	craftdiff = SKILL_LEVEL_LEGENDARY
	minimum_smith_skill = SKILL_LEVEL_LEGENDARY
