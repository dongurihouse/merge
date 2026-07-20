# Level dialog asset sprite v2

Reusable artwork extracted from the approved Meadow Sky / Cut-Paper Playground level-dialog direction.

## Deliverables

- `level_dialog_assets_sheet_1536x1024.png`: transparent 3x2 atlas, 512 px per cell.
- `final_frames/`: named transparent 512x512 masters.
- `manifest.json`: row-major atlas coordinates and runtime intent.
- `prompt-used.txt`: reproducible generation brief.
- `pipeline-meta.json`: deterministic sheet-processing metadata.
- `raw-sheet.png`: original flat-magenta generation source.

## Atlas order

| Row | Column | Asset |
| --- | --- | --- |
| 0 | 0 | Number-free level rosette base |
| 0 | 1 | Gold star token |
| 0 | 2 | Daisy medallion |
| 1 | 0 | Left oak-leaf sprig |
| 1 | 1 | Right oak-leaf sprig |
| 1 | 2 | Milestone star |

The level numeral is rendered at runtime over the rosette. Dialog panels, progress bars, summary pills, labels, and buttons remain scalable runtime UI surfaces; they are intentionally not baked into this sprite.

All final sprites use straight RGBA PNG transparency with no opaque edge pixels and no visible magenta key fringe.
