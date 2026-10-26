// Verb sections/search adapted from Ochre Valley (AGPL-3.0), commit:
// https://github.com/Ochre-Valley/Ochre-Valley/commit/0bf650a9b662d0981bae8894d8f2df30d7e79de9
// Native status data continues to come from Bad Drakian's existing Stat() procedures.
var menu = document.getElementById('menu');
var statcontentdiv = document.getElementById('statcontent');
var current_tab = 'RoundInfo';
var nativeTabs = ['RoundInfo'];
var nativeRows = Object.create(null);
var verbs = [];
var verb_tabs = [];
var verbSearch = '';
var lastVerbCat = '';
var split_admin_tabs = false;

function sortVerbs() {
	verbs.sort(function (a, b) {
		return (a[0] + '\n' + a[1]).localeCompare(b[0] + '\n' + b[1]);
	});
	verbs.reverse();
}

function make_verb_onclick(command) {
	return function (event) {
		event.preventDefault();
		Byond.winset('map', { focus: true });
		setTimeout(function () {
			Byond.command(command);
		}, 0);
	};
}

function renderTabs() {
	menu.textContent = '';
	var tabs = nativeTabs.concat(verb_tabs).filter(function (tab, index, all) {
		return all.indexOf(tab) === index;
	});
	tabs.forEach(function (tab) {
		var button = document.createElement('button');
		button.type = 'button';
		button.className = 'button' + (tab === current_tab ? ' active' : '');
		button.textContent = tab === 'RoundInfo' ? 'Round Info' : tab;
		button.onclick = function () {
			tab_change(tab);
		};
		menu.appendChild(button);
	});
	if (tabs.indexOf(current_tab) === -1) tab_change('RoundInfo');
}

function tab_change(tab) {
	current_tab = tab;
	Byond.sendMessage('Set-Tab', { tab: tab });
	renderTabs();
	if (nativeTabs.indexOf(tab) !== -1) draw_native();
	else draw_verbs(tab);
}

function draw_native() {
	statcontentdiv.textContent = '';
	(nativeRows[current_tab] || []).forEach(function (row) {
		var line = document.createElement('div');
		if (row[0]) line.appendChild(document.createTextNode(row[0]));
		if (row[0] && row[1]) line.appendChild(document.createTextNode(' '));
		var label = row[1] || (row[2] ? row[0] : '');
		if (row[2]) {
			if (!row[1]) line.textContent = '';
			var link = document.createElement('a');
			link.href = '#';
			link.textContent = label;
			link.oncontextmenu = function (event) {
				event.preventDefault();
			};
			link.onmousedown = function (event) {
				event.preventDefault();
				Byond.sendMessage('stat-click', {
					ref: row[2],
					button: event.button,
					shift: event.shiftKey,
					ctrl: event.ctrlKey,
					alt: event.altKey,
				});
			};
			line.appendChild(link);
		} else if (row[1]) {
			line.appendChild(document.createTextNode(row[1]));
		}
		if (!row[0] && !row[1]) line.appendChild(document.createElement('br'));
		statcontentdiv.appendChild(line);
	});
}

function set_theme(which) {
	document.documentElement.className = which === 'light' ? 'light' : 'dark';
}
function set_font_size(size) {
	document.body.style.fontSize = size;
}
function set_tabs_style(style) {
	menu.classList.toggle('menu-wrap', style !== 'scrollable');
	menu.classList.toggle('tabs-classic', style === 'classic');
}

Byond.subscribeTo('init_verbs', function (entries) {
	var focused = document.activeElement;
	var wasSearching = focused && focused.className === 'verb-search';
	var selection = wasSearching ? focused.selectionStart : 0;
	verbs = entries;
	verb_tabs = [];
	verbs.forEach(function (entry) {
		var tab = entry[2] || entry[0].split('.')[0];
		if (verb_tabs.indexOf(tab) === -1) verb_tabs.push(tab);
	});
	verb_tabs.sort();
	renderTabs();
	if (nativeTabs.indexOf(current_tab) === -1) {
		draw_verbs(current_tab);
		if (wasSearching) {
			var input = statcontentdiv.querySelector('.verb-search');
			input.focus();
			input.setSelectionRange(selection, selection);
		}
	}
});
Byond.subscribeTo('native_stat', function (data) {
	nativeTabs = data.tabs;
	nativeRows[data.tab] = data.rows;
	if (data.select) current_tab = data.tab;
	renderTabs();
	if (current_tab === data.tab && nativeTabs.indexOf(current_tab) !== -1)
		draw_native();
});
Byond.subscribeTo('set_theme', set_theme);
set_theme('dark');
renderTabs();
function draw_verbs(cat) {
	statcontentdiv.textContent = '';
	if (cat != lastVerbCat) {
		verbSearch = '';
		lastVerbCat = cat;
	}
	var verbSearchBox = document.createElement('input');
	verbSearchBox.type = 'text';
	verbSearchBox.className = 'verb-search';
	verbSearchBox.placeholder = 'Search verbs...';
	verbSearchBox.setAttribute('aria-label', 'Search verbs');
	verbSearchBox.value = verbSearch;
	verbSearchBox.oninput = function () {
		verbSearch = verbSearchBox.value;
		filterVerbs();
	};
	statcontentdiv.appendChild(verbSearchBox);
	var table = document.createElement('div');
	var additions = Object.create(null); // additional sub-categories to be rendered
	table.className = 'grid-container';
	sortVerbs();
	if (split_admin_tabs && cat.lastIndexOf('.') != -1) {
		var splitName = cat.split('.');
		if (splitName[0] === 'Admin') cat = splitName[1];
	}
	verbs.reverse(); // sort verbs backwards before we draw
	for (var i = 0; i < verbs.length; ++i) {
		var part = verbs[i];
		var name = part[0];
		if (split_admin_tabs && name.lastIndexOf('.') != -1) {
			var splitName = name.split('.');
			if (splitName[0] === 'Admin') name = splitName[1];
		}
		var command = part[1];

		if (command && (part[2] || name.split('.')[0]) === cat) {
			var subCat =
				name.indexOf(cat + '.') === 0
					? name.slice(cat.length + 1)
					: null;
			if (subCat && !additions[subCat]) {
				var newTable = document.createElement('div');
				newTable.className = 'grid-container';
				additions[subCat] = newTable;
			}

			var a = document.createElement('a');
			a.href = '#';
			a.onclick = make_verb_onclick(command.replace(/\s/g, '-'));
			a.className = 'grid-item';
			a.setAttribute('data-label', command);
			var t = document.createElement('span');
			t.textContent = command;
			t.className = 'grid-item-text';
			a.appendChild(t);
			(subCat ? additions[subCat] : table).appendChild(a);
		}
	}

	// Append base table to view
	var content = document.getElementById('statcontent');
	content.appendChild(table);

	// Append additional sub-categories if relevant
	for (var cat in additions) {
		if (Object.hasOwn(additions, cat)) {
			// do addition here
			var header = document.createElement('h3');
			header.textContent = cat;
			content.appendChild(header);
			content.appendChild(additions[cat]);
		}
	}
	filterVerbs();
}

function filterVerbs() {
	var q = (verbSearch || '').trim().toLowerCase();
	var items = document
		.getElementById('statcontent')
		.getElementsByClassName('grid-item');
	for (var i = 0; i < items.length; i++) {
		var show = !q || items[i].textContent.toLowerCase().indexOf(q) !== -1;
		items[i].style.display = show ? '' : 'none';
	}
	statcontentdiv.querySelectorAll('.grid-container').forEach(function (grid) {
		var anyVisible = Array.prototype.some.call(
			grid.children,
			function (item) {
				return item.style.display !== 'none';
			},
		);
		grid.style.display = anyVisible ? '' : 'none';
		var header = grid.previousElementSibling;
		if (header && header.tagName === 'H3')
			header.style.display = grid.style.display;
	});
}
