# Mail dialog icon sprite v1

Production-oriented icon pack extracted from the approved Meadow Sky + Cut-Paper Playground Mail-dialog direction.

## Deliverables

- `mail_icons_3x3_transparent.png`: transparent 3x3 atlas, 1536x1536.
- `mail_icons_3x3_raw.png`: flat `#FF00FF` keyed atlas, 1536x1536.
- `frames/`: nine named transparent 512x512 icon masters.
- `previews/`: dark, white, and warm-cream review sheets.
- `manifest.json`: stable row-major identity map for later runtime intake.
- `pipeline-meta.json`: generation and cleanup provenance.
- `prompt-used.txt` and `ribbon_gift_chest.prompt.txt`: reproducible generation prompts.

Buttons, cards, modal surfaces, labels, and numbers are intentionally excluded. Runtime UI should provide shadows and interaction states rather than baking them into these masters.

Run `python3 assemble_mail_icon_pack.py` after changing a master frame to rebuild both atlases and all three previews.
