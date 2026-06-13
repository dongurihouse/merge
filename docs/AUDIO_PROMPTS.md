# Tidy Up — Audio Generation Prompts

Companion to `ICON_PROMPTS.md`, but for **sound**. You generate the audio (music + SFX) with
text-to-audio tools; the game auto-loads files that match the names below. Wiring the new cues
into code is a later step — this doc is just so you can generate the assets.

---

## §0 — Sonic identity (read first)

**The feeling:** a sunny afternoon tidying a cozy room with soft lo-fi in the background. Warm,
plush, unhurried. Nothing urgent, nothing tense, **never "casino."** Pleasant at low volume for
someone playing in bed with the sound barely on.

- **Textures:** wood, felt, paper, soft plastic, gentle bells. **Rounded transients** — no harsh
  clicks, no sharp digital zaps, no aggressive bass.
- **Instruments to favor:** marimba, kalimba, celesta/glockenspiel, felt/muted piano, ukulele or
  soft nylon pluck, warm pad, light shaker/brush percussion, soft "pop"/"boop" mouth-ish sounds.
- **Tonality:** major / **pentatonic**, gentle. Keep **everything in one key (C major / A-minor
  pentatonic)** so SFX never clash with the music.
- **Words to paste into generators:** *warm, soft, plush, rounded, woody, cozy, twinkly, gentle,
  breezy, lo-fi, wholesome, marimba, kalimba, celesta, felt piano, soft pluck, no vocals.*
- **Avoid:** tension, minor-key drama, sirens, coins-as-slot-machine, loud risers, vocals, anything
  that feels like a slot machine or a notification you'd want to silence.

---

## §1 — Technical specs

**SFX** (one-shots):
- Mono, 44.1 kHz, **`.wav`** (the engine auto-loads `res://assets/sfx/<name>.wav`).
- Short (lengths per cue below; most ≤ 0.6 s). Trim leading/trailing silence. Peak ≈ −3 dBFS.
- Generate 2–3 variants per cue, keep the **softest, roundest** take.

**Music** (loops):
- Stereo, 44.1 kHz, **`.ogg`** (Vorbis). Put in `res://assets/music/<name>.ogg`.
- **Seamlessly loopable** (ask the tool for "seamless loop, instrumental, no vocals"; trim to a bar
  boundary and crossfade the seam). 45–90 s. Target loudness ≈ −16 to −14 LUFS (quiet, cozy).

> Keep music and SFX in the **same key** so a coin "ding" never sounds sour over the music bed.

---

## §2 — Music beds (3 loops for v1)

Tool suggestion: Suno / Udio (set **Instrumental**, ask for **seamless loop, no vocals**).

| File | Where it plays | Mood | Prompt |
|---|---|---|---|
| `music_menu.ogg` | Title screen + Home/Hub | Inviting, warm welcome, "come in and relax" | *Cozy wholesome lo-fi loop, instrumental, no vocals. Warm felt piano melody over soft marimba and a gentle shaker, mellow warm pad underneath, ~74 BPM, C major, relaxed and welcoming like a sunny morning at home. Seamless loop, soft, low energy, no drums hits, no tension.* |
| `music_play.ogg` | During a job (the board) | Unobtrusive focus loop — texture over melody so it never tires over long play | *Gentle lo-fi focus loop, instrumental, no vocals. Soft kalimba arpeggios and light brushed percussion, warm pad bed, very few melodic hooks, ~70 BPM, A-minor pentatonic, calm and spacious. Designed to loop for many minutes without getting annoying. Seamless loop, no build-ups, no tension.* |
| `music_room.ogg` | Your Home / renovation / room screens | A little fuller and more rewarding — the cozy payoff | *Warm cozy loop, instrumental, no vocals. Celesta and glockenspiel melody over soft nylon-guitar pluck and warm strings pad, light shaker, ~76 BPM, C major, content and heartwarming like finishing a project. Seamless loop, gentle, uplifting but soft, no big drums.* |

---

## §3 — Sound effects

### Existing cues (already in the game — regenerate only if you want them on-identity)
`item_pickup`, `item_drop`, `merge_soft`, `merge_success`, `tidy_poof` (showcase/"put away"),
`level_complete` (board cleared), `invalid_soft` (blocked move), `button_tap`.

### New cues for v1 (please generate these)

| File | When it plays | Character | Length | Prompt (for a text-to-SFX tool) |
|---|---|---|---|---|
| `item_slide.wav` | a piece slides across cells | a soft cloth/wood *whoosh*, very gentle | ~0.25 s | *Soft short whoosh of a felt object sliding across a wooden table, warm and gentle, no harsh air, cozy UI sound.* |
| `coin_earn.wav` | coins fly to the wallet on payout | a warm, rounded coin *plink* (NOT metallic/casino) | ~0.3 s | *Soft warm coin plink, single rounded "ding" like a small wooden bell, wholesome reward sound, gentle, no metallic clang.* |
| `star_pop.wav` | each star fills on the win screen | a bright sparkly *ding*, ascending feel | ~0.4 s | *Bright gentle sparkle "ting" like a tiny glockenspiel note with a soft shimmer tail, cute reward, C major, no harshness.* |
| `quest_complete.wav` | a quest/goal is completed | a warm little 3-note fanfare | ~0.7 s | *Short cozy 3-note marimba+celesta flourish, happy and wholesome, C major pentatonic, soft, no brass, no drums.* |
| `unlock.wav` | a new client/district/room unlocks | a gentle reveal swell | ~0.8 s | *Soft magical reveal swell, warm pad rising into a celesta sparkle, cozy "something new opened" feeling, gentle, no big riser, no whoosh.* |
| `undo.wav` | Undo is pressed | a soft reverse/whoosh, "rewind" feel | ~0.3 s | *Short soft reverse whoosh, gentle backwards swoosh like un-doing, warm and quiet, no harsh digital sound.* |
| `room_complete.wav` | a Room is fully renovated (the v1 hero beat) | a fuller, heart-warming chime — bigger than the others | ~1.2 s | *Warm rewarding chime sequence, celesta + glockenspiel + soft strings swell resolving on a major chord, "ta-da you finished the room" but cozy and gentle, wholesome, no brass fanfare, no drums.* |

> **Pitch note:** the game pitches the merge sound **up** for higher-tier merges, so keep
> `merge_success` fairly **neutral/mid-pitched** — a take that still sounds nice when raised.

---

## §4 — Generation tips

- **Loopable music:** ask for *"seamless loop, instrumental, no vocals."* Then trim to a whole bar
  and crossfade the start/end (~50–100 ms) so the seam is inaudible.
- **SFX:** generate a few variants per cue, pick the **softest/roundest**, trim to the lengths above,
  normalize to ≈ −3 dBFS.
- **Consistency:** keep one key (C major / A-minor pentatonic) across music *and* SFX.
- **Volume budget:** music should sit *under* SFX — generate music quiet (−16 to −14 LUFS) and SFX
  a touch louder so taps/merges read over the bed.
- **Drop files in:** `assets/sfx/<name>.wav` for SFX, `assets/music/<name>.ogg` for music, then run
  `godot --headless --path . --import`. (I'll wire the new SFX + music playback when we build the
  audio milestone.)

---

## §5 — GHIBLI GROVE set (2026-06-10) — SUPERSEDES the bedroom set above

Theme locked (GROVE_STYLE.md): the game is now a hand-painted forest homestead.

**Music identity (owner re-spec 2026-06-11):** *near-ambience, not songs.* The
beds should sit at the edge of hearing — slow, sparse, almost white noise,
something the player can completely ignore for an hour. **ONE instrument per
bed** (plus at most a faint pad/ambience under it), long silences between
notes, **no beat, no percussion, no melody hooks, no build-ups.** Earlier
"acoustic ensemble in a field" direction is DEAD for music — generators turned
it into fast, busy multi-instrument tracks. (SFX prompts below are unaffected:
one-shots, already landed.)
Keep §1's technical specs and the one-shared-key rule. Same engine file names —
these takes DROP IN over the old ones with zero code changes.

### Music beds (`assets/music/*.ogg`, seamless loops, instrumental)

> **Owner consolidation 2026-06-11:** per-screen beds are DEAD
> (`music_menu` / `music_play` / `music_room` — do not generate). The whole
> game plays ONE continuous ambient bed that alternates between **two
> interchangeable takes**, `amb_grove1` and `amb_grove2`, forever — the engine
> never restarts it on screen changes. Because they alternate back-to-back,
> the two takes MUST be the same key, the same loudness, and the same
> ambience family — a listener should not notice the handoff.
>
> **Acceptance test before ledgering a take (owner law 2026-06-11):** play it
> at low volume while doing something else. If you can tap your foot to it,
> hum a tune from it, or count more than one instrument — **re-roll.** It
> should feel closer to a room tone than a song.

| File | Role | Prompt |
|---|---|---|
| `amb_grove1.ogg` | continuous bed, take A | *Quiet meadow ambience with the faintest music inside it: soft distant birdsong, leaves moving in a light breeze, a very distant brook, and a single soft felt piano playing one slow note at a time with long silences between notes, no rhythm, no beat, no percussion, no melody, almost white noise, background texture meant to be ignored at low volume, seamless loop, instrumental, no vocals, 60–90s.* |
| `amb_grove2.ogg` | continuous bed, take B | *Quiet meadow ambience with the faintest music inside it: soft breeze through grass, an occasional distant songbird, a very distant brook, and a lone soft kalimba note once in a while with long pauses between notes, no rhythm, no beat, no percussion, no melody, almost white noise, background texture meant to be ignored at low volume, seamless loop, instrumental, no vocals, 60–90s.* |

### SFX (`assets/sfx/*.wav`) — existing names, grove takes

| File | Moment | Prompt |
|---|---|---|
| `item_pickup.wav` | lift an item | *Single soft leaf-brush flick, light and papery, very short, rounded, no click.* |
| `item_drop.wav` | place/move an item | *Soft thump of something small landing on moss, muffled, warm, very short.* |
| `merge_soft.wav` | small merge (growth) | *Tiny foliage rustle blooming into one soft wooden marimba note, organic, short, gentle.* |
| `merge_success.wav` | big merge | *Quick warm strum of nylon guitar harmonics with a faint leaf-flutter tail, bright but soft, short.* |
| `tidy_poof.wav` | harvest/put-away | *Soft pop like a seed pod opening with a tiny puff of air and one kalimba note, rounded, short.* |
| `level_complete.wav` | unlock/celebration | *Short warm flourish: wooden flute and glockenspiel rising figure over a guitar chord, with a single distant songbird answering at the end, joyful but gentle, ~1.5s.* |
| `button_tap.wav` | UI tap | *Single soft wooden tick, like tapping a smooth branch, very short, rounded.* |
| `invalid_soft.wav` | can't-do | *Soft low marimba double-tap, kind and unbothered, very short, no buzz.* |

### New v2 cues (wire in P1/P2; same specs)

| File | Moment | Prompt |
|---|---|---|
| `water_pop.wav` | generator pop (costs water) | *A single round water droplet plip with a tiny sprout-rustle tail, fresh and soft, very short.* |
| `bramble_clear.wav` | bramble/box opens | *Soft twig-snap and leaves whooshing aside, ending on one warm pluck, short, satisfying, not violent.* |
| `giver_cheer.wav` | animal quest complete | *A happy little animal chirp-trill (songbird-like, friendly, not cartoonish) over a tiny marimba run, ~0.8s.* |
| `star_earn.wav` | star payout | *One clear glockenspiel note with a soft shimmer tail, like a small bell in open air, short, never casino.* |
| `bag_in.wav` / `bag_out.wav` | bag stash/retrieve | *Soft cloth pouch rustle with a muted drawstring tick, very short.* (two takes) |
| `roof_open.wav` | zone close-up opens | *Gentle wooden creak swinging open with a breath of indoor air, warm, ~0.7s.* |
| `rain_refill.wav` | water refilled | *Brief gentle rain patter on leaves resolving into one bright droplet note, hopeful, ~1s.* |
| ~~`amb_grove.ogg`~~ | ~~optional ambience layer under all beds~~ | SUPERSEDED 2026-06-11: the ambience IS the music now — see `amb_grove1` / `amb_grove2` in the music table above. Do not generate a separate ambience layer. |
