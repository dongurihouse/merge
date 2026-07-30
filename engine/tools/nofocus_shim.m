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
//   4. POLLS the activation policy on the main run loop every 2 ms and demotes the moment it reads
//      Regular, which is the only answer to a promotion the process never requested;
//   5. re-demotes on the activation notifications too, as a same-pump backstop for step 4.
//
// Steps 1-3 alone left the theft intact: the check-in promotion happens LATER than anything the
// constructor can do (measured, ~575 ms into a 1.5 s capture) and no hook of ours is on its path.
//
// WHY POLLING AND NOT JUST THE NOTIFICATION (step 5 was step 4, and was the whole answer, until
// 2026-07-30). Answering NSApplicationWillBecomeActiveNotification only works on a run where macOS
// ACTUALLY ACTIVATES the capture. The promotion to Regular and the activation are separate events:
// the check-in promotes unconditionally, the activation is macOS's choice, and when the owner is
// working in the front app it is routinely declined. Measured on this machine, one capture, with
// the notification as the only lever:
//
//     activation arrives      Regular  540 ->  577 ms   (~35 ms)   <- the case every test run hit
//     activation declined     Regular  577 -> 1316 ms   (~606 ms)  <- Regular until exit
//
// So the shim was a coin flip on the very case it exists for — the owner at the keyboard is exactly
// when macOS declines the activation, and exactly when a foreground-eligible capture can hurt. The
// 2 ms poll does not care whether the activation ever comes: it reads the policy back and answers
// the promotion itself. Same capture, same machine, activation declined: Regular for 0 ms, never
// observed foreground-eligible by a 2 ms external sampler, for the whole run.
//
// The poll is bounded by the main run loop being pumped, which is where AppKit calls must happen
// anyway: a capture that blocks its main thread across the check-in stays Regular for as long as it
// blocks. That did not happen in any of the 21 runs measured, but it is the residue, and the
// structural fix for it is FEWER LAUNCHES: see `make shot-batch`.
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

// Read the policy back every tick and answer a promotion nobody in this process asked for. Only
// Regular is acted on: Regular is the foreground-ELIGIBLE state, and it is the one thing that lets
// the window server hand this process the owner's keyboard. Accessory is not, so a run that settles
// at Accessory (which is where a demotion lands while the app is already active — Prohibited is
// refused then) is left alone instead of being re-poked at 500 Hz for the rest of the capture.
static void tu_tick(CFRunLoopTimerRef timer, void *info) {
	(void)timer; (void)info;
	if (NSApp && [NSApp activationPolicy] == NSApplicationActivationPolicyRegular) {
		tu_demote("poll");
	}
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

	// The promotion nobody asked for: catch it by READING the policy back, on the same main run
	// loop AppKit requires for setActivationPolicy:. 2 ms is finer than the 6-35 ms a
	// notification-driven answer ever managed, and unlike a notification it fires whether or not
	// macOS chooses to activate this process. Common modes, so a modal/tracking pump counts too.
	CFRunLoopTimerRef poll = CFRunLoopTimerCreate(kCFAllocatorDefault, CFAbsoluteTimeGetCurrent(),
		0.002, 0, 0, tu_tick, NULL);
	if (poll) {
		CFRunLoopAddTimer(CFRunLoopGetMain(), poll, kCFRunLoopCommonModes);
	}
	if (verbose()) fprintf(stderr, "tu_nofocus: poll timer installed=%d\n", (int)(poll != NULL));

	// Backstop for the poll, on the runs where the activation does arrive: it lands on the same
	// pump, so whichever of the two the run loop reaches first answers it. WillBecomeActive fires
	// before the switch completes; DidBecomeActive covers the rest.
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserverForName:NSApplicationWillBecomeActiveNotification object:nil queue:nil
		usingBlock:^(NSNotification *n) { (void)n; tu_demote("willBecomeActive"); }];
	[nc addObserverForName:NSApplicationDidBecomeActiveNotification object:nil queue:nil
		usingBlock:^(NSNotification *n) { (void)n; tu_demote("didBecomeActive"); }];
	if (verbose()) fprintf(stderr, "tu_nofocus: installed\n");
}
