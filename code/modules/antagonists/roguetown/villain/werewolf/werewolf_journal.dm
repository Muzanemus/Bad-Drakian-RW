// Rivermist Hollow moon-hunt journal and hidden writs, adapted for Bad Drakian's quest pool.
// AGPL-3.0, revision 8dba961e768e: modular_rmh/code/modules/antagonists/werewolf/werewolf_contract_*.dm.

/datum/antagonist/werewolf
	var/list/moon_writs = list()
	var/datum/weakref/tracked_writ_ref
	var/claiming_moon_quest = FALSE

/obj/effect/proc_holder/spell/self/moon_journal
	name = "Moon Hunt"
	desc = "Review the moon's demands, contracts, pack objectives and rage."
	overlay_state = "diagnose"
	clothes_req = FALSE
	human_req = FALSE
	antimagic_allowed = TRUE
	ignore_cockblock = TRUE
	recharge_time = 1 SECONDS

/obj/effect/proc_holder/spell/self/moon_journal/cast(list/targets, mob/living/user)
	var/datum/antagonist/werewolf/W = user.mind?.has_antag_datum(/datum/antagonist/werewolf)
	if(W)
		W.show_moon_journal(user)
	return TRUE

/mob/living/proc/review_patron_contract()
	set name = "Review Moon Contract"
	set category = "Moon Hunt"
	var/datum/antagonist/werewolf/W = mind?.has_antag_datum(/datum/antagonist/werewolf)
	W?.show_moon_journal(src)

/datum/antagonist/werewolf/proc/show_moon_journal(mob/user)
	if(owner?.current != user || !user.client)
		return
	var/list/html = list("<h2>Moon Hunt</h2><p>Rage: [round(rage, 0.1)] / 150</p>")
	if(contract_party)
		var/list/demands = contract_party.get_demand_lines()
		html += demands.Join("<br>")
	html += "<h3>Pack objectives</h3>"
	refresh_werewolf_objectives()
	for(var/datum/objective/objective as anything in objectives)
		html += "<p>[objective.explanation_text]</p>"
	html += "<h3>Hunt contracts</h3>"
	for(var/obj/item/quest_writ/werewolf_hidden/writ as anything in moon_writs.Copy())
		if(QDELETED(writ) || !writ.assigned_quest)
			moon_writs -= writ
			continue
		var/datum/quest/Q = writ.assigned_quest
		html += "<p>[html_encode(Q.title)] — [Q.progress_current]/[Q.progress_required][Q.complete ? " (complete)" : ""] <a href='?src=[REF(src)];track=[REF(writ)]'>Track scent</a></p>"
	html += "<p><a href='?src=[REF(src)];sniff=1'>Sniff trail</a> | <a href='?src=[REF(src)];sniff_den=1'>Sniff den</a></p>"
	var/datum/browser/popup = new(user, "werewolf_moon_hunt", "Moon Hunt", 720, 600)
	popup.set_content(html.Join(""))
	popup.open()

/datum/antagonist/werewolf/Topic(href, list/href_list)
	if(usr != owner?.current || !usr.client || usr.incapacitated())
		return
	if(href_list["track"])
		var/obj/item/quest_writ/werewolf_hidden/writ = locate(href_list["track"]) in moon_writs
		if(writ && !QDELETED(writ) && writ.assigned_quest)
			tracked_writ_ref = WEAKREF(writ)
	if(href_list["sniff"])
		sniff_moon_contract(usr)
	if(href_list["sniff_den"])
		sniff_lair(usr)
	show_moon_journal(usr)

/datum/antagonist/werewolf/proc/sync_moon_writs(mob/new_body)
	for(var/obj/item/quest_writ/werewolf_hidden/writ as anything in moon_writs)
		if(writ.assigned_quest)
			writ.assigned_quest.quest_receiver_reference = WEAKREF(new_body)
			writ.assigned_quest.quest_receiver_name = new_body.real_name

/datum/antagonist/werewolf/proc/sniff_moon_contract(mob/user)
	var/obj/item/quest_writ/werewolf_hidden/writ = tracked_writ_ref?.resolve()
	if(!writ || !(writ in moon_writs) || !writ.assigned_quest)
		to_chat(user, span_notice("I have no contract scent to follow."))
		return
	for(var/datum/weakref/ref as anything in writ.assigned_quest.tracked_atoms)
		var/atom/target = ref.resolve()
		if(!target)
			continue
		if(target.z != user.z)
			to_chat(user, span_notice("The scent leads beyond this land, toward [get_area(target)]."))
		else
			to_chat(user, span_notice("The trail leads [dir2text(get_dir(user, target))], [get_dist(user, target)] paces away."))
		return
	to_chat(user, span_notice("The trail has gone cold."))

/obj/item/quest_writ/werewolf_hidden
	name = "moon-hunt instinct"
	icon = null
	item_flags = ABSTRACT
	var/datum/weakref/curse_ref

/obj/item/quest_writ/werewolf_hidden/Destroy()
	var/datum/antagonist/werewolf/W = curse_ref?.resolve()
	W?.moon_writs -= src
	return ..()

/obj/structure/werewolf_moon_ledger
	name = "moon-hunt ledger"
	desc = "Hidden demands of the hunt, legible only to the pack."
	icon = 'code/modules/roguetown/roguemachine/questing/questing.dmi'
	icon_state = "contractledger"
	anchored = TRUE
	var/datum/weakref/lair_ref

/obj/structure/werewolf_moon_ledger/proc/authorized(mob/living/user)
	var/datum/antagonist/werewolf/W = user?.mind?.has_antag_datum(/datum/antagonist/werewolf)
	var/obj/structure/werewolf_lair/L = lair_ref?.resolve()
	return W && !W.is_moonkissed && L?.can_use(user) && user.Adjacent(src) && !user.incapacitated()

/obj/structure/werewolf_moon_ledger/proc/is_hunt_contract(datum/quest/Q)
	return Q && Q.source == QUEST_SOURCE_POOL && (Q.quest_type in list(QUEST_KILL_EASY, QUEST_CLEAR_OUT, QUEST_RAID))

/obj/structure/werewolf_moon_ledger/attack_hand(mob/living/user)
	if(!authorized(user))
		return
	var/datum/antagonist/werewolf/W = user.mind.has_antag_datum(/datum/antagonist/werewolf)
	var/list/html = list("<h2>Moon-hunt contracts</h2><p>These contracts award hunt score instead of coin. No deposit is required.</p>")
	for(var/datum/quest/Q as anything in SSquestpool.pool)
		if(!is_hunt_contract(Q))
			continue
		html += "<p>[html_encode(Q.title)] ([html_encode(Q.quest_difficulty)]) <a href='?src=[REF(src)];claim=[REF(Q)]'>Accept</a></p>"
	for(var/obj/item/quest_writ/werewolf_hidden/writ as anything in W.moon_writs)
		var/datum/quest/Q = writ.assigned_quest
		if(Q?.complete)
			html += "<p>[html_encode(Q.title)] <a href='?src=[REF(src)];turn_in=[REF(writ)]'>Complete</a></p>"
		else if(Q)
			html += "<p>[html_encode(Q.title)] <a href='?src=[REF(src)];abandon=[REF(writ)]'>Abandon</a></p>"
	var/datum/browser/popup = new(user, "werewolf_moon_ledger", "Moon-hunt ledger", 720, 600)
	popup.set_content(html.Join(""))
	popup.open()

/obj/structure/werewolf_moon_ledger/Topic(href, list/href_list)
	var/mob/living/user = usr
	if(!authorized(user))
		return
	var/datum/antagonist/werewolf/W = user.mind.has_antag_datum(/datum/antagonist/werewolf)
	if(href_list["claim"])
		var/datum/quest/Q = locate(href_list["claim"]) in SSquestpool.pool
		if(!is_hunt_contract(Q) || W.claiming_moon_quest || length(W.moon_writs) >= 3 || !Q.can_claim(user))
			return
		W.claiming_moon_quest = TRUE
		var/claimed = SSquestpool.claim(Q, user)
		if(QDELETED(W))
			if(claimed && !QDELETED(Q))
				qdel(Q)
			return
		W.claiming_moon_quest = FALSE
		if(!claimed)
			return
		if(!authorized(user) || W.owner?.current != user)
			qdel(Q)
			return
		var/obj/item/quest_writ/werewolf_hidden/writ = new(null)
		writ.curse_ref = WEAKREF(W)
		writ.assigned_quest = Q
		Q.quest_scroll = writ
		Q.quest_scroll_ref = WEAKREF(writ)
		W.moon_writs += writ
		W.tracked_writ_ref = WEAKREF(writ)
		W.sync_moon_writs(W.owner.current)
	if(href_list["turn_in"] || href_list["abandon"])
		var/obj/item/quest_writ/werewolf_hidden/writ = locate(href_list["turn_in"] || href_list["abandon"]) in W.moon_writs
		var/datum/quest/Q = writ?.assigned_quest
		if(!Q)
			return
		if(href_list["turn_in"])
			if(!Q.complete)
				return
			var/score = 5
			switch(lowertext(Q.quest_difficulty))
				if("medium")
					score = 15
				if("hard")
					score = 25
			W.add_contract_objective_score(score)
		qdel(Q)
		qdel(writ)
	attack_hand(user)
