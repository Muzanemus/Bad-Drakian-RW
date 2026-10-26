// Verb sections/search adapted from Ochre Valley (AGPL-3.0):
// https://github.com/Ochre-Valley/Ochre-Valley/commit/0bf650a9b662d0981bae8894d8f2df30d7e79de9
// Keep native Stat() data generation and permission checks as the single source of truth.
/client
	var/datum/tgui_window/statbrowser_window
	var/statbrowser_tab = "RoundInfo"
	var/list/statbrowser_tabs = list()
	var/list/statbrowser_rows = list()
	var/list/statbrowser_clicks = list()
	var/statbrowser_panel_name
	var/statbrowser_update_pending = FALSE
	var/statbrowser_last_data
	var/list/statbrowser_verbs = list()
	var/list/statbrowser_verb_tabs = list()
	var/statbrowser_next_verbs_update = 0
	var/statbrowser_verb_visibility = 0
	var/statbrowser_requested_tab
	var/statbrowser_next_update = 0

/client/proc/initialize_statbrowser()
	set waitfor = FALSE
	sleep(1 TICKS)
	if(!src)
		return
	statbrowser_window = new(src, "statbrowser")
	statbrowser_window.subscribe(src, PROC_REF(on_statbrowser_message))
	statbrowser_window.initialize(
		inline_html = file("html/statbrowser.html"),
		inline_js = file("html/statbrowser.js"),
		inline_css = file("html/statbrowser.css"),
	)

/client/proc/on_statbrowser_message(type, list/payload)
	if(type != "ready" && !islist(payload))
		return TRUE
	switch(type)
		if("ready")
			statbrowser_tab = "RoundInfo"
			statbrowser_last_data = null
			statbrowser_next_update = 0
			winset(src, "statbrowser", "is-visible=true")
			update_statbrowser_verbs(TRUE)
			return TRUE
		if("Set-Tab")
			var/tab = payload?["tab"]
			if((tab in statbrowser_tabs) || (tab in statbrowser_verb_tabs))
				statbrowser_tab = tab
				statbrowser_last_data = null
				statbrowser_next_update = 0
			return TRUE
		if("stat-click")
			if((statbrowser_tab == "MC" || statbrowser_tab == "SDQL2") && !check_rights_for(src, R_DEBUG))
				return TRUE
			if(statbrowser_tab == "Tickets" && !check_rights_for(src, R_AHELP))
				return TRUE
			var/ref = payload?["ref"]
			if(!(ref in statbrowser_clicks))
				return TRUE
			var/atom/target = locate(ref)
			if(!target || !mob)
				return TRUE
			if(istype(target, /obj/effect/statclick))
				if(!holder)
					return TRUE
			else if(istype(target, /obj/effect/proc_holder))
				var/owned = (target in mob.mob_spell_list) || (target in mob.mind?.spell_list)
				if(isliving(mob))
					var/mob/living/living_mob = mob
					owned = owned || (target in living_mob.abilities)
				if(!owned)
					return TRUE
			else if(!mob.listed_turf || get_turf(target) != mob.listed_turf || !mob.TurfAdjacent(mob.listed_turf) || target.invisibility > mob.see_invisible)
				return TRUE
			var/list/click_params = list()
			switch(payload["button"])
				if(0)
					click_params["left"] = "1"
				if(1)
					click_params["middle"] = "1"
				if(2)
					click_params["right"] = "1"
				else
					return TRUE
			if(payload["shift"])
				click_params["shift"] = "1"
			if(payload["ctrl"])
				click_params["ctrl"] = "1"
			if(payload["alt"])
				click_params["alt"] = "1"
			Click(target, target.loc, null, list2params(click_params))
			return TRUE

/// Poll verb identities, not serialized payloads; send only when the available set changes.
/client/proc/update_statbrowser_verbs(force = FALSE)
	if(!statbrowser_window?.is_ready())
		return
	if(!force && world.time < statbrowser_next_verbs_update)
		return
	statbrowser_next_verbs_update = world.time + 2 SECONDS
	var/list/available = verbs.Copy()
	if(mob)
		available |= mob.verbs
		for(var/atom/movable/item as anything in mob.contents)
			available |= item.verbs
	var/visibility = mob?.see_invisible || 0
	if(!force && visibility == statbrowser_verb_visibility && length(available) == length(statbrowser_verbs) && !length(available ^ statbrowser_verbs))
		return
	statbrowser_verbs = available
	statbrowser_verb_visibility = visibility
	var/list/entries = list()
	statbrowser_verb_tabs = list()
	for(var/procpath/verb_path as anything in available)
		if(statbrowser_verb_hidden(verb_path) || verb_path.invisibility > visibility || !istext(verb_path.category) || !length(verb_path.category))
			continue
		var/tab = statbrowser_verb_tab(verb_path)
		statbrowser_verb_tabs |= tab
		entries += list(list(statbrowser_verb_category(verb_path), verb_path.name, tab))
	statbrowser_window.send_message("init_verbs", entries)

/// Preserve native category names until presentation groups are assigned.
/proc/statbrowser_verb_tab(procpath/verb_path)
	return verb_path.category

/// BYOND does not expose `set hidden` through procpath reflection.
/// This metadata is regenerated from the compiler's source index by the build tool.
/proc/statbrowser_verb_hidden(procpath/verb_path)
	var/static/list/hidden_settings = json_decode(file2text(file("html/statbrowser_hidden_verbs.json")))
	return hidden_settings["[verb_path]"]

/// Category payload used by the browser renderer.
/proc/statbrowser_verb_category(procpath/verb_path)
	return verb_path.category

/// Called by native Stat(); defer flushing until the entire subtype Stat() chain returns.
/client/proc/begin_statbrowser_update()
	if(!statbrowser_window?.is_ready() || statbrowser_update_pending || world.time < statbrowser_next_update)
		return
	statbrowser_next_update = world.time + 1 SECONDS
	statbrowser_update_pending = TRUE
	statbrowser_tabs = list()
	statbrowser_rows = list()
	statbrowser_clicks = list()
	spawn(0)
		if(src)
			flush_statbrowser_update()

/client/proc/flush_statbrowser_update()
	statbrowser_update_pending = FALSE
	if(!statbrowser_window?.is_ready())
		return
	update_statbrowser_verbs()
	var/list/data = list("tabs" = statbrowser_tabs, "tab" = statbrowser_tab, "rows" = statbrowser_rows, "select" = !!statbrowser_requested_tab)
	statbrowser_requested_tab = null
	var/encoded = json_encode(data)
	if(encoded == statbrowser_last_data)
		return
	statbrowser_last_data = encoded
	statbrowser_window.send_message("native_stat", data)

/// Preserve native requests to open a turf listing, including while the browser loads.
/client/proc/select_statbrowser_tab(tab)
	statpanel = tab
	statbrowser_tab = tab
	statbrowser_requested_tab = tab
	statbrowser_last_data = null
	statbrowser_next_update = 0

/// Native passthrough plus browser capture. These wrappers preserve existing Stat() checks.
/proc/statbrowser_panel(tab, name, value)
	. = statpanel(tab)
	if(args.len > 1)
		stat(name, value)
	var/client/C = usr?.client
	if(!C?.statbrowser_update_pending)
		return
	C.statbrowser_panel_name = tab
	C.statbrowser_tabs |= tab
	if(args.len > 1)
		statbrowser_record(name, value)
	return . || C.statbrowser_tab == tab

/proc/statbrowser_entry(name, value)
	if(args.len == 1)
		stat(name)
	else
		stat(name, value)
	statbrowser_record(name, value)

/proc/statbrowser_record(name, value)
	var/client/C = usr?.client
	if(!C?.statbrowser_update_pending || C.statbrowser_panel_name != C.statbrowser_tab)
		return
	var/atom/click_target
	if(isatom(value))
		click_target = value
	else if(isatom(name))
		click_target = name
	var/target_ref
	if(click_target)
		target_ref = REF(click_target)
		C.statbrowser_clicks |= target_ref
	C.statbrowser_rows += list(list(isnull(name) ? "" : "[name]", isnull(value) ? "" : "[value]", target_ref))
