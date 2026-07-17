# Meadow Sky zone reference mocks v3

Reference-only baked scene mocks for pairwise composition QA. These are dressed
approval checkpoints, not runtime layered map assets.

## Artifacts

| Zone | Prompt | PNG | Status |
| --- | --- | --- | --- |
| Appleblossom Commons | `appleblossom_commons_mock_v3.prompt.txt` | `appleblossom_commons_mock_v3.png` | Accepted |
| Bellwater Vale | `bellwater_vale_mock_v3.prompt.txt` | `bellwater_vale_mock_v3.png` | Accepted |

## Tracked reference paths

- Palette and material image: `games/grove/assets/_new/ui_redesign_direction_b/palette_studies_board_v1/palette_a_meadow_sky_board.png`
- Palette and material prompt: `games/grove/assets/_new/ui_redesign_direction_b/palette_studies_board_v1/palette_a_meadow_sky.prompt.txt`
- Camera, scale, shadow, and detail image: `games/grove/assets/_new/ui_redesign_direction_b/screen_reference_pack_meadow_sky_v1/home_screen_meadow_sky_v2_working_farm.png`
- Camera, scale, shadow, and detail prompt: `games/grove/assets/_new/ui_redesign_direction_b/screen_reference_pack_meadow_sky_v1/home_screen_meadow_sky_v2_working_farm.prompt.txt`

Supporting tracked documents:

- Approved art design: `docs/superpowers/specs/2026-07-17-three-zone-cosmetic-world-art-design.md`
- Generation and validation plan: `docs/superpowers/plans/2026-07-17-zone-reference-mocks-v3.md`

## Five-field signatures

Grid cells use `top|middle|bottom` by `left|center|right`. The hero is the
largest focal structure visible in the accepted mock.

| Field | Appleblossom Commons | Bellwater Vale | Different? |
| --- | --- | --- | --- |
| Water topology | Narrow far-right boundary stream feeding one lower-right pond | One right-edge-cropped basin narrowing into one short broad diagonal spillway that exits only the lower-left side edge; the bottom edge is continuous meadow | Yes |
| Path topology | One unbranched open promenade from the upper-left seam around the left and lower lawn edges, terminating at Rainwatch/pond; no pavilion spur or pad | One top-left entry path bending once through the Bell Arch and ending at Millhall | Yes |
| Building distribution | Unequal 4+2 edge groups: four along the upper crescent, two beside the lower pond | Uneven spatial 3+3 outer clusters: three at the upper path/mill edge, three at the lower water junction | Yes |
| Hero 3 x 3 cell | Top-center: Storytree Library | Bottom-center: Millbridge Meeting House | Yes; Manhattan distance 2 |
| Negative-space 3 x 3 cell | Middle-center: broad social lawn | Middle-center: broad quiet meadow | No |

Result: four of five signature fields differ. The two mandatory fields, path
topology and building distribution, differ.

## Hero evidence

- Appleblossom: Storytree Library occupies the top-center grid cell. Its broad
  apple canopy and ring-shaped reading shelter form the largest combined
  silhouette and dominate the upper crescent without filling the central lawn.
- Bellwater: Millbridge Meeting House occupies the bottom-center grid cell. Its
  long low straight-edged shallow-chevron roof spans the spillway and is visibly
  wider and larger than the upper-right Millhall, making it the dominant focal
  structure while retaining the crossing function.

## Silhouette rosters

- Appleblossom Commons: arc; barrel; tree-ring; parasol; folded canopy; drum.
- Bellwater Vale: wedge-and-wheel; open frame; long chevron; diamond canopy;
  flat-cap square; low arch-and-tongue.

The exact silhouette-class overlap is zero. Under a conservative broad-family
comparison, only open-canopy and rounded/arched masses overlap; that is two
shared families, and at least four classes in each zone remain absent from the
other. Appleblossom has one open shelter, the cream parasol Tea Pavilion.
Bellwater has one open shelter, the coral diamond-canopy Lilybell Pavilion.

## Canvas and checksums

Both files are non-interlaced, 8-bit RGB PNGs at exactly `941 x 1672`.

```text
730bc58e296170642d99ff6406b0b182cba49f11b297a2fc443cbf89216abde3  appleblossom_commons_mock_v3.png
df292bae7511d2bf7ce529b04a981802e706cb825e861f35453398513b3c2b1a  bellwater_vale_mock_v3.png
```

## Anti-convergence verdict

Accepted. Original-detail side-by-side review found no repeated
central-pavilion/lower-right-cottage composition: Appleblossom's pavilion is
lower-left and its lower-right structure is the folded Rainwatch House, while
Bellwater's pavilion is lower-center and its lower-right structure is the
low-arch Otter Landing. Each zone contains only one open shelter. The shared
Meadow Sky palette, high three-quarter camera, shallow matte cut-cardstock
material, warm edges, upper-left lighting, and restrained architectural detail
remain consistent while topology, distribution, and silhouette grammar remain
distinct. Appleblossom's only promenade is unbranched and the Tea Pavilion sits
directly on meadow without a paved or turf base. Bellwater water is one
continuous basin-to-spillway body, never touches the bottom frame, and exits
only the lower-left side edge; its Meeting House is the dominant bottom-center
long-chevron structure rather than a barrel-roof form.
