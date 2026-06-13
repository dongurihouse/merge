// Tidy Up — browser-side generation helpers (CHATGPT-ONLY, user directive 2026-06-10).
//
// USAGE (the agent must NOT hand-write inline JS for these steps — install this file, then one-liners):
//   1. INSTALL once per page load:  Bash `cat tools/icon_gen_browser.js` → paste whole file into
//      mcp__Claude_in_Chrome__javascript_tool on the ChatGPT tab. Re-install after any navigate.
//   2. Drive the loop with ONE-LINERS:
//        window.tu.submit(`<prompt>`)        → {ok, baseline}  (auto-prefixes the image-tool nudge)
//        window.tu.poll()                    → {ready:false, tail} | {ready:true, w, h}
//        window.tu.download('xyz_raw.png')   → {ok, size, new_baseline}  (→ ~/Downloads/)
//        window.tu.log()                     → full timestamped timeline for reports
//   3. Host side: godot process_icon.gd / process_decor.gd, then godot --import.
//
// Fixed generation thread (never open fresh chats; one growing thread is fine because submit()
// re-snapshots the CURRENT image count as the baseline each time):
//   https://chatgpt.com/c/6a2a1e89-13fc-83e8-9035-42c9ba931433
// Hang rule: poll stuck "Thinking" past ~6.5 min → submit() the same prompt again, same thread.
//
// (Dual-provider Gemini mode was retired 2026-06-10. Gotchas learned, if it ever returns: fresh
//  Gemini gens are blob: <img>s inside the last <model-response> — poll that container, not global
//  counts; fetch() throws on blob: there — export via canvas.toDataURL; first multi-download trips
//  Chrome's per-origin gate and needs one manual Allow.)

(() => {
  const isImg = i => i.naturalWidth >= 512 && !i.src.includes('avatars');
  const imgs = () => Array.from(document.querySelectorAll('img')).filter(isImg);
  window.tu_log = window.tu_log || [];
  window.tu_t0 = window.tu_t0 || Date.now();
  const log = (event, data = {}) => window.tu_log.push({ t: Date.now() - window.tu_t0, event, ...data });

  window.tu = {
    async submit(prompt) {
      window.tu_baseline = imgs().length;   // snapshot BEFORE sending — poll() compares against this
      const ed = document.querySelector('div#prompt-textarea[contenteditable="true"]')
              || document.querySelector('div[contenteditable="true"]');
      if (!ed) { log('submit_fail', { reason: 'NO_EDITOR' }); return { ok: false, reason: 'NO_EDITOR' }; }
      ed.focus(); document.execCommand('selectAll', false);
      document.execCommand('insertText', false, 'Use the image generation tool now. ' + prompt);
      await new Promise(r => setTimeout(r, 300));
      // try send-button, fall back to Enter; then VERIFY the composer emptied (the Enter
      // fallback can silently fail, leaving the prompt sitting in the editor) and retry.
      let method = 'send-btn';
      for (let attempt = 0; attempt < 4; attempt++) {
        const btn = document.querySelector('button[data-testid="send-button"]')
                 || document.querySelector('button[aria-label*="Send"]');
        if (btn && !btn.disabled) { btn.click(); }
        else { ed.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true, cancelable: true })); method = 'enter-key'; }
        await new Promise(r => setTimeout(r, 600));
        if (ed.innerText.trim().length === 0) {
          log('submit', { method, attempt, baseline: window.tu_baseline, head: prompt.slice(0, 60) });
          return { ok: true, method, attempt, baseline: window.tu_baseline };
        }
      }
      log('submit_fail', { reason: 'COMPOSER_NOT_CLEARED' });
      return { ok: false, reason: 'COMPOSER_NOT_CLEARED', editorText: ed.innerText.slice(0, 80) };
    },

    // Message-based readiness (NOT image counts): on long threads ChatGPT virtualizes old
    // messages out of the DOM, so global img counts swing arbitrarily and a count>baseline
    // check breaks. Instead: ready = an ASSISTANT message exists AFTER the last USER message
    // and contains a big image. That pair always stays in the DOM (it's the scroll bottom).
    _lastResponse() {
      const msgs = Array.from(document.querySelectorAll('[data-message-author-role]'));
      const lastUserIdx = msgs.map((m, i) => m.getAttribute('data-message-author-role') === 'user' ? i : -1).filter(i => i >= 0).pop();
      if (lastUserIdx === undefined) return { asst: null, reason: 'no user message' };
      const asst = msgs.slice(lastUserIdx + 1).find(m => m.getAttribute('data-message-author-role') === 'assistant');
      return { asst, reason: asst ? null : 'no response yet' };
    },

    poll() {
      const { asst, reason } = this._lastResponse();
      if (!asst) { log('poll_waiting', { reason }); return { ready: false, reason, tail: document.body.innerText.slice(-90) }; }
      const a = Array.from(asst.querySelectorAll('img')).filter(i => i.naturalWidth >= 512);
      if (!a.length) { log('poll_waiting', { reason: 'response no img' }); return { ready: false, reason: 'response no img', head: asst.innerText.slice(0, 60) }; }
      const last = a[a.length - 1];
      log('poll_ready', { w: last.naturalWidth, h: last.naturalHeight });
      return { ready: true, w: last.naturalWidth, h: last.naturalHeight };
    },

    async download(name) {
      const { asst } = this._lastResponse();
      const a = asst ? Array.from(asst.querySelectorAll('img')).filter(i => i.naturalWidth >= 512) : imgs();
      if (!a.length) { log('download_fail', { reason: 'NO_IMG' }); return { ok: false, reason: 'NO_IMG' }; }
      const t = a[a.length - 1];
      let blob;
      try { blob = await (await fetch(t.currentSrc || t.src, { credentials: 'include' })).blob(); }
      catch (e) { log('download_fail', { reason: 'FETCH', e: String(e) }); return { ok: false, reason: 'FETCH_FAIL', err: String(e) }; }
      const url = URL.createObjectURL(blob);
      const el = document.createElement('a'); el.href = url; el.download = name; el.style.display = 'none';
      document.body.appendChild(el); el.click();
      await new Promise(r => setTimeout(r, 400)); el.remove(); URL.revokeObjectURL(url);
      log('download', { name, size: blob.size });
      return { ok: true, size: blob.size, w: t.naturalWidth, h: t.naturalHeight, new_baseline: window.tu_baseline };
    },

    log() { return { log: window.tu_log, elapsed_ms: Date.now() - window.tu_t0 }; }
  };

  return { installed: true, imgs_now: imgs().length, baseline: window.tu_baseline ?? null };
})();
