// Adapted from Rivermist Hollow (AGPL-3.0), revision 8dba961e768e.
// https://github.com/sheetofseaweed/Rivermist-Hollow-Vanderlin/tree/8dba961e768ecf8b9cbbc7b8199372f6a9fead96/modular_rmh/code/modules/antagonists/contracts
// Werewolf pilot: moon contracts. Campaign objectives (werewolf_counter/*) are
// untouched; contract goals feed from the same record procs (see feed-through
// calls in werewolf_objectives.dm).

/datum/antagonist/werewolf
	contract_pool_type = /datum/contract_pool/werewolf

// Moonkissed have no beast form, lair, or ledger — every moon-contract goal
// would be impossible for them, so the moon makes no bargains with them.
/datum/antagonist/werewolf/lesser
	contract_pool_type = null

/datum/contract_pool/werewolf
	patron_name = "the Moon"
	issue_text = "The moon whispers new demands of the hunt..."
	success_text = "The moon hunt is satisfied. The wild power in me deepens."
	failure_text = "The moon dims with disappointment."
	excused_text = "The moon passed while I slumbered. It forgives... this once."
	// Only 4 tier-1 templates (3 without breed): larger contracts + anti-repeat
	// would drain the ceiling-1 pool and force empty EXCUSED cycles
	goals_per_contract_max = 2
	goal_templates = list(
		/datum/contract_goal/werewolf/hunt_beasts,
		/datum/contract_goal/werewolf/slay_foe,
		/datum/contract_goal/werewolf/breed,
		/datum/contract_goal/werewolf/trap,
		/datum/contract_goal/werewolf/convert,
		/datum/contract_goal/werewolf/hunt_score,
	)

/datum/contract_goal/werewolf/hunt_beasts
	name = "moon hunt: beasts"
	description_template = "Hunt %TARGET% beast(s) while in wolf form."
	tier = 1
	weight = 12
	target_minimum = 1
	target_maximum = 3

/datum/contract_goal/werewolf/slay_foe
	name = "moon hunt: foes"
	description_template = "Slay %TARGET% foe while in wolf form."
	tier = 2
	weight = 8
	target_minimum = 1
	target_maximum = 1

/datum/contract_goal/werewolf/breed
	name = "moon seed"
	description_template = "In beast form, breed %TARGET% mortal."
	tier = 1
	weight = 10
	target_minimum = 1
	target_maximum = 1

/datum/contract_goal/werewolf/breed/is_valid(datum/antagonist/antag)
	return !isnull(antag.owner?.current?.getorganslot(ORGAN_SLOT_TESTICLES))

/datum/contract_goal/werewolf/trap
	name = "moon snare"
	description_template = "Ensnare %TARGET% mortal in my traps."
	tier = 1
	weight = 10
	target_minimum = 1
	target_maximum = 1

/datum/contract_goal/werewolf/convert
	name = "spread the curse"
	description_template = "Spread the mooncurse to %TARGET% mortal."
	tier = 2
	weight = 5
	target_minimum = 1
	target_maximum = 1

/datum/contract_goal/werewolf/convert/is_valid(datum/antagonist/antag)
	for(var/mob/living/carbon/human/candidate in GLOB.player_list)
		if(candidate == antag.owner?.current)
			continue
		// can_werewolf() doesn't check consciousness/client; conversion offers do
		if(candidate.stat != CONSCIOUS || !candidate.client)
			continue
		if(candidate.can_werewolf())
			return TRUE
	return FALSE

/datum/contract_goal/werewolf/hunt_score
	name = "the moon's tithe"
	description_template = "Gain %TARGET% moon-hunt score."
	tier = 1
	weight = 12
	target_minimum = 40
	target_maximum = 80
