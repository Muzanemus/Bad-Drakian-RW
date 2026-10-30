// Adapted from Rivermist Hollow (AGPL-3.0), revision 8dba961e768e.
// https://github.com/sheetofseaweed/Rivermist-Hollow-Vanderlin/tree/8dba961e768ecf8b9cbbc7b8199372f6a9fead96/modular_rmh/code/modules/antagonists/contracts
/datum/contract_party
	/// Antagonists participating in this contract schedule.
	var/list/datum/antagonist/antags = list()
	/// Shared parties survive individual antagonist removal; solo parties do not.
	var/shared = FALSE
	var/datum/contract_pool/contract_pool
	var/datum/antag_contract/current_contract
	var/list/datum/antag_contract/contract_history = list()
	var/contracts_completed_full = 0
	/// Patron favor: FULL cycles raise it, failed ones lower it, capped by the pool's max_favor.
	var/favor = 0
	var/contract_created_at = 0

/datum/contract_party/New(contract_pool_type, shared = FALSE)
	. = ..()
	src.shared = shared
	if(contract_pool_type)
		contract_pool = new contract_pool_type
	contract_created_at = world.time

/datum/contract_party/Destroy()
	SScontracts?.deregister(src)
	for(var/datum/antagonist/antag as anything in antags)
		if(antag.contract_party == src)
			antag.contract_party = null
			antag.clear_contract_state_mirrors()
	antags = null
	QDEL_NULL(current_contract)
	QDEL_LIST(contract_history)
	QDEL_NULL(contract_pool)
	return ..()

/datum/contract_party/proc/add_antag(datum/antagonist/antag)
	if(!antag || (antag in antags))
		return
	antags += antag
	antag.contract_party = src
	if(length(antags) == 1)
		if(current_contract)
			for(var/datum/contract_goal/goal as anything in current_contract.goals)
				goal.antag = antag
		for(var/datum/antag_contract/contract as anything in contract_history)
			for(var/datum/contract_goal/goal as anything in contract.goals)
				goal.antag = antag
	if(length(antags) == 1 && !contract_pool && antag.contract_pool)
		sync_from_legacy(antag)
	sync_to_antags()
	if(contract_pool)
		SScontracts.register(src)

/datum/contract_party/proc/remove_antag(datum/antagonist/antag)
	if(!(antag in antags))
		return
	antags -= antag
	if(antag.contract_party == src)
		antag.contract_party = null
		antag.clear_contract_state_mirrors()
	if(!length(antags))
		if(current_contract)
			for(var/datum/contract_goal/goal as anything in current_contract.goals)
				goal.antag = null
		for(var/datum/antag_contract/contract as anything in contract_history)
			for(var/datum/contract_goal/goal as anything in contract.goals)
				goal.antag = null
		SScontracts.deregister(src)
		if(!shared)
			qdel(src)
		return
	var/datum/antagonist/primary_antag = antags[1]
	if(current_contract)
		for(var/datum/contract_goal/goal as anything in current_contract.goals)
			goal.antag = primary_antag
	for(var/datum/antag_contract/contract as anything in contract_history)
		for(var/datum/contract_goal/goal as anything in contract.goals)
			goal.antag = primary_antag
	sync_to_antags()

/// Imports direct legacy field changes made by existing solo-role code and tests.
/datum/contract_party/proc/sync_from_legacy(datum/antagonist/antag)
	if(shared || length(antags) > 1 || antag.contract_party != src)
		return
	contract_pool = antag.contract_pool
	current_contract = antag.current_contract
	contract_history = antag.contract_history
	contracts_completed_full = antag.contracts_completed_full
	contract_created_at = antag.contract_created_at

/// Maintains the antagonist fields as read-compatible mirrors for existing roles.
/datum/contract_party/proc/sync_to_antags()
	for(var/datum/antagonist/antag as anything in antags)
		antag.contract_pool = contract_pool
		antag.current_contract = current_contract
		antag.contract_history = contract_history
		antag.contracts_completed_full = contracts_completed_full
		antag.contract_created_at = contract_created_at

/datum/contract_party/proc/get_primary_antag()
	if(!length(antags))
		return null
	return antags[1]

/datum/contract_party/proc/has_online_member()
	for(var/datum/antagonist/antag as anything in antags)
		if(antag.owner?.current?.client)
			return TRUE
	return FALSE

/datum/contract_party/proc/notify_members(text)
	if(!text)
		return
	var/list/notified_minds = list()
	for(var/datum/antagonist/antag as anything in antags)
		for(var/datum/mind/member as anything in antag.get_contract_minds())
			if((member in notified_minds) || !member.current)
				continue
			notified_minds += member
			to_chat(member.current, span_notice(text))

/datum/contract_party/proc/reward_members(amount, reason)
	var/list/rewarded_minds = list()
	for(var/datum/antagonist/antag as anything in antags)
		for(var/datum/mind/member as anything in antag.get_contract_minds())
			if(member in rewarded_minds)
				continue
			rewarded_minds += member
			member.current?.adjust_triumphs(amount, TRUE, reason)

/datum/contract_party/proc/reanchor_contract_clock()
	contract_created_at = world.time
	if(contract_pool)
		contract_created_at -= length(contract_history) * contract_pool.cycle_length
	sync_to_antags()

/datum/contract_party/proc/issue_next_contract()
	if(!contract_pool || !length(antags))
		return
	var/cycle = length(contract_history) + 1
	var/tier_ceiling = 1 + contracts_completed_full
	var/datum/antag_contract/previous = length(contract_history) ? contract_history[length(contract_history)] : null
	if(previous?.completed_early)
		tier_ceiling++
	tier_ceiling = min(tier_ceiling, contract_pool.max_tier)

	var/list/exclude = list()
	if(previous)
		for(var/datum/contract_goal/goal as anything in previous.goals)
			exclude += goal.type

	var/datum/antag_contract/contract = new
	contract.cycle_number = cycle
	contract.issued_at = world.time
	contract.tier_ceiling = tier_ceiling
	// Fixed clock: boundaries remain anchored to contract_created_at.
	var/next_deadline = contract_created_at + cycle * contract_pool.cycle_length
	while(next_deadline <= world.time)
		next_deadline += contract_pool.cycle_length
	contract.deadline = next_deadline
	contract.goals = contract_pool.roll_goals(get_primary_antag(), tier_ceiling, exclude)
	current_contract = contract
	sync_to_antags()

	if(length(contract.goals))
		notify_members("<b>[contract_pool.issue_text]</b>")
		for(var/datum/contract_goal/goal as anything in contract.goals)
			notify_members("- [goal.get_description()]")

/datum/contract_party/proc/record_progress(goal_type_path, amount = 1)
	if(!current_contract)
		return
	for(var/datum/contract_goal/goal as anything in current_contract.goals)
		if(istype(goal, goal_type_path))
			goal.add_progress(amount)

/datum/contract_party/proc/check_early_completion()
	var/datum/antag_contract/contract = current_contract
	if(!contract || contract.completed_early || world.time >= contract.deadline)
		return
	for(var/datum/contract_goal/goal as anything in contract.goals)
		if(!goal.completed && goal.goal_type == CONTRACT_GOAL_STATE)
			goal.evaluate()
	if(!contract.all_goals_completed() || contract.completed_early)
		return
	contract.completed_early = TRUE
	notify_members("<b>[contract_pool.patron_name]'s demands are fulfilled early. Its appetite grows...</b>")

/datum/contract_party/proc/close_contract_cycle(reanchor_clock = FALSE)
	var/datum/antag_contract/contract = current_contract
	if(!contract)
		return
	for(var/datum/contract_goal/goal as anything in contract.goals)
		goal.evaluate()
	contract.grade = contract.compute_grade(contract_pool.cycle_length)
	switch(contract.grade)
		if(CONTRACT_GRADE_FULL)
			contracts_completed_full++
			sync_to_antags()
			reward_members(contract_pool.contract_bonus_triumphs, "contract cycle [contract.cycle_number] fulfilled")
			escalate_contract_omens(contract)
			for(var/datum/antagonist/antag as anything in antags.Copy())
				antag.on_contract_completed(contract)
			notify_members(contract_pool.success_text)
			adjust_favor(1)
		if(CONTRACT_GRADE_FAIL)
			for(var/datum/antagonist/antag as anything in antags.Copy())
				antag.on_contract_failed(contract)
			notify_members(contract_pool.failure_text)
			adjust_favor(-1)
		if(CONTRACT_GRADE_EXCUSED)
			notify_members(contract_pool.excused_text)
	for(var/datum/antagonist/antag as anything in antags.Copy())
		antag.on_contract_cycle_closed(contract)
	contract_history += contract
	current_contract = null
	if(reanchor_clock)
		reanchor_contract_clock()
	else
		sync_to_antags()
	issue_next_contract()

/// The current demands as chat-ready lines, shared by Review Contract, Memories and antag stations.
/datum/contract_party/proc/get_demand_lines()
	var/list/lines = list()
	var/datum/antag_contract/contract = current_contract
	if(!contract)
		lines += "[contract_pool.patron_name] has no demands right now."
	else
		var/minutes_left = max(0, round((contract.deadline - world.time) / (1 MINUTES)))
		lines += "<b>[contract_pool.patron_name]'s demands</b> ([minutes_left] min remain):"
		for(var/datum/contract_goal/goal as anything in contract.goals)
			lines += "- [goal.get_description()][goal.completed ? " (done)" : ""]"
	if(contract_pool.max_favor)
		lines += "Favor of [contract_pool.patron_name]: [favor]/[contract_pool.max_favor]"
	return lines

/datum/contract_party/proc/adjust_favor(amount)
	var/old_favor = favor
	favor = clamp(favor + amount, 0, contract_pool?.max_favor || 0)
	if(favor == old_favor)
		return
	for(var/datum/antagonist/antag as anything in antags.Copy())
		antag.on_contract_favor_changed(old_favor, favor)

/datum/contract_party/proc/escalate_contract_omens(datum/antag_contract/contract)
	var/omen_points = SSgamemode.point_thresholds[EVENT_TRACK_OMENS] * CONTRACT_OMEN_ESCALATION_FRACTION * contract.tier_ceiling
	SSgamemode.event_track_points[EVENT_TRACK_OMENS] += omen_points
	var/intervention_points = SSgamemode.point_thresholds[EVENT_TRACK_INTERVENTION] * CONTRACT_INTERVENTION_ESCALATION_FRACTION * contract.tier_ceiling
	SSgamemode.event_track_points[EVENT_TRACK_INTERVENTION] += intervention_points

/datum/contract_party/proc/roundend_ledger()
	if(!contract_pool)
		return null
	var/list/lines = list("<b>Contracts of [contract_pool.patron_name]:</b>")
	var/list/all_contracts = contract_history.Copy()
	if(current_contract)
		all_contracts += current_contract
	for(var/datum/antag_contract/contract as anything in all_contracts)
		var/list/goal_bits = list()
		for(var/datum/contract_goal/goal as anything in contract.goals)
			goal_bits += "[goal.get_description()][goal.completed ? " (done)" : ""]"
		lines += "Cycle [contract.cycle_number] — [contract.grade || "in progress"]: [goal_bits.Join("; ")]"
	return lines.Join("<br>")
