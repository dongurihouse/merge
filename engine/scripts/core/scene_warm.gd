extends RefCounted
## Threaded scene pre-warm + packed swap.
##
## `change_scene_to_file` is fully synchronous: it loads the target scene AND compiles its whole
## `preload` graph on the main thread before instantiating — ~270 ms on the FIRST visit to a scene
## (measured), which is most of the freeze when switching map<->board. This helper moves that load
## off the critical path: while the player sits on one scene, `prewarm()` loads the OTHER scene on a
## background thread; the actual swap then uses the already-loaded PackedScene (`change_scene_to_packed`),
## skipping the load + compile entirely. Godot's normal scene lifecycle is otherwise unchanged.
##
## Static-only (never instantiated). The PackedScene refs are held for the whole session so the
## compiled script graph stays resident — a return trip is then instant too. Two PackedScenes is cheap
## (the serialized scene, not an instance), so keeping both map + board warm costs little memory.

static var _packed: Dictionary = {}     # path -> PackedScene (held so the cache + script graph survive)
static var _inflight: Dictionary = {}   # path -> true while a background load is running

## Already have it (or finished loading it)?
static func is_warm(path: String) -> bool:
	return _packed.has(path)

## Kick a background (worker-thread) load of `path` if we don't already have one going. Idempotent and
## non-blocking — safe to call from a scene's _ready for the OTHER scene. A missing path is a no-op.
static func prewarm(path: String) -> void:
	if _packed.has(path) or _inflight.has(path):
		return
	if not ResourceLoader.exists(path):
		return
	if ResourceLoader.load_threaded_request(path) == OK:
		_inflight[path] = true

## Return the PackedScene for `path`, populating the cache. Uses the prewarmed copy when ready; if a
## prewarm is still in flight it blocks for whatever's left (same cost as a sync load, minus the head
## start already done); with no prewarm at all it cold-loads. Returns null only if the path is missing.
static func take(path: String) -> PackedScene:
	if _packed.has(path):
		return _packed[path]
	if _inflight.has(path):
		_inflight.erase(path)
		var res := ResourceLoader.load_threaded_get(path)   # blocks for the remainder if not done yet
		if res is PackedScene:
			_packed[path] = res
			return res
	if not ResourceLoader.exists(path):
		return null
	var ps := load(path) as PackedScene                     # cold fallback (no prewarm happened)
	if ps != null:
		_packed[path] = ps
	return ps

## Swap the running scene to `path`, using the prewarmed PackedScene when available. Returns an Error
## (OK on success). Falls back to a plain change_scene_to_file only if the packed take failed.
static func go(tree: SceneTree, path: String) -> int:
	var ps := take(path)
	if ps != null:
		return tree.change_scene_to_packed(ps)
	return tree.change_scene_to_file(path)

## Flush every outstanding background request: retrieve (consume) each in-flight threaded load so none
## is left queued in the WorkerThreadPool at process exit. A prewarm()ed-but-never-take()n request leaks
## its resource at exit ("ObjectDB instances leaked at exit") and — in the wrong teardown order — crashes
## WorkerThreadPool::finish() as it tears down the orphaned task's GDScript Callable. Retrieved scenes are
## kept warm (cheap, and useful if we end up navigating there). Call before quitting any headless harness
## (or scene) that prewarmed a scene it never navigated to.
static func drain() -> void:
	for path in _inflight.keys():
		var res := ResourceLoader.load_threaded_get(path)   # blocks for the remainder, consumes the request
		if res is PackedScene:
			_packed[path] = res
	_inflight.clear()

## Test/teardown helper — flush pending loads (so they don't leak/crash at exit) then drop the cache.
static func _clear() -> void:
	drain()
	_packed.clear()
