extends RefCounted
## Game #2 — GROVE. A full clothes layer over the base engine: art, audio, and font,
## plus the ruleset + palette it shares as the base. Blank fields = engine default.
const ID := "grove"
const DATA := preload("res://games/grove/grove_data.gd")        # the grove's content + tuning
const PALETTE := preload("res://games/grove/grove_palette.gd")  # the grove's colours
const ART_ROOT := "res://games/grove/assets/"
const AUDIO_ROOT := "res://games/grove/assets/"
const FONT := ""                                               # use the engine's system UI face (a rounded system font); the bundled ui.ttf is no longer used
# The game-side SCRIPTS + settings the engine reaches for by name. The engine may not hardcode a
# res://games/ path (docs/design/merge_spec.md §15, enforced by engine/tests/layering_tests.gd), so
# every such file is declared HERE and asked for through Game.kit() / Game.kit_settings() /
# Game.home_chrome(). Blank = the game has none, and the engine draws its code-drawn fallback.
const KIT := "res://games/grove/ui_kit.gd"                     # the shared UI kit (frames · cells · pills · icons)
const KIT_SETTINGS := "res://games/grove/ui_kit_settings.json" # the kit's workbench-saved dials — keep == ui_kit.gd's CONFIG_PATH
const HOME_CHROME := "res://games/grove/home_chrome.gd"        # canonical home/map chrome icon ids (shared with the bake)
