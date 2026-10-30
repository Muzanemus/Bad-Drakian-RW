// Adapted from Rivermist Hollow (AGPL-3.0), revision 8dba961e768e.
// https://github.com/sheetofseaweed/Rivermist-Hollow-Vanderlin/tree/8dba961e768ecf8b9cbbc7b8199372f6a9fead96/modular_rmh/code/modules/antagonists/contracts
/datum/contract_goal
	var/name = "generic demand"
	/// %TARGET% is replaced with target_amount in get_description()
	var/description_template = "Do the thing %TARGET% times."
	var/goal_type = CONTRACT_GOAL_COUNTER
	/// Weighted pool roll weight
	var/weight = 10
	/// Only rolls when the antag's tier ceiling is >= this
	var/tier = 1
	var/target_minimum = 1
	var/target_maximum = 1
	/// Rolled on instantiation
	var/target_amount = 1
	/// Triumphs paid immediately when this goal completes
	var/triumph_reward = 2
	var/completed = FALSE
	var/progress = 0
	/// The antagonist this instance was issued to
	var/datum/antagonist/antag

/datum/contract_goal/New(datum/antagonist/antag)
	..()
	src.antag = antag
	target_amount = rand(target_minimum, target_maximum)

/datum/contract_goal/Destroy()
	antag = null
	return ..()

/// Roll-time validity: override to check required organs, eligible population, prefs, etc.
/datum/contract_goal/proc/is_valid(datum/antagonist/antag)
	return TRUE

/// COUNTER goals only: external record calls add progress; completes live
/datum/contract_goal/proc/add_progress(amount = 1)
	if(completed || goal_type != CONTRACT_GOAL_COUNTER)
		return
	progress += amount
	if(progress >= target_amount)
		progress = target_amount
		complete()
	else
		antag?.contract_party?.notify_members("[antag.contract_pool.patron_name] takes note. ([get_description()])")

/// STATE goals override this to report their live condition; polled at cycle end
/datum/contract_goal/proc/get_state_progress()
	return 0

/// Evaluates STATE goals (COUNTER goals already know). Returns completed.
/datum/contract_goal/proc/evaluate()
	if(!completed && goal_type == CONTRACT_GOAL_STATE)
		progress = min(get_state_progress(), target_amount)
		if(progress >= target_amount)
			complete()
	return completed

/datum/contract_goal/proc/complete()
	if(completed)
		return
	completed = TRUE
	antag?.contract_party?.reward_members(triumph_reward, "contract goal: [name]")
	antag?.contract_party?.notify_members(span_greentext("Fulfilled: [get_description()]"))
	antag?.check_contract_early_completion()

/datum/contract_goal/proc/get_description()
	var/desc = replacetext(description_template, "%TARGET%", "[target_amount]")
	return "[desc] ([progress]/[target_amount])"
