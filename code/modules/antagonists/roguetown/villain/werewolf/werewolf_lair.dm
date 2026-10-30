// Adapted from Rivermist Hollow's werewolf lair and trap (AGPL-3.0), revision 8dba961e768e.
// Uses Bad Drakian's existing turf reservations instead of Rivermist's global pocket subsystem.
// https://github.com/sheetofseaweed/Rivermist-Hollow-Vanderlin/tree/8dba961e768ecf8b9cbbc7b8199372f6a9fead96/modular_rmh/code/modules/antagonists/werewolf

/datum/antagonist/werewolf
	var/lair_created = FALSE
	var/datum/weakref/lair_ref

/mob/living
	var/datum/weakref/werewolf_pit_ref

/datum/antagonist/werewolf/proc/cleanup_lair()
	var/obj/structure/werewolf_lair/lair = lair_ref?.resolve()
	lair_ref = null
	if(lair)
		if(lair.loading_rooms)
			lair.closing = TRUE
		else
			qdel(lair)

/datum/antagonist/werewolf/proc/sniff_lair(mob/user)
	var/obj/structure/werewolf_lair/lair = lair_ref?.resolve()
	if(!lair)
		return
	if(user.z != lair.z)
		to_chat(user, span_notice("My den's entrance lies beyond this land."))
	else
		to_chat(user, span_notice("My den is [get_dist(user, lair)] paces to the [dir2text(get_dir(user, lair))]."))

/proc/is_werewolf_lair_wall(turf/T)
	return istype(T, /turf/closed/mineral/rogue) || T?.type == /turf/closed/wall/mineral/rogue/stone

/obj/effect/proc_holder/spell/invoked/werewolf/dig_lair
	name = "Dig Lair"
	desc = "Dig a hidden den into a natural cave wall. This can be done only once."
	overlay_state = "shapeshifted"
	range = 1
	recharge_time = 5 SECONDS

/obj/effect/proc_holder/spell/invoked/werewolf/dig_lair/cast(list/targets, mob/living/carbon/human/user)
	var/datum/antagonist/werewolf/W = user.mind?.has_antag_datum(/datum/antagonist/werewolf)
	var/turf/wall = get_turf(targets[1])
	if(!W?.transformed || W.lair_created || W.lair_ref?.resolve() || !isturf(user.loc) || !user.Adjacent(wall) || !is_werewolf_lair_wall(wall) || !(get_dir(user, wall) in GLOB.cardinals))
		revert_cast(user)
		return FALSE
	if(!do_after(user, 8 SECONDS, target = wall))
		return FALSE
	if(QDELETED(W) || W.owner?.current != user || !W.transformed || W.lair_created || !user.Adjacent(wall) || !is_werewolf_lair_wall(wall) || !(get_dir(user, wall) in GLOB.cardinals))
		return FALSE
	var/obj/structure/werewolf_lair/lair = new(get_turf(user), W)
	if(!lair.create_rooms())
		qdel(lair)
		to_chat(user, span_warning("The lair caves in before it can settle."))
		return FALSE
	if(QDELETED(lair) || QDELETED(W) || W.owner?.current != user || !W.transformed)
		if(!QDELETED(lair))
			qdel(lair)
		return FALSE
	lair.setDir(get_dir(user, wall))
	W.lair_created = TRUE
	W.lair_ref = WEAKREF(lair)
	return TRUE

/area/werewolf_den
	parent_type = /area/rogue/under
	unique = FALSE
	name = "Moon Lair"
	noteleport = TRUE

/datum/map_template/werewolf_lair
	name = "Werewolf Lair"
	id = "werewolf_lair"
	mappath = "_maps/templates/werewolf_lair.dmm"

/datum/map_template/werewolf_pit
	name = "Moon Pit"
	id = "werewolf_pit"
	mappath = "_maps/templates/werewolf_pit.dmm"

/obj/effect/landmark/werewolf_entry
	name = "werewolf entry"
/obj/effect/landmark/werewolf_exit
	name = "werewolf exit"

/obj/structure/werewolf_lair
	name = "clawed-out lair"
	desc = "A burrow mouth against the cave wall, smelling of damp earth and wet fur."
	icon = 'icons/turf/roguefloor.dmi'
	icon_state = "hole1"
	anchored = TRUE
	density = FALSE
	var/datum/weakref/curse_ref
	var/datum/turf_reservation/den
	var/datum/turf_reservation/pit
	var/turf/den_entry
	var/turf/pit_entry
	var/list/invited_minds = list()
	var/list/captives = list()
	var/list/captive_events = list()
	var/pit_ready_at = 0
	var/closing = FALSE
	var/loading_rooms = FALSE

/obj/structure/werewolf_lair/Initialize(mapload, datum/antagonist/werewolf/curse)
	. = ..()
	if(!curse)
		return INITIALIZE_HINT_QDEL
	curse_ref = WEAKREF(curse)
	curse.lair_ref = WEAKREF(src)
	START_PROCESSING(SSobj, src)

/obj/structure/werewolf_lair/proc/create_rooms()
	loading_rooms = TRUE
	var/success = load_rooms()
	loading_rooms = FALSE
	return success && !closing && !QDELETED(src)

/obj/structure/werewolf_lair/proc/load_rooms()
	var/datum/map_template/template = SSmapping.map_templates["werewolf_lair"]
	var/datum/map_template/pit_template = SSmapping.map_templates["werewolf_pit"]
	if(!template || !pit_template)
		return FALSE
	den = SSmapping.RequestBlockReservation(template.width, template.height)
	if(closing || QDELETED(src))
		return FALSE
	pit = SSmapping.RequestBlockReservation(pit_template.width, pit_template.height)
	if(closing || QDELETED(src) || !den || !pit)
		return FALSE
	if(!template.load(locate(den.bottom_left_coords[1], den.bottom_left_coords[2], den.bottom_left_coords[3])))
		return FALSE
	if(closing || QDELETED(src))
		return FALSE
	if(!pit_template.load(locate(pit.bottom_left_coords[1], pit.bottom_left_coords[2], pit.bottom_left_coords[3])))
		return FALSE
	if(closing || QDELETED(src))
		return FALSE
	configure_room(den, FALSE)
	configure_room(pit, TRUE)
	return den_entry && pit_entry

/obj/structure/werewolf_lair/proc/room_turfs(datum/turf_reservation/room)
	if(!room)
		return list()
	return block(locate(room.bottom_left_coords[1], room.bottom_left_coords[2], room.bottom_left_coords[3]), locate(room.top_right_coords[1], room.top_right_coords[2], room.top_right_coords[3]))

/obj/structure/werewolf_lair/proc/configure_room(datum/turf_reservation/room, is_pit)
	// Native template loading initializes contents, but not newly created areas.
	var/list/area/new_areas = list()
	for(var/turf/T as anything in room_turfs(room))
		var/area/A = get_area(T)
		if(!(A.flags_1 & INITIALIZED_1))
			new_areas |= A
	SSatoms.InitializeAtoms(new_areas)
	for(var/turf/T as anything in room_turfs(room))
		for(var/obj/effect/landmark/werewolf_entry/entry in T)
			if(is_pit)
				pit_entry = T
			else
				den_entry = T
			qdel(entry)
		for(var/obj/effect/landmark/werewolf_exit/exit in T)
			if(T.density)
				T = T.ChangeTurf(/turf/open/floor/rogue/naturalstone)
			var/obj/structure/werewolf_den_exit/E = new(T)
			E.lair_ref = WEAKREF(src)
			E.is_pit = is_pit
			qdel(exit)
		for(var/obj/structure/werewolf_moon_pit/P in T)
			P.lair_ref = WEAKREF(src)
		for(var/obj/structure/werewolf_moon_ledger/L in T)
			L.lair_ref = WEAKREF(src)

/obj/structure/werewolf_lair/proc/can_use(mob/living/user)
	var/datum/antagonist/werewolf/W = curse_ref?.resolve()
	return W && user?.mind && (user.mind == W.owner || ((user.mind in invited_minds) && user.mind.has_antag_datum(/datum/antagonist/werewolf)))

/obj/structure/werewolf_lair/proc/can_enter(mob/living/user)
	if(can_use(user))
		return TRUE
	if(ishuman(user))
		var/mob/living/carbon/human/H = user
		if(istype(H.wear_neck, /obj/item/clothing/neck/roguetown/moonshackle))
			return TRUE
		for(var/obj/item/I as anything in H.held_items)
			if(istype(I, /obj/item/clothing/neck/roguetown/moonshackle))
				return TRUE
	return FALSE

/obj/structure/werewolf_lair/attack_hand(mob/living/user)
	if(!user.Adjacent(src) || user.incapacitated() || !can_enter(user))
		to_chat(user, span_warning("I need the den owner's invitation or a moonshackle collar to enter."))
		return
	user.forceMove(den_entry)

/obj/structure/werewolf_lair/attackby(obj/item/item, mob/living/user)
	if(istype(item, /obj/item/grabbing) && user.Adjacent(src) && can_use(user) && !user.incapacitated())
		var/obj/item/grabbing/grab = item
		var/mob/living/victim = grab.grabbed
		if(istype(victim) && user.Adjacent(victim))
			user.stop_pulling()
			victim.forceMove(den_entry)
			log_combat(user, victim, "moved into werewolf lair")
			qdel(grab)
		return
	return ..()

/obj/structure/werewolf_lair/attack_right(mob/living/user)
	var/datum/antagonist/werewolf/W = curse_ref?.resolve()
	if(!W || user.mind != W.owner || !user.Adjacent(src) || user.incapacitated())
		return
	var/list/options = list()
	for(var/mob/living/candidate in view(7, user))
		if(candidate != user && candidate.mind?.has_antag_datum(/datum/antagonist/werewolf))
			options[candidate.real_name] = candidate.mind
	var/choice = input(user, "Invite or revoke a nearby pack member.", "Moon Lair") as null|anything in options
	if(!choice || QDELETED(src) || QDELETED(user) || !user.Adjacent(src) || QDELETED(W) || user.mind != W.owner)
		return
	var/datum/mind/invited = options[choice]
	if(invited in invited_minds)
		invited_minds -= invited
	else
		invited_minds |= invited
	to_chat(user, span_notice("The invitation has been updated."))

/obj/structure/werewolf_lair/proc/capture(mob/living/user, mob/living/victim)
	if(world.time < pit_ready_at || !can_use(user) || user.incapacitated() || !user.Adjacent(victim) || victim == user || QDELETED(victim))
		return FALSE
	var/datum/antagonist/werewolf/W = curse_ref?.resolve()
	if(!W)
		return FALSE
	user.stop_pulling()
	victim.forceMove(pit_entry)
	victim.werewolf_pit_ref = WEAKREF(src)
	captives[WEAKREF(victim)] = world.time + 10 MINUTES
	pit_ready_at = world.time + 2 MINUTES
	log_combat(user, victim, "placed in werewolf moon pit")
	return TRUE

/obj/structure/werewolf_lair/proc/in_pit(atom/target)
	var/turf/T = get_turf(target)
	return pit && T && T.z == pit.bottom_left_coords[3] && T.x >= pit.bottom_left_coords[1] && T.x <= pit.top_right_coords[1] && T.y >= pit.bottom_left_coords[2] && T.y <= pit.top_right_coords[2]

/obj/structure/werewolf_lair/proc/captive_body(datum/weakref/ref)
	var/mob/living/body = ref.resolve()
	while(isliving(body?.loc))
		body = body.loc
	return body

/obj/structure/werewolf_lair/proc/record_captive_event(mob/living/body)
	for(var/datum/weakref/ref as anything in captives)
		if(captive_body(ref) == body)
			captive_events[ref]++
			return

/obj/structure/werewolf_lair/process()
	if(!curse_ref?.resolve())
		qdel(src)
		return
	for(var/datum/weakref/ref as anything in captives.Copy())
		var/mob/living/victim = captive_body(ref)
		if(QDELETED(victim) || !in_pit(victim))
			if(victim?.werewolf_pit_ref?.resolve() == src)
				victim.werewolf_pit_ref = null
			var/mob/living/original = ref.resolve()
			if(original)
				original.werewolf_pit_ref = null
			captives -= ref
			captive_events -= ref
			continue
		victim.werewolf_pit_ref = WEAKREF(src)
		if(world.time >= captives[ref] || victim.health <= victim.crit_threshold || victim.stat == DEAD || captive_events[ref] >= 10)
			victim.forceMove(den_entry)
			victim.werewolf_pit_ref = null
			var/mob/living/original = ref.resolve()
			if(original)
				original.werewolf_pit_ref = null
			captives -= ref
			captive_events -= ref

/obj/structure/werewolf_lair/Destroy()
	closing = TRUE
	var/datum/antagonist/werewolf/W = curse_ref?.resolve()
	if(W && IS_WEAKREF_OF(src, W.lair_ref))
		W.lair_ref = null
	STOP_PROCESSING(SSobj, src)
	var/turf/outside = get_turf(src)
	for(var/datum/turf_reservation/room in list(den, pit))
		if(!room)
			continue
		for(var/turf/T as anything in room_turfs(room))
			for(var/atom/movable/M in T)
				if(!M.anchored || ismob(M))
					if(isliving(M))
						var/mob/living/living = M
						living.werewolf_pit_ref = null
					M.forceMove(outside)
		qdel(room)
	den = null
	pit = null
	den_entry = null
	pit_entry = null
	captives.Cut()
	captive_events.Cut()
	return ..()

/obj/structure/werewolf_den_exit
	name = "way out"
	icon = 'icons/turf/roguefloor.dmi'
	icon_state = "hole1"
	anchored = TRUE
	var/datum/weakref/lair_ref
	var/is_pit = FALSE

/obj/structure/werewolf_den_exit/attack_hand(mob/living/user)
	var/obj/structure/werewolf_lair/L = lair_ref?.resolve()
	if(!L || !user.Adjacent(src) || user.incapacitated())
		return
	if(is_pit && !L.can_use(user))
		to_chat(user, span_warning("The moon pit holds me until its grip loosens or the den's owner releases me."))
		return
	user.forceMove(is_pit ? L.den_entry : get_turf(L))

/obj/structure/werewolf_den_exit/attackby(obj/item/item, mob/living/user)
	var/obj/structure/werewolf_lair/L = lair_ref?.resolve()
	if(!L || !L.can_use(user) || !user.Adjacent(src) || user.incapacitated())
		return
	if(istype(item, /obj/item/grabbing))
		var/obj/item/grabbing/grab = item
		var/mob/living/victim = grab.grabbed
		if(istype(victim) && user.Adjacent(victim))
			user.stop_pulling()
			victim.forceMove(is_pit ? L.den_entry : get_turf(L))
			qdel(grab)
		return
	return ..()

/obj/structure/werewolf_moon_pit
	name = "moon pit"
	desc = "A deeper sinkhole beneath the den."
	icon = 'icons/turf/roguefloor.dmi'
	icon_state = "hole1"
	anchored = TRUE
	var/datum/weakref/lair_ref

/obj/structure/werewolf_moon_pit/attackby(obj/item/item, mob/living/user)
	var/obj/structure/werewolf_lair/L = lair_ref?.resolve()
	if(istype(item, /obj/item/grabbing) && L && user.Adjacent(src))
		var/obj/item/grabbing/grab = item
		if(L.capture(user, grab.grabbed))
			qdel(grab)
		return
	return ..()

/area/werewolf_den/pit
	name = "Moon Pit"
/obj/effect/landmark/werewolf_drop
	name = "werewolf drop"
/obj/structure/werewolf_moon_anchor
	name = "moon shrine"
	desc = "A shrine to the hidden moon."
	icon = 'icons/obj/rune.dmi'
	icon_state = "summon"
	anchored = TRUE
