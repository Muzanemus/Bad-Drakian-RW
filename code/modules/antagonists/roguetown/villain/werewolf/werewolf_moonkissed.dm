// Adapted from Rivermist Hollow's wolf partial-transformation kit (AGPL-3.0).
// Revision 8dba961e768e; modular_rmh/code/modules/partial_transformation/kits/wolf_kit.dm.

/datum/antagonist/werewolf
	var/moonkissed_shifted = FALSE
	var/times_shifted = 0
	var/list/moonkissed_original_organs = list()
	var/list/moonkissed_replacements = list()
	var/list/moonkissed_frozen_flags = list()
	var/obj/effect/proc_holder/spell/self/howl/moonbound/moonkissed_howl
	var/datum/weakref/moonkissed_body_ref

/obj/effect/proc_holder/spell/self/moonkissed
	name = "Embrace the Moon's Kiss"
	desc = "Let the shallow mooncurse surface: wolfish ears, tail and vigor. Cast again to suppress it."
	overlay_state = "tamebeast"
	clothes_req = FALSE
	human_req = FALSE
	antimagic_allowed = TRUE
	ignore_cockblock = TRUE
	recharge_time = 5 SECONDS

/obj/effect/proc_holder/spell/self/moonkissed/cast(list/targets, mob/living/carbon/human/user)
	var/datum/antagonist/werewolf/W = user.mind?.has_antag_datum(/datum/antagonist/werewolf)
	if(!W?.is_moonkissed)
		revert_cast(user)
		return FALSE
	if(W.moonkissed_shifted)
		W.unshift_moonkissed(user)
		return TRUE
	if(HAS_TRAIT(user, TRAIT_SILVER_BLESSED) || HAS_TRAIT(user, TRAIT_WEREWOLF_TRANSFORMATION_SUPPRESSED) || user.is_shapeshift_shell())
		to_chat(user, span_warning("A binding or another transformation keeps the moon's kiss buried."))
		revert_cast(user)
		return FALSE
	W.shift_moonkissed(user)
	return TRUE

/obj/item/organ/ears/moonkissed
	name = "wolfish ears"
	accessory_type = /datum/sprite_accessory/ears/wolf

/obj/item/organ/tail/moonkissed
	name = "wolfish tail"
	accessory_type = /datum/sprite_accessory/tail/wolf

/datum/status_effect/buff/moonkissed
	id = "moonkissed"
	duration = -1
	alert_type = null
	effectedstats = list(STATKEY_STR = 1, STATKEY_WIL = 1, STATKEY_SPD = 2, STATKEY_PER = 2)

/datum/antagonist/werewolf/proc/shift_moonkissed(mob/living/carbon/human/H)
	if(!is_moonkissed || moonkissed_shifted || owner?.current != H)
		return FALSE
	var/list/swaps = list(ORGAN_SLOT_EARS = /obj/item/organ/ears/moonkissed, ORGAN_SLOT_TAIL = /obj/item/organ/tail/moonkissed)
	var/obj/item/organ/penis/penis = H.getorganslot(ORGAN_SLOT_PENIS)
	if(istype(penis) && penis.type == /obj/item/organ/penis)
		swaps[ORGAN_SLOT_PENIS] = /obj/item/organ/penis/knotted
	for(var/slot in swaps)
		var/obj/item/organ/original = H.getorganslot(slot)
		if(original)
			moonkissed_original_organs[slot] = original
			moonkissed_frozen_flags[slot] = !!(original.organ_flags & ORGAN_FROZEN)
			original.Remove(H, TRUE)
			original.organ_flags |= ORGAN_FROZEN
		var/replacement_type = swaps[slot]
		var/obj/item/organ/replacement = new replacement_type
		if(original)
			replacement.accessory_colors = original.accessory_colors
			replacement.damage = original.damage
			replacement.organ_flags |= original.organ_flags & ORGAN_FAILING
		replacement.Insert(H, TRUE)
		moonkissed_replacements[slot] = replacement
	moonkissed_body_ref = WEAKREF(H)
	moonkissed_shifted = TRUE
	times_shifted++
	H.apply_status_effect(/datum/status_effect/buff/moonkissed)
	ADD_TRAIT(H, TRAIT_KEENEARS, REF(src))
	moonkissed_howl = new
	H.AddSpell(moonkissed_howl)
	playsound(H, 'sound/vo/mobs/wwolf/wolftalk1.ogg', 75, TRUE)
	H.update_body_parts(TRUE)
	to_chat(H, span_notice("The moon's kiss surges through me. Wolfish ears and a tail awaken."))
	return TRUE

/datum/antagonist/werewolf/proc/unshift_moonkissed(mob/living/carbon/human/H)
	if(!moonkissed_shifted)
		return
	H = moonkissed_body_ref?.resolve()
	for(var/slot in moonkissed_replacements)
		var/obj/item/organ/replacement = moonkissed_replacements[slot]
		var/obj/item/organ/original = moonkissed_original_organs[slot]
		var/still_attached = H && !QDELETED(replacement) && H.getorganslot(slot) == replacement
		if(still_attached)
			replacement.Remove(H, TRUE)
		if(!QDELETED(original))
			if(!moonkissed_frozen_flags[slot])
				original.organ_flags &= ~ORGAN_FROZEN
			if(still_attached)
				original.damage = max(original.damage, replacement.damage)
				original.Insert(H, TRUE)
			else if(H)
				original.forceMove(get_turf(H))
			else
				qdel(original)
		if(!QDELETED(replacement))
			qdel(replacement)
	if(H)
		REMOVE_TRAIT(H, TRAIT_KEENEARS, REF(src))
		H.mob_spell_list -= moonkissed_howl
		playsound(H, 'sound/vo/mobs/wwolf/wolftalk2.ogg', 75, TRUE)
	QDEL_NULL(moonkissed_howl)
	H?.remove_status_effect(/datum/status_effect/buff/moonkissed)
	H?.update_body_parts(TRUE)
	moonkissed_shifted = FALSE
	moonkissed_body_ref = null
	moonkissed_original_organs.Cut()
	moonkissed_replacements.Cut()
	moonkissed_frozen_flags.Cut()
	if(H)
		to_chat(H, span_notice("The moon's kiss recedes beneath my skin."))
