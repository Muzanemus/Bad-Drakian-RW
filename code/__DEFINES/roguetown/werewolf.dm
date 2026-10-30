// Howl channel recipients — used in howl_channels list to define who can hear a howl.
#define HOWL_CHANNEL_WEREWOLF "werewolf" // Werewolves (/datum/antagonist/werewolf and subtypes)
#define HOWL_CHANNEL_DRUID    "druid"    // Druids, Dendorite Acolytes, and users with Call of the Moon
#define HOWL_CHANNEL_GNOLL    "gnoll"    // Gnolls (/datum/antagonist/gnoll)

GLOBAL_LIST_INIT(wolf_prefixes, list("Red", "Moon", "Bloody", "Hairy", "Eager", "Sharp", "Dark", "Silver",
									"Night", "Savage", "Fierce", "Iron", "Storm", "Wild", "Fierce", "Grim",
									"Crimson", "Midnight", "Steel", "Vicious"))
GLOBAL_LIST_INIT(wolf_suffixes, list("Fang", "Claw", "Stalker", "Prowler", "Roar", "Ripper", "Howl", "Hunt", "Hunter",
									"Bane", "Wrath", "Terror", "Fury", "Scar", "Shredder", "Maul", "Rage", "Scourge",
									"Ravager", "Seeker", "Raider"))

#define CONTRACT_GRADE_FULL "full"
#define CONTRACT_GRADE_PARTIAL "partial"
#define CONTRACT_GRADE_FAIL "fail"
#define CONTRACT_GRADE_EXCUSED "excused"

/// Goal progress is recorded live via record_contract_progress()
#define CONTRACT_GOAL_COUNTER 1
/// Goal is evaluated by polling get_state_progress() at cycle end
#define CONTRACT_GOAL_STATE 2

/// Offline for at least this fraction of a cycle = EXCUSED grade
#define CONTRACT_EXCUSED_OFFLINE_FRACTION 0.5
/// Storyteller escalation per FULL contract, as fraction of track threshold, times tier
#define CONTRACT_OMEN_ESCALATION_FRACTION 0.025
#define CONTRACT_INTERVENTION_ESCALATION_FRACTION 0.01

#define TRAIT_WEREWOLF_TRANSFORMATION_SUPPRESSED "werewolf_transformation_suppressed"
#define TRAIT_WEREWOLF_STAGGERED "werewolf_recently_staggered"
#define COMSIG_MOB_ADD_STRESS "mob_add_stress"

// Objective tuning
#define WW_BREED_OBJECTIVE_MIN 5
#define WW_BREED_OBJECTIVE_MAX 10
#define WW_HUNT_OBJECTIVE_MIN 4
#define WW_HUNT_OBJECTIVE_MAX 8
#define WW_SLAY_OBJECTIVE_MIN 4
#define WW_SLAY_OBJECTIVE_MAX 8
#define WW_CONVERT_OBJECTIVE_MIN 3
#define WW_CONVERT_OBJECTIVE_MAX 4
#define WW_CONTRACT_OBJECTIVE_TARGET 400
#define WW_CONTRACT_SCORE_BASE 5
#define WW_CONTRACT_SCORE_STEP 10
#define WW_TRAP_OBJECTIVE_TARGET 4
#define WW_TRAP_ORGASM_TRIGGER 10
#define WW_TRAP_TIME_TRIGGER 10 MINUTES
#define WW_TRAP_RESET_COOLDOWN 2 MINUTES


#define CTAG_WEREWOLF "ctag_werewolf"

#define COMSIG_LIVING_COMBAT_KILL "kill_other"
