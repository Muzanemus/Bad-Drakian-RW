/datum/quirk/rapebait
	name = "Rapebait"
	desc = "Players with the Rapist quirk can follow my trail."
	warning_text = "Players with the Rapist quirk can track your location. You'll be warned when they pick up your trail."
	point_cost = 0
	added_traits = list(TRAIT_RAPEBAIT)

/datum/quirk/rapist
	name = "Rapist"
	desc = "I can pick up the trail of someone who has chosen the Rapebait quirk."
	point_cost = 0
	added_traits = list(TRAIT_RAPIST)

/datum/quirk/rapist/apply_to_human(mob/living/carbon/human/recipient)
	if(locate(/obj/effect/proc_holder/spell/invoked/track_rapebait) in recipient.mob_spell_list)
		return
	recipient.AddSpell(new /obj/effect/proc_holder/spell/invoked/track_rapebait)
