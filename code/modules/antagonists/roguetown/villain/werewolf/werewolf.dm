/datum/antagonist/werewolf
	name = "Verevolf"
	roundend_category = "Werewolves"
	antagpanel_category = "Werewolf"
	job_rank = ROLE_WEREWOLF
	confess_lines = list(
		"THE BEAST INSIDE ME!",
		"BEWARE THE BEAST!", // beware my /obj/item/organ/penis/knotted/big
		"MY LUPINE MARK!",
	)
	rogue_enabled = TRUE
	var/special_role = ROLE_WEREWOLF
	var/transformed
	var/transforming
	var/untransforming
	var/wolfname = "Verevolf"
	var/is_moonkissed = FALSE
	var/rage = 0
	var/next_curse_tick = 0
	var/form_change_ready_at = 0
	var/last_seen_tod
	var/nights_without_transformation = 0
	var/transformed_since_last_nightfall = FALSE
	var/forced_transformation_pending = FALSE
	var/list/curse_spells = list()
	var/list/beast_spells = list()
	var/datum/weakref/active_body_ref
	var/cleaning_curse = FALSE

/datum/antagonist/werewolf/lesser
	name = "Moonkissed"
	is_moonkissed = TRUE
	increase_votepwr = FALSE

/datum/antagonist/werewolf/lesser/roundend_report()
	return

/datum/antagonist/werewolf/examine_friendorfoe(datum/antagonist/examined_datum,mob/examiner,mob/examined)
	if(istype(examined_datum, /datum/antagonist/werewolf/lesser))
		return span_boldnotice("A young lupine kin.")
	if(istype(examined_datum, /datum/antagonist/werewolf))
		return span_boldnotice("An elder lupine kin.")
	if(examiner.Adjacent(examined))
		if(istype(examined_datum, /datum/antagonist/vampire))
			if(transformed)
				return span_boldwarning("An Ancient Vampire. I must be careful!")

/datum/antagonist/werewolf/on_gain()
	last_seen_tod = GLOB.tod
	greet()
	owner.special_role = name
	forge_werewolf_objectives()

	wolfname = "[pick(GLOB.wolf_prefixes)] [pick(GLOB.wolf_suffixes)]"
	grant_curse_powers()
	return ..()

/datum/antagonist/werewolf/on_removal()
	cleanup_curse()
	if(!silent && owner.current)
		to_chat(owner.current,span_danger("I am no longer a [special_role]!"))
	owner.special_role = null
	return ..()

/datum/antagonist/werewolf/proc/add_objective(datum/objective/O)
	objectives += O

/datum/antagonist/werewolf/proc/remove_objective(datum/objective/O)
	objectives -= O

/datum/antagonist/werewolf/proc/forge_werewolf_objectives()
	var/list/paths
	if(is_moonkissed)
		paths = list(/datum/objective/werewolf/survive, /datum/objective/werewolf/pack_elder, /datum/objective/werewolf_counter/embrace_gift)
	else
		paths = list(/datum/objective/werewolf/survive, /datum/objective/werewolf_counter/hunt, /datum/objective/werewolf_counter/slay, /datum/objective/werewolf_counter/convert, /datum/objective/werewolf_counter/trap, /datum/objective/werewolf_counter/contracts)
		if(owner.current?.getorganslot(ORGAN_SLOT_TESTICLES))
			paths += /datum/objective/werewolf_counter/breed
	for(var/path in paths)
		var/datum/objective/objective = new path
		objective.owner = owner
		objectives += objective
	refresh_werewolf_objectives()

/datum/antagonist/werewolf/greet()
	to_chat(owner.current, span_userdanger("Since a bite long, long ago, Dendor's Madness has swelled within me. Before the Moonlight, I will sate my hallowed Lust."))
	return ..()

/datum/antagonist/werewolf/lesser/greet()
	to_chat(owner.current, span_userdanger("The mooncurse runs shallow. I am Moonkissed, bound to my pack."))

/mob/living/carbon/human/proc/can_werewolf()
	if(!mind)
		return FALSE
	if(ckey && is_banned_from(ckey, list(ROLE_SYNDICATE, ROLE_WEREWOLF)))
		return FALSE
	if(mind.has_antag_datum(/datum/antagonist/zombie))
		return FALSE
	if(mind.has_antag_datum(/datum/antagonist/vampire))
		return FALSE
	if(mind.has_antag_datum(/datum/antagonist/werewolf))
		return FALSE
	if(mind.has_antag_datum(/datum/antagonist/skeleton))
		return FALSE
	//No cross species pollination!!!
	if(mind.has_antag_datum(/datum/antagonist/gnoll))
		return FALSE
	if(HAS_TRAIT(src, TRAIT_SILVER_BLESSED))
		return FALSE
	return TRUE

/mob/living/carbon/human/proc/werewolf_check(werewolf_type = /datum/antagonist/werewolf/lesser)
	if(!mind)
		return
	var/already_wolfy = mind.has_antag_datum(/datum/antagonist/werewolf)
	if(already_wolfy)
		return already_wolfy
	if(!can_werewolf())
		return
	return mind.add_antag_datum(werewolf_type)

/mob/living/carbon/human/proc/werewolf_infect_attempt()
	var/datum/antagonist/werewolf/wolfy = werewolf_check()
	if(!wolfy)
		return
	if(stat >= DEAD) //do shit the natural way i guess
		return
	to_chat(src, span_danger("I feel horrible... REALLY horrible..."))
	mob_timers["puke"] = world.time
	vomit(1, blood = TRUE, stun = FALSE)
	return wolfy

/mob/living/carbon/human
	var/tmp/werewolf_bite_pending = FALSE

// Adapted from Rivermist Hollow's Voluntary Bite (AGPL-3.0), revision 8dba961e768e:
// https://github.com/sheetofseaweed/Rivermist-Hollow-Vanderlin/blob/8dba961e768ecf8b9cbbc7b8199372f6a9fead96/modular_rmh/code/modules/antagonists/werewolf/werewolf_objectives.dm
/mob/living/carbon/human/proc/can_receive_werewolf_bite(mob/living/carbon/human/source)
	if(QDELETED(source) || source == src || source.stat != CONSCIOUS || stat != CONSCIOUS)
		return FALSE
	if(!source.Adjacent(src) || !client || !mind || mind.current != src || !can_werewolf())
		return FALSE
	if(is_banned_from(ckey, list(ROLE_SYNDICATE, ROLE_WEREWOLF)))
		return FALSE
	var/datum/antagonist/werewolf/source_werewolf = source.mind?.has_antag_datum(/datum/antagonist/werewolf)
	return source_werewolf?.transformed && source.mind.current == source

/mob/living/carbon/human/proc/offer_werewolf_bite(mob/living/carbon/human/source)
	set waitfor = FALSE

	if(werewolf_bite_pending || !can_receive_werewolf_bite(source))
		return
	werewolf_bite_pending = TRUE
	var/datum/mind/recipient_mind = mind
	var/client/recipient_client = client
	var/datum/antagonist/werewolf/source_werewolf = source.mind.has_antag_datum(/datum/antagonist/werewolf)
	// Use the timed TGUI modal even when native inputs are preferred; native alerts have no timeout.
	var/datum/tgui_alert/offer = new(src, "[source] offers to turn me into a verevolf with a deliberate bite. Do I accept the curse?", "Voluntary Bite", list("Accept", "Reject"), 20 SECONDS, TRUE, GLOB.tgui_always_state)
	offer.ui_interact(src)
	offer.wait()
	var/answer
	if(!QDELETED(offer))
		answer = offer.choice
		qdel(offer)
	if(QDELETED(src))
		return
	werewolf_bite_pending = FALSE
	if(answer != "Accept")
		to_chat(src, span_notice("I refuse the verevolf's curse."))
		if(!QDELETED(source))
			to_chat(source, span_notice("[src] refuses the verevolf's curse."))
		return
	if(!can_receive_werewolf_bite(source) || mind != recipient_mind || client != recipient_client || source.mind.has_antag_datum(/datum/antagonist/werewolf) != source_werewolf)
		to_chat(src, span_warning("The moment to accept the curse has passed."))
		return
	if(!werewolf_check())
		return
	source_werewolf.record_conversion_target(src)
	to_chat(src, span_userdanger("The mooncurse takes root within me. I am Moonkissed."))
	to_chat(source, span_notice("[src] accepts the verevolf's curse."))
	log_combat(source, src, "converted into a verevolf through a voluntary bite")

/mob/living/carbon/human/proc/werewolf_feed(mob/living/carbon/human/target, healing_amount = 10)
	if(!istype(target))
		return
	if(has_status_effect(/datum/status_effect/debuff/werewolf_silver_bane) || has_status_effect(/datum/status_effect/fire_handler/fire_stacks/sunder) || has_status_effect(/datum/status_effect/fire_handler/fire_stacks/sunder/blessed))
		to_chat(src, span_notice("My power is weakened, I cannot heal!"))
		return
	if(target.mind)
		if(target.mind.has_antag_datum(/datum/antagonist/zombie))
			to_chat(src, span_warning("I should not feed on rotten flesh."))
			return
		if(target.mind.has_antag_datum(/datum/antagonist/vampire))
			to_chat(src, span_warning("I should not feed on corrupted flesh."))
			return
		if(target.mind.has_antag_datum(/datum/antagonist/werewolf))
			to_chat(src, span_warning("I should not feed on my kin's flesh."))
			return

	to_chat(src, span_warning("I feed on succulent flesh. I feel reinvigorated."))
	return src.reagents.add_reagent(/datum/reagent/medicine/healthpot, healing_amount)

/obj/item/clothing/suit/roguetown/armor/skin_armor/werewolf_skin
	parent_type = /obj/item/clothing/suit/roguetown/armor/regenerating/skin
	repair_time = 15 SECONDS
	slot_flags = null
	name = "verevolf's skin"
	desc = ""
	icon_state = null
	body_parts_covered = FULL_BODY
	body_parts_inherent = FULL_BODY
	armor = ARMOR_BRIGANDINE
	prevent_crits = list(BCLASS_CUT, BCLASS_CHOP, BCLASS_STAB, BCLASS_BLUNT, BCLASS_TWIST)
	blocksound = SOFTHIT
	blade_dulling = DULLING_BASHCHOP
	sewrepair = FALSE
	max_integrity = 300
	item_flags = DROPDEL

/obj/item/clothing/suit/roguetown/armor/skin_armor/werewolf_skin/Initialize(mapload)///makes blessed silver do extra damage
	. = ..()
	if(ismob(loc))
		RegisterSignal(loc, list(COMSIG_SPECIES_ATTACKED_BY, COMSIG_LIVING_ARMOR_CHECKED, COMSIG_MOB_APPLY_DAMGE), TYPE_PROC_REF(/obj/item/clothing/suit/roguetown/armor/regenerating, on_attacked_by), override = TRUE)

/datum/intent/simple/werewolf
	name = "claw"
	icon_state = "inchop"
	blade_class = BCLASS_CHOP
	attack_verb = list("claws", "mauls", "eviscerates")
	animname = "chop"
	hitsound = "genslash"
	penfactor = 45
	miss_text = "slashes the air!"
	miss_sound = "bluntwooshlarge"
	item_d_type = "slash"

/datum/intent/mace/smash/werewolf
	name = "thrash"
	desc = "A powerful, smash of lycan muscle that deals normal damage but can throw a standing opponent back and slow them down, based on your strength. Ineffective below 10 strength. Slowdown & Knockback scales to your Strength up to 15 (1 - 5 tiles). Cannot be used consecutively more than every 5 seconds on the same target. Prone targets halve the knockback distance."
	icon_state = "insmash"
	chargetime = 1
	penfactor = 60

/obj/item/rogueweapon/werewolf_claw
	name = "Verevolf Claw"
	desc = ""
	item_state = null
	experimental_inhand = FALSE
	lefthand_file = null
	righthand_file = null
	icon = 'icons/roguetown/weapons/unarmed32.dmi'
	max_blade_int = 900
	max_integrity = 900
	force = 15
	block_chance = 0
	wdefense = 2
	armor_penetration = 0
	associated_skill = /datum/skill/combat/unarmed
	wlength = WLENGTH_NORMAL
	wbalance = WBALANCE_HEAVY
	w_class = WEIGHT_CLASS_BULKY
	can_parry = TRUE
	sharpness = IS_SHARP
	parrysound = "bladedmedium"
	swingsound = BLADEWOOSH_MED
	possible_item_intents = list(/datum/intent/simple/werewolf)
	parrysound = list('sound/combat/parry/parrygen.ogg')
	embedding = list("embedded_pain_multiplier" = 0, "embed_chance" = 0, "embedded_fall_chance" = 0)
	item_flags = DROPDEL
	special = null

/obj/item/rogueweapon/werewolf_claw/right
	icon_state = "claw_r"

/obj/item/rogueweapon/werewolf_claw/left
	icon_state = "claw_l"

/obj/item/rogueweapon/werewolf_claw/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NOEMBED, TRAIT_GENERIC)
