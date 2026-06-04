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

  var commandBtn = document.getElementById("command-copy");
  if (commandBtn) {
    var commandLabel = commandBtn.querySelector("span");
    var commandNextSteps = document.getElementById("command-next-steps");
    var commandResetTimer;

    function confirmCommand(message) {
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
  }

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
