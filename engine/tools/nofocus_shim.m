// Keep a CAPTURE run from owning the owner's keyboard.
//
// THE DEFECT. Agents take ~160 screenshots a session, each one a cold Godot launch, and every
// launch made Godot the frontmost application and KEPT it there until the process exited —
// measured 500-850 ms per capture on this machine, during which everything the owner typed went
// into a 1x1 off-screen window. `window/size/no_focus` does not stop it: that flag only makes the
// WINDOW refuse key status, and the theft is at the APPLICATION level.
//
// WHERE IT COMES FROM (measured, not guessed — stack captured at NSApplicationDidBecomeActive):
//
//     -[NSApplication _handleActivatedEvent:]        <- an event from the WINDOW SERVER
//       -[NSApplication sendEvent:]
//         DisplayServerMacOS::_process_events
//
// Nothing in the process asked for it. Launch Services activates a freshly launched REGULAR
// application when it checks in (the AppleEvent check-in visible one frame up the same stack,
// -[NSApplication _handleAEOpenEvent:]), and that check-in also RESETS the activation policy from
// the bundle's Info.plist — so a policy set during our constructor is already undone by the time
// the activation lands. Godot's own `[NSApp activateIgnoringOtherApps:]` is real too, but vetoing
// it alone changed nothing; that is why the previous attempts (project setting, off-screen window,
// an LSBackgroundOnly .app clone) all failed.
//
// WHAT THIS DOES. Injected with DYLD_INSERT_LIBRARIES by engine/tools/quiet_godot.sh, it:
//   1. demotes the process to a UI-element (Accessory) process before AppKit exists;
//   2. sets LSUIElement in the in-memory main-bundle info dictionary, which is where NSApplication
//      reads the initial policy from;
//   3. replaces -[NSApplication activateIgnoringOtherApps:] and -[NSApplication activate] with
//      no-ops, and forces every -[NSApplication setActivationPolicy:] to Prohibited;
//   4. re-demotes to Prohibited the instant the app is told it is becoming active, which is the
//      only answer to an activation the process never requested.
//
// Steps 1-3 alone left the theft intact. Step 4 is what collapses it: measured, the capture now
// owns the keyboard for a single-digit number of milliseconds ONCE per launch instead of holding
// it for the whole run. That residue is a floor, not an oversight — the Window Server has already
// switched the front app by the time any in-process code can answer. It is not zero, and a
// keystroke that lands inside that window is still delivered to the capture. The structural fix
// for the rest is FEWER LAUNCHES: see `make shot-batch`.
//
// SCOPE. quiet_godot.sh injects this, so only screenshot runs get it. The owner's own launches
// (`make g`, `make w`, `make sw`, `make fx`, `make debug`) run godot directly and stay normal,
// focusable applications.
//
// WHY AN INSERTED DYLIB IS ALLOWED. Godot ships with com.apple.security.cs.allow-dyld-
// environment-variables and cs.disable-library-validation, so an unsigned insert loads under its
// hardened runtime. If a future build drops those, the insert is ignored and the run behaves as it
// did before — no crash, no wrong capture.
//
// Built on demand and cached at engine/generated/tu_nofocus.dylib. TU_NOFOCUS_VERBOSE=1 traces
// every veto and demotion on stderr; tools/test_quiet_window.py is the guard that keeps the
// measured claim above honest.

#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import <stdlib.h>
#import <stdio.h>

// The real -[NSApplication setActivationPolicy:], saved at install time so the replacement can
// forward to it with a different argument instead of recursing into itself.
static BOOL (*tu_orig_setActivationPolicy)(id, SEL, NSApplicationActivationPolicy) = NULL;

static int verbose(void) {
	const char *v = getenv("TU_NOFOCUS_VERBOSE");
	return v && v[0] == '1';
}

// Put the process back where it belongs. Prohibited is the strongest policy: a Prohibited app is
// not activatable. Accessory is the fallback for the (unobserved) case where the transition to
// Prohibited is refused — it at least keeps the app out of the Dock and out of the app switcher.
static void tu_demote(const char *why) {
	if (!tu_orig_setActivationPolicy || !NSApp) {
		return;
	}
	SEL sel = @selector(setActivationPolicy:);
	BOOL ok = tu_orig_setActivationPolicy(NSApp, sel, NSApplicationActivationPolicyProhibited);
	if (!ok) {
		ok = tu_orig_setActivationPolicy(NSApp, sel, NSApplicationActivationPolicyAccessory);
	}
	if (verbose()) {
		fprintf(stderr, "tu_nofocus: demote(%s) ok=%d policy=%ld active=%d\n",
			why, (int)ok, (long)[NSApp activationPolicy], (int)[NSApp isActive]);
	}
}

static void tu_activateIgnoringOtherApps(id self, SEL _cmd, BOOL flag) {
	(void)self; (void)_cmd; (void)flag;
	if (verbose()) fprintf(stderr, "tu_nofocus: vetoed activateIgnoringOtherApps:\n");
}

static void tu_activate(id self, SEL _cmd) {
	(void)self; (void)_cmd;
	if (verbose()) fprintf(stderr, "tu_nofocus: vetoed activate\n");
}

static BOOL tu_setActivationPolicy(id self, SEL _cmd, NSApplicationActivationPolicy policy) {
	if (!tu_orig_setActivationPolicy) return YES;
	BOOL ok = tu_orig_setActivationPolicy(self, _cmd, NSApplicationActivationPolicyProhibited);
	if (!ok) {
		ok = tu_orig_setActivationPolicy(self, _cmd, NSApplicationActivationPolicyAccessory);
	}
	if (verbose()) {
		fprintf(stderr, "tu_nofocus: setActivationPolicy:%ld -> vetoed (ok=%d, now %ld)\n",
			(long)policy, (int)ok, (long)[NSApp activationPolicy]);
	}
	return YES;
}

// NSApplication reads LSUIElement out of the MAIN BUNDLE's info dictionary. CFBundleGetInfoDictionary
// hands back the live dictionary (not a copy, unlike -[NSBundle infoDictionary]), so setting the key
// before AppKit initialises makes this process look like an agent without touching Godot.app on disk.
static void tu_mark_ui_element(void) {
	CFBundleRef bundle = CFBundleGetMainBundle();
	if (!bundle) return;
	CFMutableDictionaryRef info = (CFMutableDictionaryRef)CFBundleGetInfoDictionary(bundle);
	if (!info) return;
	CFDictionarySetValue(info, CFSTR("LSUIElement"), CFSTR("1"));
	CFDictionarySetValue(info, CFSTR("LSBackgroundOnly"), CFSTR("1"));
}

__attribute__((constructor))
static void tu_nofocus_install(void) {
	tu_mark_ui_element();
	ProcessSerialNumber psn = { 0, kCurrentProcess };
	OSStatus st = TransformProcessType(&psn, kProcessTransformToUIElementApplication);
	if (verbose()) fprintf(stderr, "tu_nofocus: TransformProcessType -> UIElement st=%d\n", (int)st);

	Class app = objc_getClass("NSApplication");
	if (!app) return;

	Method m = class_getInstanceMethod(app, @selector(activateIgnoringOtherApps:));
	if (m) method_setImplementation(m, (IMP)tu_activateIgnoringOtherApps);

	Method ma = class_getInstanceMethod(app, sel_registerName("activate"));
	if (ma) method_setImplementation(ma, (IMP)tu_activate);

	Method mp = class_getInstanceMethod(app, @selector(setActivationPolicy:));
	if (mp) {
		tu_orig_setActivationPolicy =
			(BOOL (*)(id, SEL, NSApplicationActivationPolicy))method_getImplementation(mp);
		method_setImplementation(mp, (IMP)tu_setActivationPolicy);
	}

	// The activation nobody asked for: answer it the moment AppKit reports it. WillBecomeActive
	// fires first and sometimes lands before the switch completes; DidBecomeActive is the backstop.
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserverForName:NSApplicationWillBecomeActiveNotification object:nil queue:nil
		usingBlock:^(NSNotification *n) { (void)n; tu_demote("willBecomeActive"); }];
	[nc addObserverForName:NSApplicationDidBecomeActiveNotification object:nil queue:nil
		usingBlock:^(NSNotification *n) { (void)n; tu_demote("didBecomeActive"); }];
	if (verbose()) fprintf(stderr, "tu_nofocus: installed\n");
}
