// Copy helpers for the install command and Pix key.
(function () {
  "use strict";

  function fallbackCopy(text) {
    var ta = document.createElement("textarea");
    ta.value = text;
    ta.setAttribute("readonly", "");
    ta.style.position = "absolute";
    ta.style.left = "-9999px";
    document.body.appendChild(ta);
    ta.select();
    var ok = false;
    try { ok = document.execCommand("copy"); } catch (e) { ok = false; }
    document.body.removeChild(ta);
    return ok;
  }

  function copyText(text, onSuccess, onFailure) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(
        onSuccess,
        function () { fallbackCopy(text) ? onSuccess() : onFailure(); }
      );
    } else {
      fallbackCopy(text) ? onSuccess() : onFailure();
    }
  }

  var commandBtns = document.querySelectorAll(".command-copy__button");
  commandBtns.forEach(function (commandBtn) {
    var commandLabel = commandBtn.querySelector("span");
    var nextStepsId = commandBtn.getAttribute("aria-controls");
    var commandNextSteps = nextStepsId ? document.getElementById(nextStepsId) : null;
    var commandResetTimer;

    function confirmCommand(message) {
      if (!commandLabel) return;
      commandLabel.textContent = message;
      clearTimeout(commandResetTimer);
      commandResetTimer = setTimeout(function () {
        commandLabel.textContent = "Copy";
      }, 2500);
    }

    commandBtn.addEventListener("click", function () {
      var command = commandBtn.getAttribute("data-command") || "";
      if (commandNextSteps) {
        commandNextSteps.hidden = false;
        commandBtn.setAttribute("aria-expanded", "true");
      }
      copyText(
        command,
        function () { confirmCommand("Copied! ✓"); },
        function () { confirmCommand("Copy failed"); }
      );
    });
  });

  var pixBtn = document.getElementById("pix-copy");
  var pixStatus = document.getElementById("pix-status");
  if (pixBtn && pixStatus) {
    var pixResetTimer;

    function confirmPix(message) {
      pixStatus.textContent = message;
      clearTimeout(pixResetTimer);
      pixResetTimer = setTimeout(function () {
        pixStatus.textContent = "";
      }, 2500);
    }

    pixBtn.addEventListener("click", function () {
      var key = pixBtn.getAttribute("data-key") || "";
      copyText(
        key,
        function () { confirmPix("Copied! ✓"); },
        function () { confirmPix("Copy this: " + key); }
      );
    });
  }
})();

// Demo animation — loops a scripted Claude Code session: the user types a
// prompt, Claude asks permission, the notification card pops up, Enter
// focuses the terminal, Claude finishes. Runs once per .demo instance (hero
// and "See it in action") and pauses whenever scrolled offscreen.
(function () {
  "use strict";

  var PROMPT = "add retries to AuthClient and run tests";

  function initDemo(root) {
    var term = root.querySelector(".demo__terminal");
    if (!term) return;
    var typed = root.querySelector(".demo__typed");
    var caret = root.querySelector(".dl__caret");
    var notifPerm = root.querySelector(".demo__notif:not(.demo__notif--done)");
    var notifDone = root.querySelector(".demo__notif--done");
    var key = root.querySelector(".demo__key");
    var optYes = root.querySelector(".demo__perm-opt.is-sel");

    function line(s) { return root.querySelector('[data-s="' + s + '"]'); }
    function show(s) { line(s).classList.add("on"); }

    // Reduced motion: render the final frame, no timers.
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      ["1", "2", "3", "5", "6", "8", "9", "10"].forEach(show);
      line("4").classList.add("gone");
      line("7").classList.add("gone");
      typed.textContent = PROMPT;
      caret.classList.add("off");
      notifDone.classList.add("on");
      return;
    }

    // Bumping `gen` makes every pending sleep reject, stopping the loop.
    var gen = 0;

    function sleep(ms) {
      var g = gen;
      return new Promise(function (resolve, reject) {
        setTimeout(function () {
          g === gen ? resolve() : reject(new Error("demo-stopped"));
        }, ms);
      });
    }

    function typeChar(i) {
      if (i >= PROMPT.length) return Promise.resolve();
      typed.textContent += PROMPT.charAt(i);
      return sleep(24 + Math.random() * 36).then(function () { return typeChar(i + 1); });
    }

    function reset() {
      var nodes = root.querySelectorAll(".dl");
      for (var i = 0; i < nodes.length; i++) nodes[i].classList.remove("on", "gone");
      typed.textContent = "";
      caret.classList.remove("off");
      optYes.classList.remove("is-hit");
      notifPerm.classList.remove("on", "bye");
      notifDone.classList.remove("on", "bye");
      key.classList.remove("on", "press");
      term.classList.remove("is-focus");
    }

    function play() {
      reset();
      sleep(500)
        .then(function () { show("1"); return sleep(600); })
        .then(function () { show("2"); return sleep(700); })
        .then(function () { show("3"); return sleep(350); })
        .then(function () { return typeChar(0); })
        .then(function () { return sleep(450); })
        .then(function () { caret.classList.add("off"); show("4"); return sleep(1100); })
        .then(function () { show("5"); return sleep(500); })
        .then(function () { show("6"); return sleep(800); })
        .then(function () { line("4").classList.add("gone"); show("7"); return sleep(650); })
        .then(function () { notifPerm.classList.add("on"); return sleep(2300); })
        .then(function () { key.classList.add("on"); return sleep(1300); })
        .then(function () {
          key.classList.add("press");
          optYes.classList.add("is-hit");
          term.classList.add("is-focus");
          notifPerm.classList.add("bye");
          return sleep(650);
        })
        .then(function () {
          key.classList.remove("on", "press");
          line("7").classList.add("gone");
          show("8");
          return sleep(950);
        })
        .then(function () { show("9"); return sleep(700); })
        .then(function () { show("10"); return sleep(600); })
        .then(function () {
          term.classList.remove("is-focus");
          notifDone.classList.add("on");
          return sleep(3200);
        })
        .then(function () { notifDone.classList.add("bye"); return sleep(900); })
        .then(play)
        .catch(function () { /* stopped — restarts when scrolled back into view */ });
    }

    var running = false;
    if ("IntersectionObserver" in window) {
      var io = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting && !running) {
            running = true;
            play();
          } else if (!entry.isIntersecting && running) {
            running = false;
            gen++;
            reset();
          }
        });
      }, { threshold: 0.25 });
      io.observe(root);
    } else {
      play();
    }
  }

  // The hero shows the same demo: clone the stage markup from the section.
  var source = document.getElementById("ccn-demo");
  var heroSlot = document.getElementById("hero-demo");
  if (source && heroSlot) heroSlot.innerHTML = source.innerHTML;

  var demos = document.querySelectorAll(".demo");
  for (var i = 0; i < demos.length; i++) initDemo(demos[i]);
})();

// Page view tracker — fire-and-forget, deduplicates by IP per day server-side.
(function () {
  "use strict";
  fetch("/tracker.php").catch(function () { /* ignore */ });
})();

// GitHub download counter — sums download_count across all release assets.
// Public API, no auth (60 req/h per IP). Stays hidden if there are no releases.
(function () {
  "use strict";

  var wrap = document.getElementById("dl-count");
  var num = document.getElementById("dl-count-num");
  if (!wrap || !num) return;

  fetch("https://api.github.com/repos/narlei/claudecodenotify/releases")
    .then(function (res) { return res.ok ? res.json() : Promise.reject(res.status); })
    .then(function (releases) {
      if (!Array.isArray(releases)) return;
      var total = releases.reduce(function (sum, rel) {
        return sum + (rel.assets || []).reduce(function (s, a) {
          return s + (a.download_count || 0);
        }, 0);
      }, 0);

      if (total > 0) {
        num.textContent = total.toLocaleString("en-US");
        wrap.hidden = false;
      }
    })
    .catch(function () { /* offline, rate-limited, or no releases — stay hidden */ });
})();

// Click tracking for buttons & important links (sends to the same analytics as page views).
// Uses data-track="event-name" on elements. Works for nav, hero CTAs, download buttons,
// copy commands, support cards, and social links. Deduped per IP+day+event server-side.
(function () {
  "use strict";

  function sendEvent(name) {
    if (!name) return;
    var url = "/event.php?name=" + encodeURIComponent(name);

    // Try multiple methods for maximum compatibility (especially Safari)
    var sent = false;

    // 1. sendBeacon — designed exactly for this (analytics on navigation/unload)
    if (navigator.sendBeacon) {
      try {
        sent = navigator.sendBeacon(url);
      } catch (e) {}
    }

    // 2. fetch + keepalive — modern and reliable in recent Safari
    if (!sent) {
      try {
        fetch(url, { keepalive: true, cache: 'no-store' }).catch(function () {});
        sent = true;
      } catch (e) {}
    }

    // 3. Classic <img> beacon — extremely reliable fallback, works in all Safari versions
    if (!sent) {
      try {
        var img = new Image(1, 1);
        img.src = url + '&_=' + Date.now(); // cache buster
      } catch (e) {}
    }
  }

  // Global helper (useful for manual testing in console)
  window.__ccnTrack = sendEvent;

  // Automatic: any click on (or inside) an element with data-track
  document.addEventListener("click", function (ev) {
    var target = ev.target.closest("[data-track]");
    if (target) {
      var name = target.getAttribute("data-track");
      sendEvent(name);
    }
  }, { capture: true });
})();
