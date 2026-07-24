extends RefCounted
## APP STORE UPDATE CHECK — notices when a newer build is live on the App Store and asks the map to
## offer the optional update prompt (ui/update_prompt.gd). Modeled on core/inbox_sync.gd: a thin network
## shell (check(), an HTTPRequest) over PURE, unit-tested logic (evaluate()/version_gt()). The check
## NEVER blocks play or shows the player an error — a dead network, a non-200, or a bad reply is a no-op.
##
## SOURCE: Apple's iTunes Lookup API (no backend). GET lookup?bundleId=<id> → results[0].version is the
## latest App Store marketing version; trackViewUrl is the store page. iOS-only — the lookup describes the
## App Store listing, so check() is a no-op off iOS (editor + other platforms are unaffected).
##
## CADENCE: once per new version. evaluate() suppresses the prompt when the store version equals the one
## the player last dismissed (Save.update_dismissed); a strictly-newer version re-prompts.

const Save = preload("res://engine/scripts/core/save.gd")
const BuildInfo = preload("res://engine/scripts/core/build_info.gd")

# The App Store bundle id (matches export_presets.cfg application/bundle_identifier).
const BUNDLE_ID := "com.dongurihouse.acornforest"
const LOOKUP_URL := "https://itunes.apple.com/lookup?bundleId=%s"
const CHECK_TIMEOUT := 8.0

# Check the App Store for a newer version. `host` parents the transient HTTPRequest. When a newer,
# not-yet-dismissed version exists, fires `on_prompt(store_version, store_url)`. Any failure → no-op.
static func check(host: Node, on_prompt: Callable, url: String = LOOKUP_URL % BUNDLE_ID) -> void:
	if OS.get_name() != "iOS":
		return                                         # the App Store listing only describes iOS builds
	var req := HTTPRequest.new()
	req.timeout = CHECK_TIMEOUT
	host.add_child(req)
	req.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			var decision := evaluate(body.get_string_from_utf8(), installed_version(), Save.update_dismissed())
			if bool(decision.get("prompt", false)) and on_prompt.is_valid():
				on_prompt.call(String(decision.get("version", "")), String(decision.get("url", "")))
		if is_instance_valid(req):
			req.queue_free())
	var err := req.request(url)                        # GET the lookup reply; evaluate() does the deciding
	if err != OK:                                      # couldn't even start (bad url / no TLS) — silent no-op
		if is_instance_valid(req):
			req.queue_free()

# PURE: decide whether to prompt from a lookup reply + the installed version + the last-dismissed version.
# Returns {"prompt": bool, "version": String, "url": String}. Never crashes on bad input → {prompt:false}.
static func evaluate(lookup_text: String, installed: String, dismissed: String) -> Dictionary:
	var no := {"prompt": false, "version": "", "url": ""}
	var json := JSON.new()                             # instance parse: returns an error code quietly (no logged ERROR on bad input)
	if json.parse(lookup_text) != OK:
		return no
	var data: Variant = json.data
	if not (data is Dictionary):
		return no
	var results: Variant = (data as Dictionary).get("results", [])
	if not (results is Array) or (results as Array).is_empty():
		return no
	var first: Variant = (results as Array)[0]
	if not (first is Dictionary):
		return no
	var version := String((first as Dictionary).get("version", ""))
	if version == "":
		return no
	var url := String((first as Dictionary).get("trackViewUrl", ""))
	var prompt := version_gt(version, installed) and version != dismissed
	return {"prompt": prompt, "version": version, "url": url}

# PURE: is version `a` strictly NEWER than `b`? Dotted-numeric compare, left to right, missing trailing
# components treated as zero (so 1.2 == 1.2.0, 1.10 > 1.9). Non-numeric segments compare as zero.
static func version_gt(a: String, b: String) -> bool:
	var pa := _parts(a)
	var pb := _parts(b)
	var n := maxi(pa.size(), pb.size())
	for i in n:
		var ca: int = pa[i] if i < pa.size() else 0
		var cb: int = pb[i] if i < pb.size() else 0
		if ca != cb:
			return ca > cb
	return false

static func _parts(v: String) -> Array:
	var out: Array = []
	for seg in v.split("."):
		out.append(String(seg).to_int())              # non-numeric leading → 0 (permissive, never crashes)
	return out

# The installed marketing version (the App Store "version" field is the marketing version too).
static func installed_version() -> String:
	return BuildInfo.version_text()
