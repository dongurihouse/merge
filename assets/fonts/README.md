# Drop the UI font here

Put the generated font as **`ui.ttf`** (TTF or OTF). The game auto-applies it to all
text globally (`scripts/ui_font.gd`) and falls back to Godot's default font if it's
absent. Spec + glyph set: see ../../docs/core/merge_spec.md §11 (the text law).

After adding `ui.ttf`, open the project in Godot once so it imports.
