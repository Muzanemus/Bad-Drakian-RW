// Adapted from Rivermist Hollow (AGPL-3.0), revision 8dba961e768e.
// https://github.com/sheetofseaweed/Rivermist-Hollow-Vanderlin/tree/8dba961e768ecf8b9cbbc7b8199372f6a9fead96/modular_rmh/code/modules/antagonists/contracts
/datum/contract_pool
	/// Typepaths of /datum/contract_goal templates
	var/list/goal_templates = list()
	var/cycle_length = 3 HOURS
	var/goals_per_contract_min = 2
	var/goals_per_contract_max = 4
	var/max_tier = 5
	/// Extra triumphs on a FULL-grade cycle (goal triumphs are paid live, separately)
	var/contract_bonus_triumphs = 3
	/// Highest patron favor a party can reach; 0 disables favor for this pool.
	var/max_favor = 0
	// Fiction skin
	var/patron_name = "the Patron"
	var/issue_text = "New demands are made of me..."
	var/success_text = "My patron is pleased. The bargain deepens."
	var/failure_text = "My patron's displeasure weighs on me."
	var/excused_text = "My absence has been overlooked... this time."

/// Instances, filters (tier ceiling, is_valid, exclusions), weighted-picks goals for one contract.
/// exclude_types: goal typepaths from the previous contract (anti-repeat).
/datum/contract_pool/proc/roll_goals(datum/antagonist/antag, tier_ceiling, list/exclude_types)
	var/list/candidates = list()
	for(var/goal_path in goal_templates)
		if(goal_path in exclude_types)
			continue
		var/datum/contract_goal/instance = new goal_path(antag)
		if(instance.tier > tier_ceiling || !instance.is_valid(antag))
			qdel(instance)
			continue
		candidates[instance] = instance.weight
	var/count = rand(goals_per_contract_min, goals_per_contract_max)
	var/list/chosen = list()
	while(length(candidates) && length(chosen) < count)
		var/datum/contract_goal/picked = pickweight(candidates)
		candidates -= picked
		chosen += picked
	for(var/datum/contract_goal/leftover as anything in candidates)
		qdel(leftover)
	return chosen
