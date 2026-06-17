# Tidy Up (Donguri Merge) — common commands.
# Override the Godot binary if it isn't on PATH:  make test GODOT=/opt/homebrew/bin/godot
GODOT   ?= godot
PROJECT := .
QUIET   := engine/tools/quiet_godot.sh
ENGINE_TESTS := engine/tests/save_tests engine/tests/mechanics_tests engine/tests/layering_tests engine/tests/quest_tests engine/tests/quest_fence_tests engine/tests/calm_tests engine/tests/mapfx_tests engine/tests/ghost_preview_tests engine/tests/hint_tests engine/tests/gate_unveil_tests engine/tests/gendim_tests engine/tests/floater_tests engine/tests/ftue_pop_tests engine/tests/spotlight_tests engine/tests/featured_tests engine/tests/anchor_tests
GROVE_TESTS  := games/grove/tests/grove_tests
TESTS        := $(ENGINE_TESTS) $(GROVE_TESTS)

.DEFAULT_GOAL := help

.PHONY: help run run_base run_grove editor test test-engine test-grove test-one smoke import \
        shot-map shot-grove shot \
        decor icon ios clean clean-cache

help: ## list available targets
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

## --- run -------------------------------------------------------------------
## Which game runs is the GAME env var (see games/active.gd). `run` uses the
## default; the two below force one game and toggle the grove-art import-skip.
run: ## play the active game (GAME env var, default placeholder)
	$(GODOT) --path $(PROJECT)

run_base: ## play the BARE placeholder (wireframe engine + debug panel)
	touch games/grove/assets/.gdignore
	GAME=placeholder $(GODOT) --path $(PROJECT)

run: ## play the GROVE game (full art; first run imports grove art)
	rm -f games/grove/assets/.gdignore
	GAME=grove $(GODOT) --path $(PROJECT)

editor: ## open the project in the Godot editor
	$(GODOT) -e --path $(PROJECT)

## --- tests (headless, no window) ------------------------------------------
test: ## run every headless suite (engine + game)
	@for t in $(TESTS); do \
		echo "== $$t =="; \
		$(GODOT) --headless --path $(PROJECT) -s res://$$t.gd || exit 1; \
	done

test-engine: ## run only the base-engine suites
	@for t in $(ENGINE_TESTS); do \
		echo "== $$t =="; \
		$(GODOT) --headless --path $(PROJECT) -s res://$$t.gd || exit 1; \
	done

test-grove: ## run only the grove game suites
	@for t in $(GROVE_TESTS); do \
		echo "== $$t =="; \
		$(GODOT) --headless --path $(PROJECT) -s res://$$t.gd || exit 1; \
	done

test-one: ## run one suite by path:  make test-one SUITE=engine/tests/save_tests
	$(GODOT) --headless --path $(PROJECT) -s res://$(SUITE).gd

smoke: ## scene smoke test (instantiates the UI + board)
	$(GODOT) --headless --path $(PROJECT) -s res://engine/tests/smoke.gd

## --- assets ----------------------------------------------------------------
import: ## (re)import assets after adding or changing art
	$(GODOT) --headless --path $(PROJECT) --import

place: ## open the map-1 placement editor (drag cutouts onto the base, Ctrl+S to save — the game reads it live)
	GAME=grove $(GODOT) --path $(PROJECT) res://games/grove/tools/MapPlacer.tscn

decor: ## process a bg/decor raw:  make decor IN=/tmp/x.png OUT=res://assets/rooms/y.png W=2160 H=2880 [OPAQUE=1]
	$(GODOT) --headless --path $(PROJECT) -s res://games/tools/process_decor.gd -- "$(IN)" $(OUT) $(W) $(H) $(if $(OPAQUE),--opaque,)

icon: ## process an icon raw:  make icon IN=/tmp/x.png OUT=res://assets/ui/y.png SIZE=512
	$(GODOT) --headless --path $(PROJECT) -s res://games/tools/process_icon.gd -- "$(IN)" $(OUT) $(SIZE)

## --- screenshots (quiet: born minimized, never steals focus) ---------------
shot-map: ## capture the map:  make shot-map [MODE=fresh|interior|progress|shop|settings|spirits] [OUT=/tmp/map.png]
	$(QUIET) --path $(PROJECT) -s res://games/grove/tools/map_shot.gd -- $(or $(MODE),fresh) $(or $(OUT),/tmp/map.png)

shot-grove: ## capture the board:  make shot-grove [MODE=fresh|played|gate|hud|compost|hive] [OUT=/tmp/grove.png]
	$(QUIET) --path $(PROJECT) -s res://games/grove/tools/grove_shot.gd -- $(or $(MODE),hud) $(or $(OUT),/tmp/grove.png)

shot: ## any quiet capture by path:  make shot TOOL=games/grove/tools/grove_shot ARGS="hud /tmp/x.png"
	$(QUIET) --path $(PROJECT) -s res://$(TOOL).gd -- $(ARGS)

## --- iOS -------------------------------------------------------------------
ios: ## export the iOS Xcode project to build/ios (needs export templates + Xcode; see docs/iOS_BUILD.md)
	$(GODOT) --headless --path $(PROJECT) --export-debug "iOS" build/ios/ReachZero.xcodeproj

## --- clean -----------------------------------------------------------------
clean: ## remove the gitignored build/ output
	rm -rf build

clean-cache: ## remove the Godot import cache (forces a full reimport next run)
	rm -rf .godot
