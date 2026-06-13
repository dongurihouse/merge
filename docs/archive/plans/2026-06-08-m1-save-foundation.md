# M1 Part 1 — Save Persistence Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `Save` — the single owner of all persisted state — as a versioned-JSON store with atomic writes, a `.bak` fallback, and a one-time migration from the legacy `progress.cfg`, then route the existing `Progress` reads/writes through it.

**Architecture:** `Save` is a **static-singleton preload const** (`scripts/save.gd`, like the existing `Audio`/`Progress`/`Palette`), *not* a tree autoload — pure data needs no scene presence, and Godot autoloads don't resolve in headless `-s` test runs (a known gotcha in this project). It holds one `Dictionary` mirrored to `user://save.json`. Writes are atomic (`.tmp` → re-parse-verify → rename, keeping the previous file as `.bak`); reads fall back primary → backup → fresh. A first run with a legacy `progress.cfg` migrates once (seeding `boards_cleared` and a coin grant), guarded by a `migrated_v2` flag. `progress.gd` becomes a thin read/delegate shim so `main.gd`/`room.gd` keep working unchanged while all state lives in `Save`.

**Tech Stack:** Godot 4.6.2, GDScript. Tests are headless `SceneTree` scripts run with `godot --headless -s res://tests/<file>.gd`. Persistence via `FileAccess` (JSON) + `DirAccess` (atomic rename) + `ConfigFile` (legacy read only).

**Scope note:** This is the first of several M1 plans. FX layer, i18n string-externalization, EconConfig, and Settings are **separate plans**. This plan adds only the fields needed now (`currencies.coins`, `jobs`, `stats.boards_cleared`); later plans add `rooms`/`quests`/`streak`/etc. additively via the deep-merge (no migration code needed for additive fields). `crc` integrity is intentionally out of scope — corruption is detected by JSON re-parse validity, which covers truncated/garbage files.

**Godot binary:** `/opt/homebrew/bin/godot`

---

### Task 0: Initialize version control

**Files:**
- Create: `.gitignore`

- [ ] **Step 1: Initialize the repo and ignore generated files**

```bash
cd /Users/xup/mobile_game
git init
printf '.godot/\n.DS_Store\n/tmp/\n' > .gitignore
git add -A
git commit -m "chore: initialize git repo for Tidy Up"
```

Expected: a first commit containing the existing project. (`.godot/` is Godot's regenerable import cache — ignored; `*.import` files ARE committed, as Godot requires them.)

---

### Task 1: Save module — schema, round-trip, atomic write

**Files:**
- Create: `scripts/save.gd`
- Test: `tests/save_tests.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/save_tests.gd`:

```gdscript
extends SceneTree
## Headless tests for the Save persistence layer.
##   godot --headless -s res://tests/save_tests.gd

const Save = preload("res://scripts/save.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

# Point Save at a clean temp dir (never touches the real save or progress.cfg).
func fresh(name: String) -> void:
	var dir := "user://tu_test_" + name + "/"
	if DirAccess.dir_exists_absolute(dir):
		for fn in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + fn)
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	Save.configure_for_test(dir)

func _initialize() -> void:
	print("== Save tests ==")

	# 1. fresh load → defaults
	fresh("fresh")
	ok(Save.coins() == 0, "fresh load: coins default 0")

	# 2. persistence across an explicit reload
	fresh("persist")
	Save.add_coins(120)
	Save._loaded = false              # force a reload from disk
	ok(Save.coins() == 120, "coins persist across reload")

	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `/opt/homebrew/bin/godot --headless -s res://tests/save_tests.gd`
Expected: FAIL to even load — `Parse Error: Could not preload resource file "res://scripts/save.gd"` (file does not exist yet).

- [ ] **Step 3: Write the minimal implementation**

Create `scripts/save.gd`:

```gdscript
extends RefCounted
## Tidy Up — THE persistence layer (single owner of all saved state).
## Static singleton (like Audio): everything reads/writes via Save.* — no other save file,
## no other format. Versioned JSON at user://save.json with atomic writes + a .bak fallback
## and a one-time migration from the legacy progress.cfg.
##
## NOT a tree autoload: pure data needs no scene presence, and autoloads don't resolve in
## headless `-s` test runs. Tests call configure_for_test() to redirect the paths.

const SCHEMA_VERSION := 2
const COINS_PER_CLEAR_SEED := 35   # migration: coins granted per past board clear

# Paths are static vars (not consts) so tests can redirect them to a temp dir.
static var path := "user://save.json"
static var bak := "user://save.bak"
static var tmp := "user://save.tmp"
static var legacy := "user://progress.cfg"

static var data: Dictionary = {}
static var _loaded := false

static func _default() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"migrated_v2": false,
		"currencies": {"coins": 0},
		"jobs": {},                       # job_id -> {best_stars, best_drags, completed, plays, first_clear_paid}
		"stats": {"boards_cleared": 0},
		"settings": {},
	}

# --- lifecycle -------------------------------------------------------------

static func _ensure_loaded() -> void:
	if not _loaded:
		load_now()

static func load_now() -> void:
	_loaded = true
	var loaded := _read(path)
	data = _merge(_default(), loaded)
	save_now()

static func _read(p: String) -> Dictionary:
	if not FileAccess.file_exists(p):
		return {}
	var text := FileAccess.get_file_as_string(p)
	if text == "":
		return {}
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}                              # garbage/truncated → treat as missing

static func save_now() -> void:
	data["schema_version"] = SCHEMA_VERSION
	var text := JSON.stringify(data, "  ")
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(text)
	f.close()
	if _read(tmp).is_empty():               # verify the temp file re-parses
		return
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return
	dir.rename(tmp.get_file(), path.get_file())   # atomic swap-in

static func flush() -> void:
	if _loaded:
		save_now()

# Deep additive merge: fills keys missing from `over` using `base`, never drops `over`'s data.
static func _merge(base: Dictionary, over: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for k in over:
		if out.has(k) and out[k] is Dictionary and over[k] is Dictionary:
			out[k] = _merge(out[k], over[k])
		else:
			out[k] = over[k]
	return out

# --- accessors -------------------------------------------------------------

static func coins() -> int:
	_ensure_loaded()
	return int(data["currencies"]["coins"])

static func add_coins(n: int) -> void:
	_ensure_loaded()
	data["currencies"]["coins"] = coins() + n
	save_now()

# --- test support ----------------------------------------------------------

static func configure_for_test(dir: String) -> void:
	path = dir + "save.json"
	bak = dir + "save.bak"
	tmp = dir + "save.tmp"
	legacy = dir + "progress.cfg"
	data = {}
	_loaded = false
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `/opt/homebrew/bin/godot --headless -s res://tests/save_tests.gd`
Expected: `== 2 passed, 0 failed ==` and exit code 0.

- [ ] **Step 5: Commit**

```bash
cd /Users/xup/mobile_game
git add scripts/save.gd tests/save_tests.gd
git commit -m "feat(save): JSON save store with atomic write + round-trip"
```

---

### Task 2: Backup (.bak) + corruption fallback

**Files:**
- Modify: `scripts/save.gd` (`save_now`, `load_now`)
- Test: `tests/save_tests.gd`

- [ ] **Step 1: Write the failing test**

Add this block to `tests/save_tests.gd` just before the final `print("== %d passed...` line:

```gdscript
	# 3. corruption of the live file recovers from .bak
	fresh("corrupt")
	Save.add_coins(200)               # 1st write: creates save.json (no .bak yet)
	Save.add_coins(0)                 # 2nd write: rotates save.json -> save.bak
	var bad := FileAccess.open(Save.path, FileAccess.WRITE)
	bad.store_string("{ this is not json")
	bad.close()
	Save._loaded = false
	ok(Save.coins() == 200, "corrupt primary recovers from .bak")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `/opt/homebrew/bin/godot --headless -s res://tests/save_tests.gd`
Expected: FAIL `corrupt primary recovers from .bak` (currently `load_now` reads only `path`, finds garbage → falls to defaults → coins 0, not 200).

- [ ] **Step 3: Write the implementation**

In `scripts/save.gd`, replace `load_now` and `save_now` with these versions:

```gdscript
static func load_now() -> void:
	_loaded = true
	var loaded := _read(path)
	if loaded.is_empty():
		loaded = _read(bak)            # primary unreadable/corrupt → try the backup
	data = _merge(_default(), loaded)
	save_now()

static func save_now() -> void:
	data["schema_version"] = SCHEMA_VERSION
	var text := JSON.stringify(data, "  ")
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(text)
	f.close()
	if _read(tmp).is_empty():               # verify the temp file re-parses
		return
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return
	if FileAccess.file_exists(path):
		dir.rename(path.get_file(), bak.get_file())   # keep last-good as backup
	dir.rename(tmp.get_file(), path.get_file())        # atomic swap-in
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `/opt/homebrew/bin/godot --headless -s res://tests/save_tests.gd`
Expected: `== 3 passed, 0 failed ==`.

- [ ] **Step 5: Commit**

```bash
git add scripts/save.gd tests/save_tests.gd
git commit -m "feat(save): .bak backup rotation + corruption fallback"
```

---

### Task 3: Currency spend + stats + per-job records

**Files:**
- Modify: `scripts/save.gd` (add accessors)
- Test: `tests/save_tests.gd`

- [ ] **Step 1: Write the failing test**

Add to `tests/save_tests.gd` before the final print:

```gdscript
	# 4. spend
	fresh("spend")
	Save.add_coins(100)
	ok(Save.spend(30) and Save.coins() == 70, "spend deducts when affordable")
	ok(not Save.spend(1000) and Save.coins() == 70, "spend refused when too poor")

	# 5. board-clear counter
	fresh("clears")
	Save.record_board_clear()
	Save.record_board_clear()
	ok(Save.boards_cleared() == 2, "record_board_clear increments")

	# 6. per-job best record
	fresh("jobs")
	Save.record_job("bedroom_01", 2, 5)
	Save.record_job("bedroom_01", 3, 4)     # better run
	Save.record_job("bedroom_01", 1, 9)     # worse run must not regress best
	var j := Save.job("bedroom_01")
	ok(int(j["best_stars"]) == 3 and int(j["best_drags"]) == 4 and int(j["plays"]) == 3, \
		"record_job keeps best stars/drags + play count")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `/opt/homebrew/bin/godot --headless -s res://tests/save_tests.gd`
Expected: FAIL — `Invalid call. Nonexistent function 'spend' in base ...` (methods not defined).

- [ ] **Step 3: Write the implementation**

In `scripts/save.gd`, add to the accessors section (after `add_coins`):

```gdscript
static func spend(n: int, _reason := "") -> bool:
	_ensure_loaded()
	if coins() < n:
		return false
	data["currencies"]["coins"] = coins() - n
	save_now()
	return true

static func boards_cleared() -> int:
	_ensure_loaded()
	return int(data["stats"]["boards_cleared"])

static func record_board_clear(n := 1) -> void:
	_ensure_loaded()
	data["stats"]["boards_cleared"] = boards_cleared() + n
	save_now()

static func record_job(id: String, stars: int, drags: int) -> void:
	_ensure_loaded()
	var jobs: Dictionary = data["jobs"]
	var j: Dictionary = jobs.get(id, {
		"best_stars": 0, "best_drags": -1, "completed": false, "plays": 0, "first_clear_paid": false,
	})
	j["plays"] = int(j["plays"]) + 1
	j["completed"] = true
	j["best_stars"] = maxi(int(j["best_stars"]), stars)
	var bd := int(j["best_drags"])
	j["best_drags"] = drags if bd < 0 else mini(bd, drags)
	jobs[id] = j
	save_now()

static func job(id: String) -> Dictionary:
	_ensure_loaded()
	return data["jobs"].get(id, {})
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `/opt/homebrew/bin/godot --headless -s res://tests/save_tests.gd`
Expected: `== 7 passed, 0 failed ==`.

- [ ] **Step 5: Commit**

```bash
git add scripts/save.gd tests/save_tests.gd
git commit -m "feat(save): spend, board-clear counter, per-job best records"
```

---

### Task 4: One-time migration from legacy progress.cfg

**Files:**
- Modify: `scripts/save.gd` (`load_now`, add `_migrate_legacy`)
- Test: `tests/save_tests.gd`

- [ ] **Step 1: Write the failing test**

Add to `tests/save_tests.gd` before the final print:

```gdscript
	# 7. migrate a legacy progress.cfg, exactly once
	fresh("migrate")
	var c := ConfigFile.new()
	c.set_value("progress", "cleared", 5)
	c.save(Save.legacy)                      # temp legacy file (NOT the real one)
	Save._loaded = false
	Save.load_now()
	ok(Save.boards_cleared() == 5, "migration carries over boards_cleared")
	ok(Save.coins() == 5 * Save.COINS_PER_CLEAR_SEED, "migration seeds coins from past clears")
	ok(bool(Save.data["migrated_v2"]), "migration sets the once-guard")
	var after := Save.coins()
	Save._loaded = false
	Save.load_now()                          # reloading must NOT re-grant
	ok(Save.coins() == after, "migration does not double-grant on reload")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `/opt/homebrew/bin/godot --headless -s res://tests/save_tests.gd`
Expected: FAIL — `migration carries over boards_cleared` (boards_cleared 0, coins 0; no migration runs yet).

- [ ] **Step 3: Write the implementation**

In `scripts/save.gd`, replace `load_now` with this version (adds the legacy hook), and add `_migrate_legacy`:

```gdscript
static func load_now() -> void:
	_loaded = true
	var loaded := _read(path)
	if loaded.is_empty():
		loaded = _read(bak)
	data = _merge(_default(), loaded)
	# First run with a legacy progress.cfg present and not yet migrated → carry it over once.
	if not bool(data["migrated_v2"]) and FileAccess.file_exists(legacy):
		_migrate_legacy()
	save_now()

static func _migrate_legacy() -> void:
	var c := ConfigFile.new()
	var cleared := 0
	if c.load(legacy) == OK:
		cleared = int(c.get_value("progress", "cleared", 0))
	data["stats"]["boards_cleared"] = cleared
	data["currencies"]["coins"] = coins_raw() + cleared * COINS_PER_CLEAR_SEED
	data["migrated_v2"] = true
```

Also add this tiny helper (used by `_migrate_legacy` to read coins without triggering `_ensure_loaded` re-entrancy during load):

```gdscript
static func coins_raw() -> int:
	return int(data["currencies"]["coins"])
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `/opt/homebrew/bin/godot --headless -s res://tests/save_tests.gd`
Expected: `== 11 passed, 0 failed ==`.

- [ ] **Step 5: Commit**

```bash
git add scripts/save.gd tests/save_tests.gd
git commit -m "feat(save): one-time migration from legacy progress.cfg"
```

---

### Task 5: Stable string IDs on every level

**Files:**
- Modify: `scripts/levels.gd` (add `"id"` to each of the 6 level dicts)
- Test: `tests/save_tests.gd`

- [ ] **Step 1: Write the failing test**

Add to the top of `tests/save_tests.gd` (after the `Save` preload line):

```gdscript
const Levels = preload("res://scripts/levels.gd")
```

And add this block before the final print in `_initialize`:

```gdscript
	# 8. every level has a unique, stable string id
	var ids := {}
	var all_have_id := true
	for lv in Levels.LEVELS:
		if not lv.has("id") or String(lv["id"]) == "":
			all_have_id = false
		else:
			ids[String(lv["id"])] = true
	ok(all_have_id, "every level has a non-empty id")
	ok(ids.size() == Levels.LEVELS.size(), "all level ids are unique")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `/opt/homebrew/bin/godot --headless -s res://tests/save_tests.gd`
Expected: FAIL — `every level has a non-empty id`.

- [ ] **Step 3: Add the ids**

In `scripts/levels.gd`, add an `"id"` field to each level dict, right above its `"name"`. The six ids, in order:

```gdscript
"id": "bedroom_01",   # above "name": "1 • Tidy two socks"
"id": "bedroom_02",   # above "name": "2 • Slide it over"
"id": "bedroom_03",   # above "name": "3 • Fold the pile"
"id": "bedroom_04",   # above "name": "4 • The tricky corner"
"id": "bedroom_05",   # above "name": "5 • Shelve the books"
"id": "bedroom_06",   # above "name": "6 • Sort the toy bin"
```

For example the first dict becomes:

```gdscript
	{
		"id": "bedroom_01",
		"name": "1 • Tidy two socks",
		"rows": 3, "cols": 3, "top": 1, "par": 1,
		"grid": [
			0,   0,   0,
			0, 101, 101,
			0,   0,   0,
		],
		"hint": "Flick a sock toward its glowing twin — two together get tidied away. Clear the board to finish!",
	},
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `/opt/homebrew/bin/godot --headless -s res://tests/save_tests.gd`
Expected: `== 13 passed, 0 failed ==`.

- [ ] **Step 5: Commit**

```bash
git add scripts/levels.gd tests/save_tests.gd
git commit -m "feat(levels): stable string ids for save records"
```

---

### Task 6: Route Progress through Save (no second persistence)

**Files:**
- Modify: `scripts/progress.gd` (delegate to Save; stop touching `progress.cfg`)
- Test: `tests/save_tests.gd`, plus the existing `tests/smoke.gd` (must still pass)

The existing callers stay untouched: `main.gd` writes via `Progress.add_cleared(1)` (line ~530) and `room.gd` reads `Progress.cleared()` / `Progress.tidiness()`. We repoint `progress.gd` itself so those calls flow into `Save`, eliminating the duplicate `progress.cfg` writer.

- [ ] **Step 1: Write the failing test**

Add to the top of `tests/save_tests.gd` (after the `Levels` preload):

```gdscript
const Progress = preload("res://scripts/progress.gd")
```

And add before the final print:

```gdscript
	# 9. Progress shim reflects Save and writes through it
	fresh("shim")
	Progress.add_cleared(3)
	ok(Progress.cleared() == 3, "Progress.cleared reads Save")
	ok(Save.boards_cleared() == 3, "Progress.add_cleared writes through Save")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `/opt/homebrew/bin/godot --headless -s res://tests/save_tests.gd`
Expected: FAIL — `Progress.add_cleared writes through Save` (the current shim writes `progress.cfg`, not Save, so `Save.boards_cleared()` stays 0; `Progress.cleared()` may also mismatch since it reads the legacy file). NOTE: this pre-implementation run briefly writes the real `user://progress.cfg` (the old code's fixed path) — harmless dev-local data, eliminated by Step 3.

- [ ] **Step 3: Rewrite the shim**

Replace the entire contents of `scripts/progress.gd` with:

```gdscript
extends RefCounted
## Read/delegate shim over Save (the single persistence owner). Kept so existing callers
## (main.gd, room.gd) work unchanged; all state now lives in Save — progress.cfg is never
## written again (Save reads it once, for migration only).

const Palette = preload("res://scripts/palette.gd")
const Save = preload("res://scripts/save.gd")

static func cleared() -> int:
	return Save.boards_cleared()

static func add_cleared(n: int = 1) -> void:
	Save.record_board_clear(n)

## 0.0 → 1.0 how tidy the bedroom is.
static func tidiness() -> float:
	return clampf(float(Save.boards_cleared()) / float(Palette.ROOM_TARGET), 0.0, 1.0)
```

- [ ] **Step 4: Run the Save tests to verify they pass**

Run: `/opt/homebrew/bin/godot --headless -s res://tests/save_tests.gd`
Expected: `== 15 passed, 0 failed ==`.

- [ ] **Step 5: Run the smoke test to verify nothing regressed**

Run: `/opt/homebrew/bin/godot --headless -s res://tests/smoke.gd`
Expected: all lines `-> OK` (`SMOKE`, `ART`, `SWIPE`, `DRAG`, `ZERO`, `MENU`, `ROOM`), exit 0. (`main.gd`/`room.gd` are unmodified; they call `Progress.*`, now backed by `Save`.)

- [ ] **Step 6: Commit**

```bash
git add scripts/progress.gd tests/save_tests.gd
git commit -m "refactor(progress): delegate to Save, drop progress.cfg writes"
```

---

### Task 7: Full verification pass

**Files:** none (verification only)

- [ ] **Step 1: Run all three headless suites**

```bash
cd /Users/xup/mobile_game
/opt/homebrew/bin/godot --headless -s res://tests/run_tests.gd
/opt/homebrew/bin/godot --headless -s res://tests/save_tests.gd
/opt/homebrew/bin/godot --headless -s res://tests/smoke.gd
```

Expected:
- `run_tests.gd` → `== 9 passed, 0 failed ==` (rules engine untouched).
- `save_tests.gd` → `== 15 passed, 0 failed ==`.
- `smoke.gd` → all `-> OK`.

- [ ] **Step 2: Real-run sanity (migration of any existing progress.cfg)**

Render the menu once so the game boots through `Save` with the real `user://` paths:

Run: `/opt/homebrew/bin/godot --path . -s res://tools/screenshot.gd -- res://scenes/Menu.tscn /tmp/tu_save_check.png`
Expected: `SHOT saved=...`, no GDScript errors. If a real `user://progress.cfg` existed, `user://save.json` now exists with `migrated_v2: true` and seeded coins.

- [ ] **Step 3: Confirm the live save file is well-formed**

```bash
/opt/homebrew/bin/godot --headless --path . -s /dev/stdin <<'EOF' 2>&1 | grep SAVE || true
extends SceneTree
const Save = preload("res://scripts/save.gd")
func _initialize():
	print("SAVE keys=", Save.data.keys(), " coins=", Save.coins(), " cleared=", Save.boards_cleared())
	quit()
EOF
```

Expected: a `SAVE keys=[...] coins=N cleared=M` line printing the live save. (If `/dev/stdin` fails to load in your Godot build — a known flake — write the snippet to `tools/_savecheck.gd`, run it, then delete it.)

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "test(save): full M1-part-1 verification green" --allow-empty
```

---

## Self-review notes (for the implementer)

- **Spec coverage:** versioned JSON ✓ (Task 1), atomic write + `.bak` ✓ (Task 2), deep-merge for additive growth ✓ (Task 1 `_merge`), corruption fallback ✓ (Task 2), spend/stats/jobs accessors ✓ (Task 3), once-guarded legacy migration with coin seed ✓ (Task 4), stable level ids ✓ (Task 5), `progress.gd` read-only-ish shim / no double-write ✓ (Task 6). Deferred (own later plans): forced flush on `APPLICATION_PAUSED`/`WM_CLOSE_REQUEST` (needs a tree node — lands with the FX autoload or a tiny lifecycle node), `crc`, the full schema (`rooms`/`quests`/`streak`/`settings` keys), and 04:00 daily rollover.
- **Type consistency:** `coins()/add_coins/spend`, `boards_cleared()/record_board_clear`, `record_job(id,stars,drags)/job(id)`, `configure_for_test(dir)`, statics `path/bak/tmp/legacy/data/_loaded` — names are identical across all tasks and the shim.
- **No-placeholder check:** every step has runnable code and exact commands; no TBD/TODO.
