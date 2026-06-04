// Pix key — copy to clipboard with a small "Copied!" confirmation.
(function () {
  "use strict";

  var btn = document.getElementById("pix-copy");
  var status = document.getElementById("pix-status");
  if (!btn || !status) return;

  var resetTimer;

  function confirm(message) {
    status.textContent = message;
    clearTimeout(resetTimer);
    resetTimer = setTimeout(function () {
      status.textContent = "";
    }, 2500);
  }

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

  btn.addEventListener("click", function () {
    var key = btn.getAttribute("data-key") || "";

    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(key).then(
        function () { confirm("Copied! ✓"); },
        function () { confirm(fallbackCopy(key) ? "Copied! ✓" : "Copy this: " + key); }
      );
    } else {
      confirm(fallbackCopy(key) ? "Copied! ✓" : "Copy this: " + key);
    }
  });
})();
