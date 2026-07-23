# Quest plates — cut-paper quest bar backgrounds (v2, awaiting curation)

Sixteen irregular hand-cut cream paper plates to replace the square quest-card background
in the board quest strip. Each file is a 512x512 transparent PNG, plate centered, with its
soft down-right contact shadow **baked into the alpha channel** (shadow color #294654,
about 18-20% opacity), so the runtime draws one texture and no code shadow.

Provenance: generated with Codex as four themed rows on a flat #6FA9C0 field
(`raw/plates_row_[a-d].png` + per-row prompts), then deterministically un-blended against
that known background and cut per connected component (`raw/unblend_compose.py`).
Because the authoring background equals the in-game board blue, any un-blend residual is
invisible in place, and the alpha shadow also composites correctly over other surfaces.

Rows: a = lobed blobs · b = wavy boulders · c = bulge + bite · d = partial scallops.

**Curation:** delete the plate files you do not want, then ask for intake — survivors get
plan.json-ed into the real quest-strip asset location and these raws archived.
