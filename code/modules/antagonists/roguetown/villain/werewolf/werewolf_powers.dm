// Adapted from Rivermist Hollow (AGPL-3.0), revision 8dba961e768e.
// Source: code/modules/spells/spell_types/pointed/{lunge,throw,aoe/howl}.dm.
// https://github.com/sheetofseaweed/Rivermist-Hollow-Vanderlin/tree/8dba961e768ecf8b9cbbc7b8199372f6a9fead96

/obj/effect/proc_holder/spell/invoked/werewolf
	clothes_req = FALSE
	human_req = FALSE
	antimagic_allowed = TRUE
	ignore_cockblock = TRUE
	invocation_type = "none"
	chargetime = 0
	chargedrain = 0
	associated_skill = null
	is_cdr_exempt = TRUE
	var/rage_cost = 0

/obj/effect/proc_holder/spell/invoked/werewolf/proc/pay_rage(mob/living/user)
	var/datum/antagonist/werewolf/W = user.mind?.has_antag_datum(/datum/antagonist/werewolf)
	if(!W || !W.spend_rage(rage_cost, user))
		revert_cast(user)
		return FALSE
	return TRUE

/obj/effect/proc_holder/spell/invoked/werewolf/proc/has_beast_caster(mob/living/user)
	if(QDELETED(src) || QDELETED(user))
		return FALSE
	var/datum/antagonist/werewolf/W = user.mind?.has_antag_datum(/datum/antagonist/werewolf)
	return W?.transformed && W.owner?.current == user && (src in W.beast_spells)

/obj/effect/proc_holder/spell/invoked/werewolf/lunge
	name = "Predatory Lunge"
	desc = "Spring toward a target and grapple them, or strike with extended claws."
	overlay_state = "claws"
	range = 6
	recharge_time = 45 SECONDS
	rage_cost = 30

/obj/effect/proc_holder/spell/invoked/werewolf/lunge/cast(list/targets, mob/living/carbon/human/user)
	var/mob/living/target = targets[1]
	if(!istype(target) || target == user || !isturf(user.loc) || !isturf(target.loc) || user.pulling || user.pulledby || user.incapacitated() || get_dist(user, target) > range || target.z != user.z)
		revert_cast(user)
		return FALSE
	if(!pay_rage(user))
		return FALSE
	if(!do_after(user, 2 SECONDS, target = target))
		return FALSE
	if(!has_beast_caster(user) || QDELETED(target) || user.incapacitated() || !isturf(target.loc) || !isturf(user.loc) || target.z != user.z || get_dist(user, target) > range)
		return FALSE
	var/steps_left = range * 3 + 1
	var/failures = 0
	while(!user.Adjacent(target) && steps_left-- > 0)
		if(!has_beast_caster(user) || user.incapacitated() || QDELETED(target) || target.z != user.z || !isturf(target.loc))
			return FALSE
		if(!step_to(user, target))
			failures++
		if(failures >= 3)
			break
		sleep(1)
	if(!has_beast_caster(user) || !user.Adjacent(target) || user.incapacitated())
		return FALSE
	if(ishuman(target))
		var/mob/living/carbon/human/H = target
		if(H.stat == DEAD)
			var/obj/item/organ/heart = H.getorganslot(ORGAN_SLOT_HEART)
			if(heart)
				heart.Remove(H)
				user.put_in_hands(heart)
		else if(istype(user.get_active_held_item(), /obj/item/rogueweapon/werewolf_claw))
			var/obj/item/bodypart/chest = H.get_bodypart(BODY_ZONE_CHEST)
			chest?.add_wound(/datum/wound/slash/large)
			H.apply_damage(40, BRUTE, BODY_ZONE_CHEST)
		else
			H.grabbedby(user)
			H.grippedby(user, instant = TRUE)
	else
		user.start_pulling(target)
	if(user.alpha <= 40 || get_dir(target, user) != target.dir)
		target.Knockdown(2 SECONDS)
	user.visible_message(span_warning("[user] lunges at [target]!"))
	return TRUE

/obj/effect/proc_holder/spell/invoked/werewolf/throw_target
	name = "Predatory Throw"
	desc = "Hurl a grabbed foe at a nearby location."
	overlay_state = "claws"
	range = 7
	recharge_time = 30 SECONDS
	rage_cost = 25

/obj/effect/proc_holder/spell/invoked/werewolf/throw_target/cast(list/targets, mob/living/user)
	var/turf/destination = get_turf(targets[1])
	var/mob/living/victim = user.pulling
	if(!istype(victim) || !destination || destination.z != user.z || get_dist(user, destination) > range || user.incapacitated() || user.pulledby)
		revert_cast(user)
		return FALSE
	if(!pay_rage(user))
		return FALSE
	if(!do_after(user, 1 SECONDS, target = victim))
		return FALSE
	if(!has_beast_caster(user) || QDELETED(victim) || user.pulling != victim || !user.Adjacent(victim) || user.incapacitated() || user.z != destination.z || get_dist(user, destination) > range)
		return FALSE
	user.stop_pulling()
	victim.adjustBruteLoss(10)
	victim.Knockdown(1 SECONDS)
	victim.throw_at(destination, range, 2, user, callback = CALLBACK(src, PROC_REF(predatory_impact), victim))
	user.visible_message(span_warning("[user] hurls [victim] through the air!"))
	return TRUE

/obj/effect/proc_holder/spell/invoked/werewolf/throw_target/proc/predatory_impact(mob/living/victim)
	if(QDELETED(victim))
		return
	victim.adjustBruteLoss(15)
	victim.Knockdown(2 SECONDS)
	victim.Paralyze(0.5 SECONDS)
	for(var/mob/living/bystander in get_turf(victim))
		if(bystander != victim)
			bystander.adjustBruteLoss(10)
			bystander.Knockdown(1.5 SECONDS)

/obj/effect/proc_holder/spell/self/terrifying_howl
	name = "Terrifying Howl"
	desc = "Repel nearby attackers with a terrifying roar. Costs 45 rage."
	overlay_state = "howl"
	clothes_req = FALSE
	human_req = FALSE
	antimagic_allowed = TRUE
	ignore_cockblock = TRUE
	recharge_time = 50 SECONDS

/obj/effect/proc_holder/spell/self/terrifying_howl/cast(list/targets, mob/living/user)
	var/datum/antagonist/werewolf/W = user.mind?.has_antag_datum(/datum/antagonist/werewolf)
	if(!W || !W.spend_rage(45, user))
		revert_cast(user)
		return FALSE
	playsound(user, 'sound/vo/mobs/wwolf/roar.ogg', 100, TRUE)
	for(var/mob/living/victim in view(5, user))
		if(victim == user || HAS_TRAIT(victim, TRAIT_WEREWOLF_STAGGERED))
			continue
		var/distance = get_dist(user, victim)
		victim.Immobilize(clamp(1.5 SECONDS * (1 - distance / 5), 0.1 SECONDS, 1.5 SECONDS))
		if(distance == 1)
			victim.throw_at(get_step(victim, get_dir(user, victim)), 1, 1, user)
		ADD_TRAIT(victim, TRAIT_WEREWOLF_STAGGERED, "howl")
		addtimer(TRAIT_CALLBACK_REMOVE(victim, TRAIT_WEREWOLF_STAGGERED, "howl"), 60 SECONDS)
	return TRUE

/obj/effect/proc_holder/spell/self/claws/moonbound
	recharge_time = 5 SECONDS

/obj/effect/proc_holder/spell/self/howl/moonbound
	desc = "Communicate with the pack. Those versed in Beast Tongue may understand me."
	howl_distance_limit = 500
	associated_skill = null

/obj/effect/proc_holder/spell/self/howl/moonbound/cast(list/targets, mob/living/user)
	var/datum/antagonist/werewolf/W = user.mind?.has_antag_datum(/datum/antagonist/werewolf)
	if(!W)
		revert_cast(user)
		return FALSE
	var/message = tgui_input_text(user, "Howl to the hidden moon...", "Mooncursed", max_length = 512, timeout = 45 SECONDS)
	if(!message || QDELETED(user) || QDELETED(src) || QDELETED(W) || W.owner?.current != user || user.stat != CONSCIOUS)
		if(!QDELETED(src))
			revert_cast(user)
		return FALSE
	var/safe_message = html_encode(message)
	playsound(user, pick(howl_sounds), 75, TRUE)
	to_chat(user, span_boldannounce("I howl to the hidden moon: [safe_message]"))
	for(var/mob/player in GLOB.player_list)
		if(player == user || !player.mind || player.stat == DEAD || isbrain(player))
			continue
		if(player.mind.has_antag_datum(/datum/antagonist/werewolf) || player.has_language(/datum/language/beast))
			to_chat(player, span_boldannounce("[W.wolfname] howls to the hidden moon: [safe_message]"))
		if(player.z == user.z && get_dist(player, user) > 7 && get_dist(player, user) <= howl_distance_limit)
			player.playsound_local(get_turf(player), pick(howl_sounds_far), 50, FALSE, pressure_affected = FALSE)
	user.log_message("howls: [message] (WEREWOLF)", LOG_GAME)
	return TRUE

/obj/effect/proc_holder/spell/self/keen_nose
	name = "Sniff for Scents"
	desc = "Smell nearby creatures and the direction of my den."
	overlay_state = "howl"
	clothes_req = FALSE
	human_req = FALSE
	antimagic_allowed = TRUE
	ignore_cockblock = TRUE
	recharge_time = 30 SECONDS

/obj/effect/proc_holder/spell/self/keen_nose/cast(list/targets, mob/living/user)
	user.visible_message(span_notice("[user] sniffs the air."))
	var/found = FALSE
	for(var/mob/living/target in range(20, user))
		if(target == user)
			continue
		found = TRUE
		var/scent = target.stat == DEAD ? "something rotten" : "a creature"
		if(target.mind?.has_antag_datum(/datum/antagonist/werewolf))
			scent = "a member of my pack"
		to_chat(user, span_notice("I smell [scent] to the [dir2text(get_dir(user, target))], [get_dist(user, target)] paces away."))
	if(!found)
		to_chat(user, span_notice("No creatures are nearby, save myself."))
	var/datum/antagonist/werewolf/W = user.mind?.has_antag_datum(/datum/antagonist/werewolf)
	W?.sniff_lair(user)
	return TRUE

/obj/effect/proc_holder/spell/invoked/werewolf/woundlick
	name = "Lick the Wounds"
	desc = "Spend 5 rage and seven seconds tending someone's wounds."
	overlay_state = "diagnose"
	range = 1
	rage_cost = 5
	recharge_time = 5 SECONDS

/obj/effect/proc_holder/spell/invoked/werewolf/woundlick/cast(list/targets, mob/living/user)
	var/mob/living/carbon/human/target = targets[1]
	if(!istype(target) || !user.Adjacent(target) || target.stat == DEAD)
		revert_cast(user)
		return FALSE
	if(!pay_rage(user))
		return FALSE
	if(!do_after(user, 7 SECONDS, target = target))
		return FALSE
	if(!has_beast_caster(user) || QDELETED(target) || !user.Adjacent(target) || user.incapacitated() || target.stat == DEAD)
		return FALSE
	target.reagents?.add_reagent(/datum/reagent/medicine/healthpot, 5)
	target.visible_message(span_notice("[user] tends [target]'s wounds."))
	return TRUE
