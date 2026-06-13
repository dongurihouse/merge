# Tidy Up (Donguri Merge) — common commands.
# Override the Godot binary if it isn't on PATH:  make test GODOT=/opt/homebrew/bin/godot
GODOT   ?= godot
PROJECT := .
QUIET   := tools/quiet_godot.sh
TESTS   := core_tests grove_tests layout_tests map_tests quest_tests save_tests run_tests

.DEFAULT_GOAL := help

.PHONY: help run editor test test-one smoke import \
        shot-home shot-grove shot-map shot \
        decor icon ios clean clean-cache

help: ## list available targets
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

## --- run -------------------------------------------------------------------
run: ## play the game (desktop window)
	$(GODOT) --path $(PROJECT)

editor: ## open the project in the Godot editor
	$(GODOT) -e --path $(PROJECT)

## --- tests (headless, no window) ------------------------------------------
test: ## run every headless test suite
	@for t in $(TESTS); do \
		echo "== $$t =="; \
		$(GODOT) --headless --path $(PROJECT) -s res://tests/$$t.gd || exit 1; \
	done

test-one: ## run one suite:  make test-one SUITE=grove_tests
	$(GODOT) --headless --path $(PROJECT) -s res://tests/$(SUITE).gd

smoke: ## scene smoke test (instantiates the UI + board)
	$(GODOT) --headless --path $(PROJECT) -s res://tests/smoke.gd

## --- assets ----------------------------------------------------------------
import: ## (re)import assets after adding or changing art
	$(GODOT) --headless --path $(PROJECT) --import

decor: ## process a bg/decor raw:  make decor IN=/tmp/x.png OUT=res://assets/rooms/y.png W=2160 H=2880 [OPAQUE=1]
	$(GODOT) --headless --path $(PROJECT) -s res://tools/process_decor.gd -- "$(IN)" $(OUT) $(W) $(H) $(if $(OPAQUE),--opaque,)

icon: ## process an icon raw:  make icon IN=/tmp/x.png OUT=res://assets/ui/y.png SIZE=512
	$(GODOT) --headless --path $(PROJECT) -s res://tools/process_icon.gd -- "$(IN)" $(OUT) $(SIZE)

## --- screenshots (quiet: born minimized, never steals focus) ---------------
shot-home: ## capture Home:  make shot-home [MODE=fresh|interior|progress|shop|settings|spirits] [OUT=/tmp/home.png]
	$(QUIET) --path $(PROJECT) -s res://tools/home_shot.gd -- $(or $(MODE),fresh) $(or $(OUT),/tmp/home.png)

shot-grove: ## capture the board:  make shot-grove [MODE=fresh|played|gate|hud|compost|hive] [OUT=/tmp/grove.png]
	$(QUIET) --path $(PROJECT) -s res://tools/grove_shot.gd -- $(or $(MODE),hud) $(or $(OUT),/tmp/grove.png)

shot-map: ## capture the map:  make shot-map [MODE=fresh] [OUT=/tmp/map.png]
	$(QUIET) --path $(PROJECT) -s res://tools/map_shot.gd -- $(or $(MODE),fresh) $(or $(OUT),/tmp/map.png)

shot: ## any quiet capture:  make shot TOOL=grove_shot ARGS="hud /tmp/x.png"
	$(QUIET) --path $(PROJECT) -s res://tools/$(TOOL).gd -- $(ARGS)

## --- iOS -------------------------------------------------------------------
ios: ## export the iOS Xcode project to build/ios (needs export templates + Xcode; see docs/iOS_BUILD.md)
	$(GODOT) --headless --path $(PROJECT) --export-debug "iOS" build/ios/ReachZero.xcodeproj

## --- clean -----------------------------------------------------------------
clean: ## remove the gitignored build/ output
	rm -rf build

clean-cache: ## remove the Godot import cache (forces a full reimport next run)
	rm -rf .godot
