/obj/effect/proc_holder/spell/invoked/track_rapebait
	name = "Track Rapebait"
	desc = "Cast on yourself to choose someone with the Rapebait quirk. Cast on them to pick up their trail directly, or cast elsewhere to check where your quarry is."
	recharge_time = 0.5 SECONDS
	chargetime = 0.1 SECONDS
	breaks_invisibility = FALSE
	overlay_icon = 'icons/mob/actions/gnollmiracles.dmi'
	action_icon = 'icons/mob/actions/gnollmiracles.dmi'
	overlay_state = "sniff"
	invocation_type = "none"
	action_icon_state = "sniff"
	hide_charge_effect = TRUE
	var/datum/weakref/tracked_target_ref
	var/list/target_warning_next_by_ref = list()
	var/last_selection

/obj/effect/proc_holder/spell/invoked/track_rapebait/cast(list/targets, mob/user)
	var/atom/target = targets[1]
	if(can_track_rapebait(target, user))
		return follow_rapebait(user, target)

	var/mob/living/tracked_target = tracked_target_ref?.resolve()
	if(!can_track_rapebait(tracked_target, user))
		tracked_target_ref = null

	if(target == user || !tracked_target_ref)
		return select_rapebait(user)

	report_quarry_directions(user, tracked_target)
	return TRUE

/obj/effect/proc_holder/spell/invoked/track_rapebait/proc/select_rapebait(mob/user)
	var/list/possible_targets = list()
	var/list/name_counts = list()
	for(var/mob/living/carbon/human/human in GLOB.player_list)
		if(!can_track_rapebait(human, user))
			continue
		var/base_name = human.real_name
		var/name_count = (name_counts[base_name] || 0) + 1
		name_counts[base_name] = name_count
		var/entry_name = name_count > 1 ? "[base_name] ([name_count])" : base_name
		var/class_title = human.get_class_title()
		if(length(class_title))
			entry_name += " - [class_title]"
		possible_targets[entry_name] = human

	if(!length(possible_targets))
		to_chat(user, span_warning("You can't find any rapebait trails."))
		return FALSE

	var/selection = tgui_input_list(user, "Whose trail will you follow?", name, possible_targets, last_selection)
	if(!selection || QDELETED(src) || QDELETED(user))
		return FALSE

	var/mob/living/carbon/human/selected_target = possible_targets[selection]
	if(!can_track_rapebait(selected_target, user))
		to_chat(user, span_warning("That trail has gone cold."))
		return FALSE

	last_selection = selection
	return follow_rapebait(user, selected_target)

/obj/effect/proc_holder/spell/invoked/track_rapebait/proc/can_track_rapebait(atom/target, mob/user)
	var/mob/living/carbon/human/human = target
	return istype(human) && human != user && !QDELETED(human) && human.stat != DEAD \
		&& !istype(human, /mob/living/carbon/human/dummy) && human.client && human.mind \
		&& !human.advsetup && human.class_equip_finished && HAS_TRAIT(human, TRAIT_RAPEBAIT) && get_turf(human)

/obj/effect/proc_holder/spell/invoked/track_rapebait/proc/follow_rapebait(mob/user, mob/living/target)
	tracked_target_ref = WEAKREF(target)
	to_chat(user, span_notice("You pick up the trail of [target.real_name]."))
	notify_tracked_target(target)
	report_quarry_directions(user, target)
	return TRUE

/obj/effect/proc_holder/spell/invoked/track_rapebait/proc/report_quarry_directions(mob/user, mob/living/target)
	var/turf/user_turf = get_turf(user)
	var/turf/target_turf = get_turf(target)
	if(!user_turf || !target_turf)
		to_chat(user, span_warning("You can't find a trail from here."))
		return

	if(user_turf.z != target_turf.z)
		var/vertical_direction = user_turf.z > target_turf.z ? "below" : "above"
		to_chat(user, span_notice("[target.real_name]'s trail leads [vertical_direction] you."))
		return

	var/distance = get_dist(user_turf, target_turf)
	var/direction = dir2text(get_dir(user_turf, target_turf))
	if(distance <= 1)
		to_chat(user, span_boldnotice("Your quarry is right here!"))
	else if(distance < 10)
		to_chat(user, span_notice("The trail leads [direction]. Your quarry is very close."))
	else
		to_chat(user, span_notice("You pick up a faint trail to the [direction]."))

/obj/effect/proc_holder/spell/invoked/track_rapebait/proc/notify_tracked_target(mob/living/target)
	var/target_ref = REF(target)
	var/next_warning_time = target_warning_next_by_ref[target_ref]
	if(!isnull(next_warning_time) && world.time < next_warning_time)
		return

	target_warning_next_by_ref[target_ref] = world.time + 10 MINUTES
	to_chat(target, span_warning("I feel the gaze of a hunter. Someone is tracking me!"))
