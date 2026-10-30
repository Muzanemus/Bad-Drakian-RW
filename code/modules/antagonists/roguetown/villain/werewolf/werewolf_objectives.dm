// Adapted from Rivermist Hollow (AGPL-3.0), revision 8dba961e768e.
// https://github.com/sheetofseaweed/Rivermist-Hollow-Vanderlin/tree/8dba961e768ecf8b9cbbc7b8199372f6a9fead96/modular_rmh/code/modules/antagonists/contracts
/proc/werewolf_is_player_character(mob/living/target)
	if(!istype(target))
		return FALSE
	if(!target.mind)
		return FALSE
	return TRUE

/proc/werewolf_plural_suffix(amount)
	if(amount == 1)
		return ""
	return "s"

/datum/antagonist/werewolf
	var/tmp/list/bred_player_minds = list()
	var/tmp/animals_hunted_in_wolf_form = 0
	var/tmp/foes_slain_in_wolf_form = 0
	var/tmp/list/converted_player_minds = list()
	var/tmp/list/trapped_player_minds = list()
	var/tmp/contract_objective_score = 0

/datum/antagonist/werewolf/proc/refresh_werewolf_objectives()
	for(var/datum/objective/objective as anything in objectives)
		if(!istype(objective, /datum/objective/werewolf_counter))
			continue
		objective.update_explanation_text()

/datum/antagonist/werewolf/proc/add_contract_objective_score(score_amount)
	if(score_amount <= 0)
		return FALSE

	contract_objective_score += score_amount
	record_contract_progress(/datum/contract_goal/werewolf/hunt_score, score_amount)
	refresh_werewolf_objectives()

	if(owner?.current)
		to_chat(owner.current, span_notice("The moon hunt credits me [score_amount] score. Total: [contract_objective_score]/[WW_CONTRACT_OBJECTIVE_TARGET]."))
		if(contract_objective_score >= WW_CONTRACT_OBJECTIVE_TARGET)
			to_chat(owner.current, span_greentext("The moon hunt is satisfied."))
	return TRUE

/datum/antagonist/werewolf/proc/record_breed_target(mob/living/carbon/human/target)
	if(!transformed)
		return FALSE
	if(!istype(target))
		return FALSE
	if(!werewolf_is_player_character(target))
		return FALSE
	if(target == owner?.current)
		return FALSE
	if(target.mind in bred_player_minds)
		return FALSE

	bred_player_minds += target.mind
	record_contract_progress(/datum/contract_goal/werewolf/breed)
	refresh_werewolf_objectives()
	return TRUE

/datum/antagonist/werewolf/proc/record_conversion_target(mob/living/carbon/human/target)
	if(!istype(target))
		return FALSE
	if(!werewolf_is_player_character(target))
		return FALSE
	if(target.mind in converted_player_minds)
		return FALSE

	converted_player_minds += target.mind
	record_contract_progress(/datum/contract_goal/werewolf/convert)
	refresh_werewolf_objectives()
	return TRUE

/datum/antagonist/werewolf/proc/record_trapped_target(mob/living/target)
	if(!istype(target))
		return FALSE
	if(!werewolf_is_player_character(target))
		return FALSE
	if(target.mind in trapped_player_minds)
		return FALSE

	trapped_player_minds += target.mind
	record_contract_progress(/datum/contract_goal/werewolf/trap)
	refresh_werewolf_objectives()
	return TRUE

/datum/antagonist/werewolf/proc/on_werewolf_kill(mob/living/source, mob/living/victim)
	SIGNAL_HANDLER

	if(!transformed)
		return
	if(!istype(victim))
		return
	if(victim == source)
		return

	if(isanimal(victim))
		animals_hunted_in_wolf_form += 1
		record_contract_progress(/datum/contract_goal/werewolf/hunt_beasts)
		refresh_werewolf_objectives()
		return

	if(werewolf_is_player_character(victim))
		return

	foes_slain_in_wolf_form += 1
	record_contract_progress(/datum/contract_goal/werewolf/slay_foe)
	refresh_werewolf_objectives()

/datum/objective/werewolf_counter
	triumph_count = 5
	var/target_minimum = 1
	var/target_maximum = 1

/datum/objective/werewolf_counter/on_creation()
	target_amount = rand(target_minimum, target_maximum)
	update_explanation_text()

/datum/objective/werewolf_counter/check_completion()
	return get_progress() >= target_amount

/datum/objective/werewolf_counter/proc/get_progress()
	return 0

/datum/objective/werewolf_counter/proc/get_werewolf_antag()
	if(!owner)
		return null
	return owner.has_antag_datum(/datum/antagonist/werewolf)

/datum/objective/werewolf_counter/contracts
	name = "contracts"
	target_minimum = WW_CONTRACT_OBJECTIVE_TARGET
	target_maximum = WW_CONTRACT_OBJECTIVE_TARGET

/datum/objective/werewolf_counter/contracts/get_progress()
	var/datum/antagonist/werewolf/werewolf_antag = get_werewolf_antag()
	if(!werewolf_antag)
		return 0
	return werewolf_antag.contract_objective_score

/datum/objective/werewolf_counter/contracts/update_explanation_text()
	..()
	explanation_text = "Complete moon-hunt contracts until I have [target_amount] hunt score. Progress: [get_progress()]/[target_amount]."

/datum/objective/werewolf_counter/breed
	name = "breed"
	target_minimum = WW_BREED_OBJECTIVE_MIN
	target_maximum = WW_BREED_OBJECTIVE_MAX

/datum/objective/werewolf_counter/breed/get_progress()
	var/datum/antagonist/werewolf/werewolf_antag = get_werewolf_antag()
	if(!werewolf_antag)
		return 0
	return length(werewolf_antag.bred_player_minds)

/datum/objective/werewolf_counter/breed/update_explanation_text()
	..()
	explanation_text = "In beast form, Form bonds with [target_amount] different player[werewolf_plural_suffix(target_amount)]. Progress: [get_progress()]/[target_amount]."

/datum/objective/werewolf_counter/hunt
	name = "hunt"
	target_minimum = WW_HUNT_OBJECTIVE_MIN
	target_maximum = WW_HUNT_OBJECTIVE_MAX

/datum/objective/werewolf_counter/hunt/get_progress()
	var/datum/antagonist/werewolf/werewolf_antag = get_werewolf_antag()
	if(!werewolf_antag)
		return 0
	return werewolf_antag.animals_hunted_in_wolf_form

/datum/objective/werewolf_counter/hunt/update_explanation_text()
	..()
	explanation_text = "In beast form, hunt [target_amount] animal[werewolf_plural_suffix(target_amount)]. Progress: [get_progress()]/[target_amount]."

/datum/objective/werewolf_counter/slay
	name = "slay"
	target_minimum = WW_SLAY_OBJECTIVE_MIN
	target_maximum = WW_SLAY_OBJECTIVE_MAX

/datum/objective/werewolf_counter/slay/get_progress()
	var/datum/antagonist/werewolf/werewolf_antag = get_werewolf_antag()
	if(!werewolf_antag)
		return 0
	return werewolf_antag.foes_slain_in_wolf_form

/datum/objective/werewolf_counter/slay/update_explanation_text()
	..()
	explanation_text = "In beast form, slay [target_amount] non-player foe[werewolf_plural_suffix(target_amount)]. Progress: [get_progress()]/[target_amount]."

/datum/objective/werewolf_counter/convert
	name = "convert"
	target_minimum = WW_CONVERT_OBJECTIVE_MIN
	target_maximum = WW_CONVERT_OBJECTIVE_MAX

/datum/objective/werewolf_counter/convert/get_progress()
	var/datum/antagonist/werewolf/werewolf_antag = get_werewolf_antag()
	if(!werewolf_antag)
		return 0
	return length(werewolf_antag.converted_player_minds)

/datum/objective/werewolf_counter/convert/update_explanation_text()
	..()
	explanation_text = "Convert [target_amount] willing soul[werewolf_plural_suffix(target_amount)] into werewolves. Progress: [get_progress()]/[target_amount]."

/datum/objective/werewolf_counter/trap
	name = "trap"
	target_minimum = WW_TRAP_OBJECTIVE_TARGET
	target_maximum = WW_TRAP_OBJECTIVE_TARGET

/datum/objective/werewolf_counter/trap/get_progress()
	var/datum/antagonist/werewolf/werewolf_antag = get_werewolf_antag()
	if(!werewolf_antag)
		return 0
	return length(werewolf_antag.trapped_player_minds)

/datum/objective/werewolf_counter/trap/update_explanation_text()
	..()
	explanation_text = "Throw [target_amount] different player[werewolf_plural_suffix(target_amount)] into my moon pit. Progress: [get_progress()]/[target_amount]."

// ------------- Moonkissed (lesser werewolf) pack objectives -------------

/datum/objective/werewolf/pack_elder
	name = "pack elder"
	explanation_text = "Follow the pack: at least one elder of my pack must survive."
	triumph_count = 2

/datum/objective/werewolf/pack_elder/check_completion()
	for(var/datum/antagonist/werewolf/wolf as anything in GLOB.antagonists)
		if(!istype(wolf) || wolf.is_moonkissed)
			continue
		if(considered_alive(wolf.owner))
			return TRUE
	return FALSE

/datum/objective/werewolf_counter/embrace_gift
	name = "embrace"
	triumph_count = 2
	target_minimum = 3
	target_maximum = 5

/datum/objective/werewolf_counter/embrace_gift/get_progress()
	var/datum/antagonist/werewolf/lesser/wolfkin = get_werewolf_antag()
	if(!istype(wolfkin))
		return 0
	return wolfkin.times_shifted

/datum/objective/werewolf_counter/embrace_gift/update_explanation_text()
	..()
	explanation_text = "Embrace the moon's gift: take my moonkissed form [target_amount] time[werewolf_plural_suffix(target_amount)]. Progress: [get_progress()]/[target_amount]."

/datum/objective/werewolf/survive
	name = "survive"
	explanation_text = "Survive with the mooncurse."
/datum/objective/werewolf/survive/check_completion()
	return considered_alive(owner)
