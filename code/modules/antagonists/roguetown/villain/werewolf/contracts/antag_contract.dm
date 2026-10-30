// Adapted from Rivermist Hollow (AGPL-3.0), revision 8dba961e768e.
// https://github.com/sheetofseaweed/Rivermist-Hollow-Vanderlin/tree/8dba961e768ecf8b9cbbc7b8199372f6a9fead96/modular_rmh/code/modules/antagonists/contracts
/datum/antag_contract
	var/cycle_number = 1
	var/list/datum/contract_goal/goals = list()
	var/issued_at = 0
	var/deadline = 0
	/// One of CONTRACT_GRADE_*; null while the contract is live
	var/grade
	var/completed_early = FALSE
	/// The tier ceiling this contract was rolled at; scales storyteller escalation
	var/tier_ceiling = 1
	/// Accumulated by SScontracts while the owner has no client
	var/offline_deciseconds = 0

/datum/antag_contract/Destroy()
	QDEL_LIST(goals)
	return ..()

/datum/antag_contract/proc/all_goals_completed()
	if(!length(goals))
		return FALSE
	for(var/datum/contract_goal/goal as anything in goals)
		if(!goal.completed)
			return FALSE
	return TRUE

/datum/antag_contract/proc/compute_grade(cycle_length)
	if(!length(goals))
		return CONTRACT_GRADE_EXCUSED
	if(offline_deciseconds >= cycle_length * CONTRACT_EXCUSED_OFFLINE_FRACTION)
		return CONTRACT_GRADE_EXCUSED
	var/completed_count = 0
	for(var/datum/contract_goal/goal as anything in goals)
		if(goal.completed)
			completed_count++
	if(completed_count == length(goals))
		return CONTRACT_GRADE_FULL
	if(completed_count > 0)
		return CONTRACT_GRADE_PARTIAL
	return CONTRACT_GRADE_FAIL
