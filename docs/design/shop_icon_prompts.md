# Shop / currency icon prompts — ready-to-paste (T47 tail)

> Authored for the **"cleaner shop icons"** T46/T47 tail. Per `grove_art_pipeline §2` the
> Engineer **authors prompts**; the **Dev/artist generates** the PNGs; the Engineer then
> processes (`process_icon` → 512² transparent) + drops at the engine path + `make import` +
> verifies. So this file is the hand-off: paste a prompt → get a finished transparent sprite back.
>
> **Scope truth (surfaced building this tail):** the shop's icons are almost all the **shared
> currency / utility canon** — `icon_coin` (acorn), `icon_gem` (dewdrop), `icon_water`, `icon_rain`
> (the "Fill your water" help icon). They render in the **HUD wallet + every price pill**, not just
> the shop, so redoing them improves the whole game — and it **is** the `§8` icon-canon /
> emoji-purge work this tail bumped into. The shop's **featured** cards use live `PieceView`
> previews (already on-style), so they need **no** icon art. Do the set below as **one batch** for a
> consistent currency language; coordinate with whoever owns the §8 canon so it isn't done twice.

## Format

Each prompt = `[subject] + [ICON SCAFFOLD] + [STYLE LOCK]`. Icons are **flat front-on UI glyphs**
— **no horizon / sky / scene / perspective** (the `grove_art_pipeline §3` top-down rule; the
STYLE LOCK's cloud/haze/grass clauses are scene-only and dropped here). Output: **512×512,
transparent, no text/numerals** (the engine draws all text — §16 rule 6).

**ICON SCAFFOLD** (paste verbatim after the subject):
> a single game UI icon, centered, chunky readable silhouette, soft painterly shading with one warm
> rim light, a soft contact shadow beneath, clean simple outline; flat front-on icon, no horizon, no
> scene, no perspective; on a transparent background, any interior gaps fully cut through
> (transparent), not filled

**STYLE LOCK** (paste verbatim last):
> hand-painted anime film style, soft gouache and watercolor texture with visible brushwork, warm
> nostalgic pastoral palette of meadow green, straw gold and clear sky blue, painterly cel-shaded
> with clean simple line work, no photorealism, no glossy 3D render, no text

## The prompts

| id (engine path `games/grove/assets/ui/kit/icon_<id>.png`) | Subject (paste before the scaffold) |
|---|---|
| **coin** (the acorn = soft currency) | `a single plump glossy golden-brown acorn with a neat ridged cap and a soft highlight` |
| **gem** (the dewdrop = premium currency) | `a single luminous faceted teal-and-sky-blue dewdrop gem with a soft inner glow and a clean highlight` |
| **water** (energy / watering) | `a single clear sky-blue water droplet with a soft white highlight` |
| **rain** (the "Fill your water" help icon) | `a friendly tin watering can tilted to pour, with a small arc of three clear water droplets from its spout` |
| **star** (the Bloomstar = progression) — optional, only if §8 wants it here | `a plump rounded five-point bloom-star in straw gold with a soft warm glow` |

*Acorn-pouch note:* the **"Coin pouch"** card's framing is a pouch, but the **icon is the acorn**
(it must match the HUD wallet's coin glyph). Keep `icon_coin` the acorn; the "pouch" lives in the
card title, not the art.

## Hook-up (Engineer, when sprites return)

1. `process_icon` each return → trimmed/centered **512² transparent** (verify alpha over magenta —
   no halos, subject not eaten).
2. Drop at `games/grove/assets/ui/kit/icon_<id>.png` (overwrite the current glyph), `make import`.
3. No code change — `Look.icon(id)` auto-resolves the new PNG (it already prefers the file over the
   emoji glyph fallback). Verify with `make shot-map MODE=shop` + a HUD shot (the wallet) — the new
   art must read at the in-shop sizes (`PRICE_ICON 28`, `HERO_ICON 72`, `GEM_ICON 64`) **and** the
   HUD pill sizes.
4. Share-gate sign-off is the **Dev's eye** (low LLM-reliability — never my eyeball).
