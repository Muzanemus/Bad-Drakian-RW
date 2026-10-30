// Adapted from Rivermist Hollow (AGPL-3.0), revision 8dba961e768e.
// https://github.com/sheetofseaweed/Rivermist-Hollow-Vanderlin/tree/8dba961e768ecf8b9cbbc7b8199372f6a9fead96/modular_rmh/code/modules/antagonists/contracts
// Contract framework compatibility surface. State is owned by contract_party;
// the fields remain synchronized for established antagonist code and tests.
/datum/antagonist
	var/contract_pool_type
	var/datum/contract_party/contract_party
	var/datum/contract_pool/contract_pool
	var/datum/antag_contract/current_contract
	var/list/datum/antag_contract/contract_history = list()
	var/contracts_completed_full = 0
	var/contract_created_at = 0

/// Shared roles override this to return their team's persistent party.
/datum/antagonist/proc/get_shared_contract_party()
	return null

/// Contract rewards and messages go to these minds. Team roles may widen it.
/datum/antagonist/proc/get_contract_minds()
	if(!owner)
		return list()
	return list(owner)

/datum/antagonist/proc/clear_contract_state_mirrors()
	contract_pool = null
	current_contract = null
	contract_history = list()
	contracts_completed_full = 0
	contract_created_at = 0

/datum/antagonist/proc/get_or_create_contract_party()
	if(contract_party)
		contract_party.sync_from_legacy(src)
		return contract_party
	var/datum/contract_party/shared_party = get_shared_contract_party()
	if(shared_party)
		shared_party.add_antag(src)
		return shared_party
	// Existing role code and unit tests may seed these compatibility fields before
	// invoking a framework proc. Build an empty party so add_antag() can import it.
	var/has_legacy_state = contract_pool || current_contract || length(contract_history) || contracts_completed_full || contract_created_at
	var/datum/contract_party/solo_party = new /datum/contract_party(has_legacy_state ? null : contract_pool_type)
	solo_party.add_antag(src)
	return solo_party

/datum/antagonist/proc/setup_contracts()
	if(!contract_pool_type || contract_party)
		return
	var/datum/contract_party/party = get_or_create_contract_party()
	if(owner?.current && !(/mob/living/proc/review_patron_contract in owner.current.verbs))
		owner.current.verbs |= /mob/living/proc/review_patron_contract
	if(!party.current_contract)
		party.issue_next_contract()

/datum/antagonist/proc/teardown_contracts()
	if(!contract_party)
		return
	var/has_other_contract = FALSE
	for(var/datum/antagonist/other_antag as anything in owner?.antag_datums)
		if(other_antag != src && other_antag.contract_party)
			has_other_contract = TRUE
			break
	if(!has_other_contract && owner?.current)
		owner.current.verbs -= /mob/living/proc/review_patron_contract
	var/datum/contract_party/old_party = contract_party
	old_party.remove_antag(src)

/datum/antagonist/proc/on_contract_mind_transfer(datum/mind/source, mob/living/old_body)
	SIGNAL_HANDLER
	if(old_body)
		old_body.verbs -= /mob/living/proc/review_patron_contract
	if(isliving(source.current) && !(/mob/living/proc/review_patron_contract in source.current.verbs))
		source.current.verbs |= /mob/living/proc/review_patron_contract

/datum/antagonist/proc/reanchor_contract_clock()
	var/datum/contract_party/party = get_or_create_contract_party()
	party.reanchor_contract_clock()

/datum/antagonist/proc/issue_next_contract()
	var/datum/contract_party/party = get_or_create_contract_party()
	party.issue_next_contract()

/datum/antagonist/proc/record_contract_progress(goal_type_path, amount = 1)
	var/datum/contract_party/party = get_or_create_contract_party()
	party.record_progress(goal_type_path, amount)

/datum/antagonist/proc/check_contract_early_completion()
	var/datum/contract_party/party = get_or_create_contract_party()
	party.check_early_completion()

/datum/antagonist/proc/close_contract_cycle(reanchor_clock = FALSE)
	var/datum/contract_party/party = get_or_create_contract_party()
	party.close_contract_cycle(reanchor_clock)

/datum/antagonist/proc/on_contract_completed(datum/antag_contract/contract)
	return

/datum/antagonist/proc/on_contract_failed(datum/antag_contract/contract)
	return

/datum/antagonist/proc/on_contract_cycle_closed(datum/antag_contract/contract)
	return

/// Called on every party member after the party's patron favor changes.
/datum/antagonist/proc/on_contract_favor_changed(old_favor, new_favor)
	return

/datum/antagonist/proc/notify_contract(text)
	var/datum/contract_party/party = get_or_create_contract_party()
	party.notify_members(text)

/datum/antagonist/proc/escalate_contract_omens(datum/antag_contract/contract)
	var/datum/contract_party/party = get_or_create_contract_party()
	party.escalate_contract_omens(contract)

/datum/antagonist/proc/contract_roundend_ledger()
	if(!contract_party && !contract_pool)
		return null
	var/datum/contract_party/party = get_or_create_contract_party()
	return party.roundend_ledger()
