# Tidy Up (Donguri Merge) — common commands.
# Override the Godot binary if it isn't on PATH:  make test GODOT=/opt/homebrew/bin/godot
GODOT   ?= godot
PROJECT := .
QUIET   := engine/tools/quiet_godot.sh
JOBS    ?= 4                                  # parallel suites; 4 avoids over-subscribing cores
RUNNER  := engine/tools/run_suites.py         # parallel runner + per-suite timing table
ENGINE_TESTS := engine/tests/save_tests engine/tests/inbox_tests engine/tests/mechanics_tests engine/tests/layering_tests engine/tests/quest_tests engine/tests/quest_fence_tests engine/tests/calm_tests engine/tests/mapfx_tests engine/tests/ghost_preview_tests engine/tests/hint_tests engine/tests/gate_unveil_tests engine/tests/gendim_tests engine/tests/floater_tests engine/tests/ftue_pop_tests engine/tests/spotlight_tests engine/tests/featured_tests engine/tests/anchor_tests engine/tests/palette_tests engine/tests/level_badge_tests
# the grove suite was split from one 2.3k-line monolith into focused suites so they
# parallelise and you can run just the slice you touched (see games/grove/tests/grove_test_base.gd)
GROVE_TESTS  := games/grove/tests/grove_model_tests games/grove/tests/grove_economy_tests games/grove/tests/grove_ui_tests games/grove/tests/grove_placement_tests games/grove/tests/grove_shop_ads_tests
TESTS        := $(ENGINE_TESTS) $(GROVE_TESTS)
export GODOT JOBS                             # so $(RUNNER) (a python script) sees them

.DEFAULT_GOAL := help

.PHONY: help run run_debug run_grove editor test test-fast test-engine test-grove test-one smoke import \
        shot-map shot-grove shot \
        decor icon ios clean clean-cache intake intake-test

help: ## list available targets
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

## --- run -------------------------------------------------------------------
## Which game runs is the GAME env var (see games/active.gd). `run` uses the
## default (grove); the ones below force the game and toggle the grove-art import.
run: ## play the active game (GAME env var, default grove)
	$(GODOT) --path $(PROJECT)


debug: ## play the active game (default grove) WITH the debug panel + toggles
	rm -f games/grove/assets/.gdignore
	GAME=$${GAME:-grove} $(GODOT) --path $(PROJECT) -- debug

grove: ## play the GROVE game (full art; first run imports grove art)
	rm -f games/grove/assets/.gdignore
	GAME=grove $(GODOT) --path $(PROJECT)

editor: ## open the project in the Godot editor
	$(GODOT) -e --path $(PROJECT)

## --- tests (headless, no window; parallel — override with JOBS=N) ----------
## INNER LOOP: run `make test-fast` after EVERY change (engine suites, a few seconds).
## Run the full `make test` (adds the grove game suites) before you commit / hand off.
## Suites run in parallel via $(RUNNER), which prints a per-suite timing table and
## fails on any FAIL / crash (it never trusts a zero exit code alone).
test-fast: ## ⚡ inner-loop check — engine suites only, parallel. USE THIS AFTER EVERY CHANGE.
	@python3 $(RUNNER) $(ENGINE_TESTS)

test: ## full sweep: every suite (engine + grove), parallel + per-suite timing table
	@python3 $(RUNNER) $(TESTS)

test-engine: ## only the base-engine suites (parallel)
	@python3 $(RUNNER) $(ENGINE_TESTS)

test-grove: ## only the grove game suites (parallel)
	@python3 $(RUNNER) $(GROVE_TESTS)

test-one: ## run one suite by path:  make test-one SUITE=engine/tests/save_tests
	$(GODOT) --headless --path $(PROJECT) -s res://$(SUITE).gd

smoke: ## scene smoke test (instantiates the UI + board)
	$(GODOT) --headless --path $(PROJECT) -s res://engine/tests/smoke.gd

## --- assets ----------------------------------------------------------------
import: ## (re)import assets after adding or changing art
	$(GODOT) --headless --path $(PROJECT) --import

intake: ## apply intake plans in assets/_new/ (agent authors plan.json first): make intake [PLAN=path]
	python3 games/tools/intake_apply.py --godot $(GODOT) $(if $(PLAN),--plan $(PLAN),)

intake-test: ## unit-test the intake runner (pure stdlib, no godot)
	python3 games/tools/test_intake_apply.py

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

commit:
	git add .
	git commit -m "changes"
	git push
