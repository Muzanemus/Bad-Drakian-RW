// Adapted from Rivermist Hollow (AGPL-3.0), revision 8dba961e768e.
// Source: code/modules/jobs/job_types/other/werewolf.dm.

/datum/job/roguetown/werewolf
	title = "Werewolf"
	flag = (1<<7)
	department_flag = WANDERERS
	faction = "Station"
	total_positions = 1
	spawn_positions = 1
	roundstart_spawn_rank = "Towner"
	can_random = FALSE
	antag_job = TRUE
	allowed_races = RACES_ALL_KINDS
	allowed_sexes = list(MALE, FEMALE)
	min_pq = null
	max_pq = null
	whitelist_req = TRUE
	announce_latejoin = FALSE
	obsfuscated_job = TRUE
	job_reopens_slots_on_death = FALSE
	display_order = JDO_WRETCH + 0.1
	tutorial = "You carry a hidden curse. Blend into the town, choose when to release the beast, and fulfill the moon's demands."
	outfit = /datum/outfit/job/roguetown/werewolf
	advclass_cat_rolls = list(CTAG_WEREWOLF = 1)
	job_subclasses = list(/datum/advclass/werewolf)

/datum/job/roguetown/werewolf/special_job_check(mob/dead/new_player/player)
	return player?.client && !is_banned_from(player.ckey, list(ROLE_SYNDICATE, ROLE_WEREWOLF))

/datum/job/roguetown/werewolf/special_check_latejoin(client/player)
	return player && !is_banned_from(player.ckey, list(ROLE_SYNDICATE, ROLE_WEREWOLF))

/datum/advclass/werewolf
	name = "Moonbound"
	category_tags = list(CTAG_WEREWOLF)
	outfit = /datum/outfit/job/roguetown/werewolf
	subclass_stats = list(STATKEY_STR = 2, STATKEY_CON = 2, STATKEY_WIL = 2)
	subclass_skills = list(/datum/skill/combat/knives = 2, /datum/skill/combat/wrestling = 5, /datum/skill/combat/unarmed = 6, /datum/skill/misc/climbing = 6, /datum/skill/misc/athletics = 6, /datum/skill/misc/medicine = 4, /datum/skill/misc/sneaking = 4)

/datum/outfit/job/roguetown/werewolf
	name = "Werewolf"
	shirt = /obj/item/clothing/suit/roguetown/shirt/undershirt/random
	pants = /obj/item/clothing/under/roguetown/tights/random
	shoes = /obj/item/clothing/shoes/roguetown/simpleshoes
	backr = /obj/item/storage/backpack/rogue/satchel
	belt = /obj/item/storage/belt/rogue/leather/rope
	beltl = /obj/item/storage/belt/rogue/pouch/coins/poor

/datum/outfit/job/roguetown/werewolf/post_equip(mob/living/carbon/human/H, visualsOnly = FALSE)
	. = ..()
	if(visualsOnly || !H.mind)
		return
	if(!H.mind.has_antag_datum(/datum/antagonist/werewolf))
		H.mind.add_antag_datum(/datum/antagonist/werewolf)

/datum/job/roguetown/werewolf/after_spawn(mob/living/L, mob/M, latejoin = TRUE)
	. = ..()
	if(ishuman(L))
		var/mob/living/carbon/human/H = L
		H.ambushable = FALSE
		INVOKE_ASYNC(H, TYPE_PROC_REF(/mob/living/carbon/human, choose_werewolf_disguise))

/mob/living/carbon/human/proc/choose_werewolf_disguise()
	// Mind/client transfer follows after_spawn. Do not block round setup on the prompt.
	var/deadline = world.time + 1 MINUTES
	while(!client && !QDELETED(src) && world.time < deadline)
		sleep(1)
	if(QDELETED(src) || !client || !mind?.has_antag_datum(/datum/antagonist/werewolf))
		return
	var/datum/mind/original_mind = mind
	var/list/original_items = list()
	for(var/slot in list(SLOT_SHIRT, SLOT_PANTS, SLOT_HEAD, SLOT_ARMOR, SLOT_CLOAK))
		original_items["[slot]"] = get_item_by_slot(slot)
	var/choice = tgui_input_list(src, "Choose the townsfolk identity I will pass as.", "Disguise", list("Traveler", "Laborer", "Farmer"), timeout = 1 MINUTES)
	if(!choice || QDELETED(src) || mind != original_mind || !mind?.has_antag_datum(/datum/antagonist/werewolf))
		return
	var/datum/antagonist/werewolf/W = mind.has_antag_datum(/datum/antagonist/werewolf)
	if(W.transformed)
		return
	var/list/clothing = list("[SLOT_SHIRT]" = /obj/item/clothing/suit/roguetown/shirt/undershirt/brown, "[SLOT_PANTS]" = /obj/item/clothing/under/roguetown/trou)
	switch(choice)
		if("Traveler")
			clothing["[SLOT_CLOAK]"] = /obj/item/clothing/cloak/raincloak
		if("Laborer")
			clothing["[SLOT_HEAD]"] = /obj/item/clothing/head/roguetown/armingcap
			clothing["[SLOT_ARMOR]"] = /obj/item/clothing/suit/roguetown/armor/workervest
		if("Farmer")
			clothing["[SLOT_HEAD]"] = /obj/item/clothing/head/roguetown/strawhat
	for(var/slot_text in clothing)
		var/slot = text2num(slot_text)
		var/obj/item/original = original_items[slot_text]
		// Preserve anything the player changed while the menu was open.
		if(get_item_by_slot(slot) != original)
			continue
		if(original)
			if(!temporarilyRemoveItemFromInventory(original))
				continue
			qdel(original)
		var/item_type = clothing[slot_text]
		equip_to_slot_or_del(new item_type(src), slot)
	advjob = choice
	mind.cosmetic_class_title = choice
	to_chat(src, span_notice("I pass as a [lowertext(choice)]. The mooncurse remains my secret."))

/obj/effect/landmark/start/werewolf
	name = "Werewolf"
