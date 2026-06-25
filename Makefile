# Acorn Forest: Merge! (Donguri Merge) — common commands.
# Override the Godot binary if it isn't on PATH:  make test GODOT=/opt/homebrew/bin/godot
GODOT   ?= godot
PROJECT := .
QUIET   := engine/tools/quiet_godot.sh
JOBS    ?= 4                                  # parallel suites; 4 avoids over-subscribing cores
RUNNER  := engine/tools/run_suites.py         # parallel runner + per-suite timing table
# Active suites = the core-logic / "basic coding functional" set. At this stage of development the
# UI + economy/liveops suites are PARKED in the *_DISABLED vars below — they churn with rapid UI/
# economy iteration and slow the loop without guarding stable code. To RE-ENABLE: move names back
# from *_DISABLED into the active lists. See docs/BACKLOG.md "Re-enable the UI + economy test suites".
ENGINE_TESTS := engine/tests/save_tests engine/tests/mechanics_tests engine/tests/quest_tests engine/tests/quest_fence_tests engine/tests/anchor_tests engine/tests/layering_tests engine/tests/inbox_sync_tests engine/tests/identity_tests engine/tests/store_tests engine/tests/iap_tests engine/tests/scene_warm_tests engine/tests/kit_config_cache_tests engine/tests/kit_polish_async_tests engine/tests/kit_bake_tests engine/tests/boot_trace_tests engine/tests/map_canvas_tests engine/tests/strings_tests engine/tests/level_badge_tests engine/tests/fx_juice_tests engine/tests/water_fill_effect_tests engine/tests/sfx_tests engine/tests/reward_arrival_tests
ENGINE_TESTS_DISABLED := engine/tests/inbox_tests engine/tests/login_tests engine/tests/calm_tests engine/tests/mapfx_tests engine/tests/hint_tests engine/tests/gendim_tests engine/tests/floater_tests engine/tests/palette_tests engine/tests/bag_overlay_tests engine/tests/switch_tests engine/tests/settings_kit_tests engine/tests/vault_kit_tests
# the grove suite was split from one 2.3k-line monolith into focused suites so they
# parallelise and you can run just the slice you touched (see games/grove/tests/grove_test_base.gd)
GROVE_TESTS  := games/grove/tests/grove_workbench_tests games/grove/tests/grove_vine_tests games/grove/tests/grove_shop_tests games/grove/tests/grove_fx_workbench_tests
GROVE_TESTS_DISABLED := games/grove/tests/grove_model_tests games/grove/tests/grove_economy_tests games/grove/tests/grove_ui_tests games/grove/tests/grove_placement_tests games/grove/tests/grove_vine_tool_tests
TESTS        := $(ENGINE_TESTS) $(GROVE_TESTS)
export GODOT JOBS                             # so $(RUNNER) (a python script) sees them

.DEFAULT_GOAL := help

.PHONY: help run run_debug run_grove editor workbench fx fx-workbench vine test test-fast test-engine test-grove test-one smoke import bake bake-textures bake-vine \
        shot-map shot-grove shot shot-workbench shot-fx-workbench \
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

g: ## play the GROVE game (full art; first run imports grove art)
	rm -f games/grove/assets/.gdignore
	GAME=grove $(GODOT) --path $(PROJECT)

editor: ## open the project in the Godot editor
	$(GODOT) -e --path $(PROJECT)

w: ## see + test the UI workbench live (a real window you can click)
	$(GODOT) --path $(PROJECT) -s res://games/grove/tools/ui_workbench.gd

fx: ## watch the breaking-glass FX live, looping (a real window; close it to quit):  make fx
	$(GODOT) --path $(PROJECT) -s res://engine/tools/fx_demo.gd

fx-workbench: ## see + tune Grove FX live (sidebar list + contextual preview)
	$(GODOT) --path $(PROJECT) -s res://games/grove/tools/fx_workbench.gd

vine: ## edit a map's vine-overgrowth mask regions live (a real window):  make vine
	$(GODOT) --path $(PROJECT) res://games/tools/vine_mask_tool/VineMaskTool.tscn

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

bake: bake-textures bake-vine   ## pre-bake every runtime art cache: kit texture polish + vine region maps

bake-textures: ## pre-bake the runtime defringe/feather polish (auto-discovered from every kit dialog) so dialogs open without the first-use hitch
	$(GODOT) --headless --path $(PROJECT) -s res://games/tools/bake_textures.gd
	$(GODOT) --headless --path $(PROJECT) --import

bake-vine: ## pre-bake the warped vine region-index maps (auto-discovered from every vine map) so the first home render skips the ~1.1s raster
	$(GODOT) --headless --path $(PROJECT) -s res://games/tools/bake_vine_region_maps.gd
	$(GODOT) --headless --path $(PROJECT) --import

intake: ## apply intake plans in assets/_new/ (agent authors plan.json first): make intake [PLAN=path]
	python3 games/tools/intake_apply.py --godot $(GODOT) $(if $(PLAN),--plan $(PLAN),)

intake-test: ## unit-test the intake runner (pure stdlib, no godot)
	python3 games/tools/test_intake_apply.py

sfx: ## bake the synth SFX palette into games/grove/assets/music/sfx/ then import
	python3 -m tools.sfx_synth.bake
	$(GODOT) --headless --path $(PROJECT) --import

sfx-test: ## pure-python tests for the SFX generator (no godot)
	python3 -m tools.sfx_synth.test_synth

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

shot-workbench: ## quiet screenshot of the UI workbench:  make shot-workbench [OUT=/tmp/ui_workbench.png] [EL=mystery]
	$(QUIET) --path $(PROJECT) -s res://games/grove/tools/ui_workbench.gd -- $(or $(OUT),/tmp/ui_workbench.png) $(EL)

shot-fx-workbench: ## quiet screenshot of the FX workbench:  make shot-fx-workbench [OUT=/tmp/fx_workbench.png]
	$(QUIET) --path $(PROJECT) -s res://games/grove/tools/fx_workbench.gd -- $(or $(OUT),/tmp/fx_workbench.png)

## --- iOS -------------------------------------------------------------------
ios-plugins: ## fetch the Apple-services plugin (Game Center + StoreKit) into addons/ (per-checkout; pinned)
	tools/install_ios_plugins.sh

ios: ios-plugins ## export the iOS Xcode project to build/ios (needs export templates + Xcode; see docs/design/apple-services-setup.md)
	mkdir -p build/ios
	find build/ios -mindepth 1 -maxdepth 1 ! -name ci_scripts -exec rm -rf {} +
	$(GODOT) --headless --path $(PROJECT) --export-debug "iOS" build/ios/AcornForest.xcodeproj
	# Godot's template forces empty camera/photo/mic usage strings — strip them (App Store rejects blanks).
	tools/strip_unused_ios_permissions.sh build/ios/AcornForest/AcornForest-Info.plist
	# Godot pins "Apple Distribution" on Release under automatic signing — Xcode rejects that. Fix to "Apple Development".
	tools/normalize_ios_signing.sh build/ios/AcornForest.xcodeproj/project.pbxproj

## --- clean -----------------------------------------------------------------
clean: ## remove the gitignored build/ output
	if [ -d build ]; then find build -mindepth 1 -maxdepth 1 ! -name ios -exec rm -rf {} +; fi
	if [ -d build/ios ]; then find build/ios -mindepth 1 -maxdepth 1 ! -name ci_scripts -exec rm -rf {} +; fi

clean-cache: ## remove the Godot import cache (forces a full reimport next run)
	rm -rf .godot

c:
	git add .
	git commit -m "changes"
	git push

l:
	git worktree list
