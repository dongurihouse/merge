extends RefCounted
## Tidy Up — tiny cross-scene handoff (which job to play next). Static like Save/Audio
## so it survives scene changes without an autoload. The Jobs map sets next_level
## before launching Main.tscn; Main reads it on _ready.

static var next_level := 0
