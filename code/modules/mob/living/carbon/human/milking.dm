/mob/living/carbon/human/proc/try_milking(mob/living/user, obj/item/reagent_containers/glass/container)
	if(!ishuman(src) || stat == DEAD)
		return
	if(!get_location_accessible(src, BODY_ZONE_CHEST))
		return
	if(user != src && !client?.prefs?.milkable)//user can self milk, but they need the pref toggled to let others milk them
		return

	// Constructs cannot be milked
	if(construct)
		to_chat(user, span_warning("[src] cannot be milked!"))
		return

	var/obj/item/organ/breasts/B = has_breasts()
	if(!B)
		to_chat(user, span_warning("[src] cannot be milked!"))
		return
	if(!B.lactating)
		to_chat(user, span_warning("[src] does not seem to be producing milk."))
		return
	if(B.milk_stored < 1)
		to_chat(user, span_warning("[src] is out of milk!"))
		return

	if(container.reagents.total_volume >= container.reagents.maximum_volume)
		to_chat(user, span_warning("[container] is full."))
		return

	playsound(get_turf(src), pick('modular/Creechers/sound/milking1.ogg', 'modular/Creechers/sound/milking2.ogg'), 100, TRUE, -1)
	if(!do_after(user, 20, target = src))
		return
	if(QDELETED(src) || QDELETED(container) || stat == DEAD || !get_location_accessible(src, BODY_ZONE_CHEST))
		return
	if(user != src && !client?.prefs?.milkable)
		return

	// The stored milk and free space can change during the delay.
	if(QDELETED(B) || B != has_breasts() || !B.lactating)
		return
	if(B.milk_stored < 1)
		to_chat(user, span_warning("[src] is out of milk!"))
		return
	var/free_space = container.reagents.maximum_volume - container.reagents.total_volume
	if(free_space <= 0)
		to_chat(user, span_warning("[container] is full."))
		return

	var/milk_to_take = min(free_space, B.milk_stored, max(B.breast_size, 1))
	if(!container.reagents.add_reagent(/datum/reagent/consumable/milk, milk_to_take))
		return
	B.milk_stored -= milk_to_take
	user.visible_message(
		span_notice("[user] milks [(src == user) ? p_themselves() : src] into \the [container]."),
		span_notice("I milk [(src == user) ? "myself" : src] into \the [container].")
	)
	src?.sexcon?.adjust_arousal(2)
	try_milking(user, container)
