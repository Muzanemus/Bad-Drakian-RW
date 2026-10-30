// Adapted from Rivermist Hollow (AGPL-3.0), revision 8dba961e768e.
// https://github.com/sheetofseaweed/Rivermist-Hollow-Vanderlin/tree/8dba961e768ecf8b9cbbc7b8199372f6a9fead96

/datum/antagonist/werewolf/on_life(mob/user)
	var/mob/living/carbon/human/H = user
	if(!istype(H) || H.stat == DEAD || H.advsetup || owner?.current != H)
		return
	// Life and DeadLife can both dispatch antagonist ticks; use one clock per curse.
	if(world.time < next_curse_tick)
		return
	next_curse_tick = world.time + 2 SECONDS
	if(!is_moonkissed)
		update_rage(transformed ? -5.5 : -0.5)
		if(transformed && rage >= 50 && !H.IsParalyzed() && H.get_blood_volume() > BLOOD_VOLUME_SURVIVE)
			for(var/obj/item/bodypart/part as anything in H.bodyparts)
				for(var/datum/wound/wound as anything in part.wounds)
					wound.heal_wound(1.2)
		update_moon_pressure(H)

/datum/antagonist/werewolf/proc/update_moon_pressure(mob/living/carbon/human/H)
	if(last_seen_tod != GLOB.tod)
		var/previous = last_seen_tod
		last_seen_tod = GLOB.tod
		if(!isnull(previous) && GLOB.tod == "night")
			if(transformed || transformed_since_last_nightfall)
				reset_moon_pressure()
			else
				nights_without_transformation = min(nights_without_transformation + 1, 3)
				H.remove_stress_list(list(/datum/stressevent/werewolf_restless_1, /datum/stressevent/werewolf_restless_2, /datum/stressevent/werewolf_restless_3))
				switch(nights_without_transformation)
					if(1)
						H.add_stress(/datum/stressevent/werewolf_restless_1)
					if(2)
						H.add_stress(/datum/stressevent/werewolf_restless_2)
					if(3)
						H.add_stress(/datum/stressevent/werewolf_restless_3)
						forced_transformation_pending = TRUE
				to_chat(H, span_warning("The beast has been denied for [nights_without_transformation] nightfalls."))
			transformed_since_last_nightfall = FALSE
	if(forced_transformation_pending && can_change_form(H))
		begin_form_change(H, TRUE)

/datum/antagonist/werewolf/proc/reset_moon_pressure()
	nights_without_transformation = 0
	forced_transformation_pending = FALSE
	var/mob/living/carbon/human/H = owner?.current
	if(transformed)
		H = H?.stored_mob
	H?.remove_stress_list(list(/datum/stressevent/werewolf_restless_1, /datum/stressevent/werewolf_restless_2, /datum/stressevent/werewolf_restless_3))

/datum/antagonist/werewolf/proc/can_change_form(mob/living/carbon/human/H, feedback = FALSE)
	var/reason
	if(QDELETED(H) || owner?.current != H || H.stat != CONSCIOUS || H.advsetup)
		reason = "I am in no condition to command the beast."
	else if(is_moonkissed)
		reason = "My shallow curse cannot take a beast's form."
	else if(transforming || untransforming)
		reason = "My body is already changing."
	else if(world.time < form_change_ready_at)
		reason = "My form is still settling for [DisplayTimeText(form_change_ready_at - world.time)]."
	else if(!transformed && (HAS_TRAIT(H, TRAIT_SILVER_BLESSED) || HAS_TRAIT(H, TRAIT_WEREWOLF_TRANSFORMATION_SUPPRESSED)))
		reason = "Silver or a holy blessing keeps the beast caged."
	else if(H.notransform || (!transformed && H.is_shapeshift_shell()))
		reason = "Another transformation prevents the change."
	if(reason)
		if(feedback && !QDELETED(H))
			to_chat(H, span_warning(reason))
		return FALSE
	return TRUE

/datum/antagonist/werewolf/proc/begin_form_change(mob/living/carbon/human/H, forced = FALSE)
	set waitfor = FALSE
	if(!can_change_form(H, TRUE))
		return FALSE
	var/was_transformed = transformed
	var/datum/mind/original_mind = owner
	if(was_transformed)
		untransforming = TRUE
	else
		transforming = TRUE
	H.Stun(3.5 SECONDS, ignore_canstun = TRUE)
	H.fullscreen_redflash("redflash3")
	H.emote("scream", forced = TRUE)
	sleep(1.5 SECONDS)
	if(!QDELETED(H))
		H.emote("scream", forced = TRUE)
	sleep(1.5 SECONDS)
	if(QDELETED(src))
		return FALSE
	transforming = FALSE
	untransforming = FALSE
	if(QDELETED(H) || owner != original_mind || H.mind != owner || transformed != was_transformed || !can_change_form(H, TRUE))
		return FALSE
	if(was_transformed)
		H.werewolf_untransform()
	else
		H.werewolf_transform()
	return TRUE

/datum/antagonist/werewolf/proc/finish_form_change()
	transforming = FALSE
	untransforming = FALSE
	form_change_ready_at = world.time + 5 MINUTES
	transformed_since_last_nightfall = TRUE
	reset_moon_pressure()

/datum/stressevent/werewolf_restless_1
	desc = "The beast is growing restless beneath my skin."
	stressadd = 2
/datum/stressevent/werewolf_restless_2
	desc = "Denying the beast is becoming unbearable."
	stressadd = 4
/datum/stressevent/werewolf_restless_3
	desc = "The beast is furious at being denied."
	stressadd = 6

/mob/living/carbon/human/species/werewolf/death(gibbed, nocutscene = FALSE)
	werewolf_untransform(TRUE, gibbed)

/mob/living/carbon/human/proc/werewolf_transform()
	if(!mind)
		return
	Paralyze(1, ignore_canstun = TRUE)
	for(var/obj/item/item in get_equipped_items(FALSE))
		if(istype(item, /obj/item/clothing) || istype(item, /obj/item/storage/belt))
			item.take_damage(item.max_integrity * 0.15, sound_effect = FALSE)
		else
			dropItemToGround(item)
	regenerate_icons()
	icon = null
	var/oldinv = invisibility
	invisibility = INVISIBILITY_MAXIMUM
	cmode = FALSE
	if(client)
		SSdroning.play_area_sound(get_area(src), client)
//	stop_cmusic() // cboy cmusic

	fully_heal(FALSE)

	var/ww_path
	if(gender == MALE)
		ww_path = /mob/living/carbon/human/species/werewolf/male
	else
		ww_path = /mob/living/carbon/human/species/werewolf/female

	var/mob/living/carbon/human/species/werewolf/W = new ww_path(loc)


	W.set_patron(src.patron)
	W.gender = gender
	W.regenerate_icons()
	W.stored_mob = src

	//Set the werewolf's name from the antagonist datum
	var/datum/antagonist/werewolf/Were = mind.has_antag_datum(/datum/antagonist/werewolf/)
	if(Were)
		W.real_name = Were.wolfname
		W.name = Were.wolfname
		Were.transformed = TRUE
		Were.transforming = FALSE
	W.limb_destroyer = TRUE
	W.ambushable = FALSE
	W.cmode_music = 'sound/music/cmode/antag/combat_darkstar.ogg'
	W.skin_armor = new /obj/item/clothing/suit/roguetown/armor/skin_armor/werewolf_skin(W)
	playsound(W.loc, pick('sound/combat/gib (1).ogg','sound/combat/gib (2).ogg'), 80, FALSE, 3)
	W.spawn_gibs(FALSE)
	src.forceMove(W)
	notransform = TRUE

	W.after_creation()
	W.stored_language = new
	W.stored_language.copy_known_languages_from(src)
	W.stored_skills = ensure_skills().known_skills.Copy()
	W.stored_experience = ensure_skills().skill_experience.Copy()
	W.cmode_music_override = cmode_music_override
	W.cmode_music_override_name = cmode_music_override_name
	mind.transfer_to(W)
	W.remove_all_languages()
	W.grant_language(/datum/language/beast)

	W.base_intents = list(INTENT_HELP, INTENT_DISARM, INTENT_GRAB)
	W.update_a_intents()

	to_chat(W, span_userdanger("I transform into a horrible beast!"))
	W.emote("rage")

	if(getorganslot(ORGAN_SLOT_PENIS))
		var/obj/item/organ/organ = new /obj/item/organ/penis/knotted/big
		organ.Insert(W, TRUE)
	if(getorganslot(ORGAN_SLOT_TESTICLES))
		var/obj/item/organ/organ = new /obj/item/organ/testicles
		organ.Insert(W, TRUE)
	if(getorganslot(ORGAN_SLOT_BREASTS))
		var/obj/item/organ/organ = new /obj/item/organ/breasts
		organ.Insert(W, TRUE)
	if(getorganslot(ORGAN_SLOT_VAGINA))
		var/obj/item/organ/organ = new /obj/item/organ/vagina
		organ.Insert(W, TRUE)

	W.adjust_skillrank(/datum/skill/combat/wrestling, max(0, 5 - W.get_skill_level(/datum/skill/combat/wrestling)), TRUE)
	W.adjust_skillrank(/datum/skill/combat/unarmed, max(0, 5 - W.get_skill_level(/datum/skill/combat/unarmed)), TRUE)
	W.adjust_skillrank(/datum/skill/misc/climbing, max(0, 6 - W.get_skill_level(/datum/skill/misc/climbing)), TRUE)

	W.STASTR = 20
	W.STACON = 20
	W.STAWIL = 20
	W.STAPER = 15
	W.STASPD = 13
	W.STAINT = 7

	if(Were)
		Were.grant_beast_powers(W)
		Were.finish_form_change()
	ADD_TRAIT(src, TRAIT_NOSLEEP, REF(Were))

	invisibility = oldinv

/mob/living/carbon/human/proc/werewolf_untransform(dead,gibbed)
	set waitfor = FALSE
	if(!stored_mob)
		return
	if(!mind)
		return
	icon = null
	invisibility = INVISIBILITY_MAXIMUM

	var/mob/living/carbon/human/W = stored_mob
	stored_mob = null
	W.notransform = FALSE
	var/datum/antagonist/werewolf/antag = mind?.has_antag_datum(/datum/antagonist/werewolf)
	REMOVE_TRAIT(W, TRAIT_NOSLEEP, REF(antag))
	if(antag)
		antag.remove_beast_powers(src)

	W.forceMove(get_turf(src))

	REMOVE_TRAIT(W, TRAIT_NOMOOD, TRAIT_GENERIC)
	REMOVE_TRAIT(W, TRAIT_SILVER_WEAK, TRAIT_GENERIC)

	if(antag)
		antag.transformed = FALSE
	mind.transfer_to(W)

	var/mob/living/carbon/human/species/werewolf/WA = src
	W.remove_all_languages()
	W.copy_known_languages_from(WA.stored_language)
	W.ensure_skills().known_skills = WA.stored_skills.Copy()
	W.ensure_skills().skill_experience = WA.stored_experience.Copy()

	if(antag)
		antag.finish_form_change()
	W.regenerate_icons()

	// The player and stored body are restored before any potentially sleeping effects.
	INVOKE_ASYNC(W, TYPE_PROC_REF(/mob/living/carbon/human, finish_werewolf_return), dead, gibbed)
	for(var/obj/item/item in src)
		dropItemToGround(item)
	if(!QDELETED(src))
		qdel(src)

/mob/living/carbon/human/proc/finish_werewolf_return(dead, gibbed)
	if(dead)
		death(gibbed)
	to_chat(src, span_userdanger("I return to my facade."))
	playsound(loc, pick('sound/combat/gib (1).ogg','sound/combat/gib (2).ogg'), 200, FALSE, 3)
	spawn_gibs(FALSE)
	Knockdown(1 SECONDS)

/mob/living/carbon/human/species/werewolf/Destroy()
	// Administrative deletion must not delete the player stored inside the beast.
	if(stored_mob && mind?.current == src)
		INVOKE_ASYNC(src, PROC_REF(werewolf_untransform), stat == DEAD)
	return ..()
