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
