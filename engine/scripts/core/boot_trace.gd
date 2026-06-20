extends RefCounted
## Boot instrumentation — a begin/end WORK-span timer + an aligned timing table.
##
## Each begin(name)/end(name) pair times only the work inside it. Time spent BETWEEN spans
## — the splash's deliberate minimum-duration wait and the fade — is timed by nothing, so it
## never pollutes the "what's taking long" table. Spans may nest; they record in close order.
##
## begin/end/done are no-ops unless a trace is active — so map.gd can call them
## unconditionally and they fire ONLY on the cold boot (the Boot scene calls start()), never
## on later Board<->Map opens. Static-only (process-global, like SceneWarm's cache).

static var _active := false
static var _open: Dictionary = {}        # name -> t0_us for currently-open spans
static var _spans: Array = []            # [{name:String, us:int}] closed spans, in close order

## Begin a fresh trace. Clears any prior spans and arms begin/end/done.
static func start() -> void:
	_active = true
	_open = {}
	_spans = []

## Open a work span named `name`. No-op unless a trace is active.
static func begin(name: String) -> void:
	if not _active:
		return
	_open[name] = Time.get_ticks_usec()

## Close the span named `name`, recording its duration. No-op if inactive or never begun.
static func end(name: String) -> void:
	if not _active or not _open.has(name):
		return
	_spans.append({"name": name, "us": Time.get_ticks_usec() - int(_open[name])})
	_open.erase(name)

## Close any still-open spans, print the timing table, and end the trace. No-op if inactive.
static func done() -> void:
	if not _active:
		return
	var now := Time.get_ticks_usec()
	for name in _open.keys():
		_spans.append({"name": name, "us": now - int(_open[name])})
	_open = {}
	print(format_table(_spans, _total(_spans)))
	_active = false

static func active() -> bool:
	return _active

## A copy of the closed spans recorded so far (test/inspection helper).
static func spans() -> Array:
	return _spans.duplicate(true)

## Test/teardown helper — drop all trace state.
static func _reset() -> void:
	_active = false
	_open = {}
	_spans = []

static func _total(s: Array) -> int:
	var t := 0
	for e in s:
		t += int(e["us"])
	return t

## Pure: render `spans` (+ a work total) as an aligned, share-of-total table. No side effects.
static func format_table(spans_in: Array, total_us: int) -> String:
	var name_w := 5
	for p in spans_in:
		name_w = maxi(name_w, String(p["name"]).length())
	var lines := PackedStringArray()
	lines.append("-- boot trace " + "-".repeat(30))
	for p in spans_in:
		var nm := String(p["name"])
		var us := int(p["us"])
		var frac := (float(us) / float(total_us)) if total_us > 0 else 0.0
		lines.append("  %s  %s ms  %s" % [nm.rpad(name_w), _ms(us / 1000.0), _bar(frac)])
	lines.append("  " + "-".repeat(name_w + 10))
	lines.append("  %s  %s ms" % ["total".rpad(name_w), _ms(total_us / 1000.0)])
	return "\n".join(lines)

static func _ms(ms: float) -> String:
	return "%7.1f" % ms

static func _bar(frac: float) -> String:
	return "#".repeat(int(round(clampf(frac, 0.0, 1.0) * 20.0)))
