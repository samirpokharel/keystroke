.pragma library
.import "Hotkeys.js" as Hotkeys

// smr: which keybinding does the same thing as a result row. The preview
// pane shows those keys for any row, not just Hotkeys rows: Screenshot shows
// Print, Chromium shows whatever launches it, a submenu shows the bind that
// opens it. Built from the same omarchy-menu-keybindings records the Hotkeys
// provider loads, matched on the command each side would run.

// Launch wrappers whose next word names the program or page they start.
var WRAPPERS = {
  "omarchy-launch-or-focus": true, "omarchy-launch-or-focus-webapp": true,
  "omarchy-launch-webapp": true, "omarchy-launch-tui": true, "omarchy-launch-or-focus-tui": true
}

// A command as it would run: no uwsm/setsid prefix, no backgrounding, one
// space between words.
function norm(command) {
  var text = String(command || "").replace(/\s+/g, " ").trim()
  text = text.replace(/^(uwsm-app|uwsm app)\s+--\s+/, "").replace(/^setsid\s+/, "").replace(/\s*&$/, "")
  return text
}

// "a --stop || b" runs either, so either may match.
function parts(command) {
  return String(command || "").split(/\s*(?:\|\||&&|;)\s*/).map(norm).filter(function(p) { return p.length > 0 })
}

function basename(word) {
  var text = String(word || "").replace(/^["']|["']$/g, "")
  return text.substring(text.lastIndexOf("/") + 1).toLowerCase()
}

// The program a command starts: its first word, or the wrapped one.
function programs(command) {
  var words = norm(command).split(" ")
  var out = [basename(words[0])]
  if (WRAPPERS[out[0]] && words[1]) out.push(basename(words[1]))
  return out
}

function push(map, key, bind) {
  if (!key) return
  if (!map[key]) map[key] = []
  if (map[key].indexOf(bind) < 0) map[key].push(bind)
}

function index(binds) {
  var idx = { cmd: ({}), menu: ({}), prog: ({}), raw: ({}) }
  for (var i = 0; i < (binds || []).length; i++) {
    var bind = binds[i]
    push(idx.raw, bind.dispatcher + "\u001f" + bind.arg, bind)
    if (bind.dispatcher !== "exec") continue
    var ps = parts(bind.arg)
    for (var j = 0; j < ps.length; j++) {
      push(idx.cmd, ps[j], bind)
      var menu = /^omarchy-menu(?:\s+(?:toggle|summon))?(?:\s+(\S+))?$/.exec(ps[j])
      if (menu) push(idx.menu, menu[1] || "root", bind)
      var progs = programs(ps[j])
      for (var k = 0; k < progs.length; k++) push(idx.prog, progs[k], bind)
    }
  }
  return idx
}

// An app's launch line from its desktop entry, without %U-style field codes.
function execLine(command) {
  var words = Array.isArray(command) ? command : String(command || "").split(" ")
  return norm(words.filter(function(w) { return !/^%[a-zA-Z]$/.test(String(w)) }).join(" "))
}

// Binds for a row, as { label, keys: ["Super", "F"] } per combo.
function forRow(row, idx, appCommand, extraCommand) {
  if (!row || !row.action || !idx) return []
  var action = row.action, hits = []
  function add(list) { for (var i = 0; i < (list || []).length; i++) if (hits.indexOf(list[i]) < 0) hits.push(list[i]) }

  if (action.type === "hotkey") add(idx.raw[action.dispatcher + "\u001f" + action.arg])
  else if (action.type === "shell") {
    var ps = parts(action.command)
    for (var i = 0; i < ps.length; i++) add(idx.cmd[ps[i]])
  } else if (action.type === "navigate" && /^omarchy\//.test(String(action.scope || ""))) {
    add(idx.menu[String(action.scope).substring(8)])
  } else if (action.type === "app") {
    var line = execLine(appCommand)
    if (line) {
      add(idx.cmd[line])
      if (!hits.length) add(idx.prog[programs(line)[programs(line).length - 1]])
    }
    if (!hits.length) add(idx.prog[String(action.id || "").toLowerCase()])
    // The default terminal/browser also answer to Omarchy's generic launchers.
    if (extraCommand) add(idx.cmd[extraCommand])
  }

  var out = []
  for (var h = 0; h < hits.length; h++) {
    for (var c = 0; c < hits[h].combos.length; c++) {
      var text = Hotkeys.keys(hits[h].combos[c])
      if (!text) continue
      out.push({ label: hits[h].label, keys: text.split(" + ") })
    }
  }
  return out.slice(0, 3)
}
