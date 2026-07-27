# Acorn Forest: Merge! (Donguri Merge) — common commands.
# Override the Godot binary if it isn't on PATH:  make test GODOT=/opt/homebrew/bin/godot
GODOT   ?= godot
PROJECT := .
QUIET   := engine/tools/quiet_godot.sh
JOBS    ?= 4                                  # parallel suites; 4 avoids over-subscribing cores
RUNNER  := engine/tools/run_suites.py         # parallel runner + per-suite timing table
DEVICE  ?=                                    # desktop phone simulator for make g, e.g. DEVICE=393x852
# Suites = the pure code-logic set. The UI / FX / layout / scene-display suites were removed;
# these guard game rules, model, economy, persistence, quest logic, store/IAP, and identity.
ENGINE_TESTS := engine/tests/save_tests engine/tests/mechanics_tests engine/tests/quest_tests engine/tests/quest_fence_tests engine/tests/layering_tests engine/tests/inbox_sync_tests engine/tests/identity_tests engine/tests/build_info_tests engine/tests/store_tests engine/tests/iap_tests engine/tests/scene_warm_tests engine/tests/kit_config_cache_tests engine/tests/boot_trace_tests engine/tests/strings_tests engine/tests/bust_tests engine/tests/tuning_tests engine/tests/resident_bucket_tests engine/tests/bucket_adapter_tests engine/tests/scene_cells_tests engine/tests/hint_tests engine/tests/action_button_tests engine/tests/ftue_hand_hint_tests engine/tests/update_check_tests engine/tests/asset_size_guard_tests engine/tests/cluster_manifest_tests engine/tests/palette_ssot_tests engine/tests/modal_dismiss_tests engine/tests/suite_registry_tests engine/tests/fx_config_tests engine/tests/const_ssot_tests engine/tests/feature_flag_registry_tests
ENGINE_TESTS_DISABLED :=
# the grove suite was split from one 2.3k-line monolith into focused suites so they
# parallelise and you can run just the slice you touched (see games/grove/tests/grove_test_base.gd)
GROVE_TESTS  := games/grove/tests/grove_board_actions_tests games/grove/tests/grove_explore_tests games/grove/tests/grove_scene_workbench_tests games/grove/tests/grove_scene_covers_tests games/grove/tests/grove_shop_tests games/grove/tests/grove_ui_workbench_tests games/grove/tests/grove_ftue_tests games/grove/tests/grove_rush_ftue_tests
GROVE_TESTS_DISABLED :=
# dev-tool suites — pure-Image logic for the asset intake pipeline (fast, no scenes)
TOOLS_TESTS  := games/tools/tests/slice_islands_tests
TESTS        := $(ENGINE_TESTS) $(TOOLS_TESTS) $(GROVE_TESTS)
# Non-Godot guards — plain python/bash, seconds at most, run via `make test-config` (which
# `make test` depends on). Two kinds live here:
#   • SHIPPING-config guards (splash + launch storyboard, the build-info stamper, the Xcode
#     Cloud clone hook) — stdlib only, milliseconds, and they read only committed files
#     (build/ios/ci_scripts/ci_post_clone.sh is tracked — un-ignored by .gitignore's
#     negations — and none of them touch gitignored engine/generated/), so they are safe on
#     a clean checkout and in CI.
#   • ASSET-PIPELINE guards for the python image tools (composite baker, meadow-UI
#     extractor). These are NOT stdlib-only — they need Pillow / numpy / scipy, the same
#     deps the intake pipeline already requires. They build their fixtures in tempdirs and
#     touch no repo files.
# Every suite here is run with PYTHONPATH=. so package-style imports
# (`from games.grove.tools.… import …`) resolve from the repo root; run bare, those fail
# with ModuleNotFoundError because sys.path[0] is the test's own directory.
#   • TOOL-PIPELINE suites that used to hang off their own targets only (`make intake-test`,
#     `make sfx-test`) and so were absent from the sweep everyone actually runs. Both are fast
#     (~0.05s and ~0.6s) and build their fixtures in tempdirs, so they are folded in here; the
#     two targets stay as shortcuts. engine/tests/suite_registry_tests.gd now asserts this list
#     covers every python suite on disk, so the next one cannot sit unrun.
PY_TESTS     := tools/test_boot_splash_assets.py \
                games/grove/tests/bake_scene_composites_tests.py \
                games/grove/tools/tests/test_extract_meadow_ui_v2.py \
                games/tools/test_intake_apply.py \
                tools/sfx_synth/test_synth.py
SH_TESTS     := tools/test_stamp_build_info.sh tools/test_xcode_cloud_ci.sh
export GODOT JOBS                             # so $(RUNNER) (a python script) sees them

.DEFAULT_GOAL := help

.PHONY: help run g-phone editor fx test test-fast test-config test-engine test-grove test-one smoke import bake bake-textures \
        shot-map shot-grove shot-widget shot shot-workbench shot-fx-workbench sw shot-sw \
        decor icon ios release-ios get-ios clean clean-cache intake intake-test

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

g: ## play the GROVE game (full art; use DEVICE=393x852 to mimic a phone viewport)
	rm -f games/grove/assets/.gdignore
	GROVE_DEVICE_POINTS="$(DEVICE)" GAME=grove $(GODOT) --path $(PROJECT)

g-phone: ## play Grove in an iPhone-ish point viewport (same as make g DEVICE=393x852)
	$(MAKE) g DEVICE=393x852

editor: ## open the project in the Godot editor
	$(GODOT) -e --path $(PROJECT)

w: ## see + test the UI workbench live (a real window you can click)
	$(GODOT) --path $(PROJECT) -s res://games/grove/tools/ui_workbench.gd

sw: ## place + fine-tune a picture-book scene (drag/resize/wheel/z, clusters; ⌘S saves):  make sw [SCENE=sakura] [CLUSTER=<name>] [ROOT=<scenes dir>]
	$(GODOT) --path $(PROJECT) -s res://games/grove/tools/scene_workbench.gd -- $(or $(SCENE),sakura) $(or $(ROOT),auto) $(or $(CLUSTER),none)

shot-sw: ## quiet screenshot of the scene workbench:  make shot-sw [SCENE=...] [CLUSTER=...] [OUT=/tmp/scene_workbench.png]
	$(QUIET) --path $(PROJECT) -s res://games/grove/tools/scene_workbench.gd -- $(or $(SCENE),sakura) $(or $(ROOT),auto) $(or $(CLUSTER),none) $(or $(OUT),/tmp/scene_workbench.png)

fx: ## see + tune every Grove FX live — the feel verbs (land · merge · launch · move · grab), the Expedition juice, and the reward flight
	$(GODOT) --path $(PROJECT) -s res://games/grove/tools/fx_workbench.gd

## --- tests (headless, no window; parallel — override with JOBS=N) ----------
## INNER LOOP: run `make test-fast` after EVERY change (engine suites, a few seconds).
## Run the full `make test` (adds the grove game suites) before you commit / hand off.
## Suites run in parallel via $(RUNNER), which prints a per-suite timing table and
## fails on any FAIL / crash (it never trusts a zero exit code alone).
test-fast: ## ⚡ inner-loop check — engine + tool suites, parallel. USE THIS AFTER EVERY CHANGE.
	@python3 $(RUNNER) $(ENGINE_TESTS) $(TOOLS_TESTS)

test: test-config ## full sweep: config guards + every suite (engine + grove), parallel + per-suite timing table
	@python3 $(RUNNER) $(TESTS)

test-config: ## non-godot guards (splash, build-info stamp, Xcode Cloud hook, asset-pipeline image tools)
	@set -e; \
	for t in $(PY_TESTS); do echo "== $$t"; PYTHONPATH=$(PROJECT) python3 $$t; done; \
	for t in $(SH_TESTS); do echo "== $$t"; bash $$t; done

test-engine: ## only the base-engine suites (parallel)
	@python3 $(RUNNER) $(ENGINE_TESTS)

test-grove: ## only the grove game suites (parallel)
	@python3 $(RUNNER) $(GROVE_TESTS)

# Goes through $(RUNNER) like every other test target, so a single suite is judged by the
# SAME rules as the full sweep: it passes only on "== N passed, 0 failed ==" with exit 0 and
# ZERO `SCRIPT ERROR`, and a suite that aborts mid-`_initialize()` (never reaching quit()) is
# killed by the hang guard and reported, instead of idling forever. Running godot directly
# here trusted the raw exit code, which is 0 for a suite that logged failures — so the one
# command you reach for when debugging was the one that could not fail honestly.
test-one: ## run one suite by path:  make test-one SUITE=engine/tests/save_tests
	@python3 $(RUNNER) $(SUITE)

smoke: ## scene smoke test (instantiates the UI + board)
	$(GODOT) --headless --path $(PROJECT) -s res://engine/tests/smoke.gd

## --- assets ----------------------------------------------------------------
import: ## (re)import assets after adding or changing art
	$(GODOT) --headless --path $(PROJECT) --import

bake: bake-textures   ## pre-bake every runtime art cache: kit texture polish

bake-textures: ## pre-bake the runtime defringe/feather polish (auto-discovered from every kit dialog) so dialogs open without the first-use hitch
	$(GODOT) --headless --path $(PROJECT) -s res://games/tools/bake_textures.gd
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

shot-grove: ## capture the board (byte-deterministic per MODE):  make shot-grove [MODE=fresh|played|gate|hud|fullline] [OUT=/tmp/grove.png]
	$(QUIET) --path $(PROJECT) -s res://games/grove/tools/grove_shot.gd -- $(or $(MODE),hud) $(or $(OUT),/tmp/grove.png)

shot-widget: ## render board widgets in isolation (SEE a UI change cheaply):  make shot-widget OUT=/tmp/w.png TILES="104 104:glow"
	$(QUIET) --path $(PROJECT) -s res://games/grove/tools/widget_shot.gd -- $(or $(OUT),/tmp/widget.png) $(TILES)

shot: ## any quiet capture by path:  make shot TOOL=games/grove/tools/grove_shot ARGS="hud /tmp/x.png"
	$(QUIET) --path $(PROJECT) -s res://$(TOOL).gd -- $(ARGS)

shot-workbench: ## quiet screenshot of the UI workbench:  make shot-workbench [OUT=/tmp/ui_workbench.png] [EL=mystery]
	$(QUIET) --path $(PROJECT) -s res://games/grove/tools/ui_workbench.gd -- $(or $(OUT),/tmp/ui_workbench.png) $(EL)

shot-fx-workbench: ## quiet screenshot of the FX workbench:  make shot-fx-workbench [OUT=/tmp/fx_workbench.png] [EL=merge_fx]
	$(QUIET) --path $(PROJECT) -s res://games/grove/tools/fx_workbench.gd -- $(or $(OUT),/tmp/fx_workbench.png) $(EL)

## --- iOS -------------------------------------------------------------------
# `make ios 1.2.3` / `make release-ios 1.2.3` pass the version as a positional goal (also accepts
# VERSION=1.2.3). `make release-ios patch|minor|major` instead auto-bumps the last UPLOADED version.
# The leftover goal(s) after the iOS targets are taken as that arg; when an iOS target is requested we
# stub them as no-op targets so make doesn't error with "No rule to make target '1.2.3'" (scoped to iOS
# runs, so a typo'd target in any other command still errors normally).
IOS_ARGS    := $(filter-out ios ios-plugins release-ios get-ios,$(MAKECMDGOALS))
IOS_VERSION := $(or $(VERSION),$(IOS_ARGS))
# Which Godot export template the Xcode project links. `debug` keeps the remote debugger
# for on-device iteration; `release` is smaller and is what ships. `release-ios` overrides
# this — never hand a debug template to App Store Connect.
IOS_EXPORT_MODE ?= debug
ifneq (,$(filter ios release-ios,$(MAKECMDGOALS)))
ifneq (,$(IOS_ARGS))
$(eval $(IOS_ARGS):;@:)
endif
endif

ios-plugins: ## fetch the Apple-services plugin (Game Center + StoreKit) into addons/ (per-checkout; pinned)
	tools/install_ios_plugins.sh

ios: ios-plugins ## export iOS Xcode project to build/ios; `make ios 1.2.3` sets the app version (see docs/design/apple-services-setup.md)
	mkdir -p build/ios
	find build/ios -mindepth 1 -maxdepth 1 ! -name ci_scripts -exec rm -rf {} +
	tools/stamp_build_info.sh engine/generated/build_info.gd $(IOS_VERSION)
	tools/export_ios.sh $(PROJECT) build/ios/AcornForest.xcodeproj $(IOS_EXPORT_MODE)
	# The main preset excludes games/grove/assets/**, so the pack above is code + data only.
	# Build the art/audio half separately and reference it from the Xcode project; boot.gd
	# mounts it at startup. Keeping art in its own byte-stable pack is what lets a code-only
	# update ship ~6 MB instead of the whole game.
	tools/export_asset_pack.sh $(PROJECT) build/ios/grove_assets.pck
	tools/add_asset_pack_to_xcode.py build/ios/AcornForest.xcodeproj/project.pbxproj
	# Godot's template forces empty camera/photo/mic usage strings — strip them (App Store rejects blanks).
	tools/strip_unused_ios_permissions.sh build/ios/AcornForest/AcornForest-Info.plist
	# Godot pins "Apple Distribution" on Release under automatic signing — Xcode rejects that. Fix to "Apple Development".
	tools/normalize_ios_signing.sh build/ios/AcornForest.xcodeproj/project.pbxproj
	# `make ios 1.2.3` -> app version 1.2.3; bare `make ios` keeps export_presets' version (Xcode Cloud
	# auto-sets the build number from $$CI_BUILD_NUMBER). See tools/set_ios_version.sh.
	tools/set_ios_version.sh build/ios/AcornForest.xcodeproj/project.pbxproj $(IOS_VERSION)

release-ios: ## archive + upload to App Store Connect/TestFlight: make release-ios <patch|minor|major|X.Y.Z>
	@test -n "$(strip $(IOS_VERSION))" || { echo "usage: make release-ios <patch|minor|major|X.Y.Z>"; exit 1; }
	@set -e; \
	v="$(IOS_VERSION)"; \
	case "$$v" in major|minor|patch) v="$$(tools/next_ios_version.sh "$$v")";; esac; \
	echo "==> Releasing version $$v"; \
	$(MAKE) ios VERSION="$$v" IOS_EXPORT_MODE=release; \
	tools/release_ios.sh "$$v"

get-ios: ## print the last version/build uploaded to App Store Connect (needs the API key)
	tools/get_ios_version.sh

## --- clean -----------------------------------------------------------------
clean: ## remove the gitignored build/ output
	if [ -d build ]; then find build -mindepth 1 -maxdepth 1 ! -name ios -exec rm -rf {} +; fi
	if [ -d build/ios ]; then find build/ios -mindepth 1 -maxdepth 1 ! -name ci_scripts -exec rm -rf {} +; fi

clean-cache: ## remove the Godot import cache (forces a full reimport next run)
	rm -rf .godot

c:
	git add .
	git commit -m "changes"

l:
	git worktree list
