(function () {
  var root = document.documentElement;
  var shell = document.querySelector(".site-shell");
  var prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
  var downloadButton = document.getElementById("download-button");
  var releaseBadge = document.getElementById("release-badge");
  var fallbackUrl = "https://github.com/premsathisha/text-shot/releases/latest";
  var releaseCacheKey = "text-shot-latest-release-v1";
  var releaseCacheTtl = 6 * 60 * 60 * 1000;
  var installTrigger = document.getElementById("install-trigger");
  var installOverlay = document.getElementById("install-modal-overlay");
  var installModal = document.getElementById("install-modal");
  var dialogClose = document.getElementById("dialog-close");
  var previouslyFocusedElement = null;
  var lockedScrollY = 0;
  var previousBodyStyles = null;
  var previousShellAriaHidden = null;
  var previousShellInert = false;

  window.copyInstallCommand = async function (button) {
    var copied = false;
    var copyValue = button.dataset.copyValue;
    if (!copyValue) return;

    try {
      if (!navigator.clipboard || typeof navigator.clipboard.writeText !== "function") {
        throw new Error("Clipboard API unavailable");
      }
      await navigator.clipboard.writeText(copyValue);
      copied = true;
    } catch (error) {
      var helper = document.createElement("textarea");
      helper.value = copyValue;
      helper.setAttribute("readonly", "");
      helper.style.position = "fixed";
      helper.style.top = "0";
      helper.style.left = "-9999px";
      helper.style.fontSize = "16px";
      helper.style.opacity = "0";
      document.body.appendChild(helper);
      helper.focus({ preventScroll: true });
      helper.select();
      helper.setSelectionRange(0, copyValue.length);
      copied = document.execCommand("copy");
      helper.remove();
    }

    button.classList.toggle("copied", copied);
    button.setAttribute("aria-label", copied ? "Command copied" : "Copy command");
    window.clearTimeout(button.copyResetTimer);
    button.copyResetTimer = window.setTimeout(function () {
      button.classList.remove("copied");
      button.setAttribute("aria-label", "Copy command");
    }, 2000);
  };

  function runModeBlur() {
    if (!shell || prefersReducedMotion.matches) return;
    shell.animate(
      [
        { filter: "blur(3px)", opacity: 0.92 },
        { filter: "blur(0)", opacity: 1 },
      ],
      {
        duration: 900,
        easing: "ease-out",
        fill: "none",
      }
    );
  }

  function normalizeRelease(release) {
    var dmgAsset = Array.isArray(release.assets)
      ? release.assets.find(function (asset) {
          return typeof asset.name === "string" && /\.dmg$/i.test(asset.name);
        })
      : null;

    return {
      tagName: release.tag_name || "",
      htmlUrl: release.html_url || fallbackUrl,
      dmgAsset: dmgAsset
        ? {
            name: dmgAsset.name,
            url: dmgAsset.browser_download_url,
          }
        : null,
    };
  }

  function applyRelease(release) {
    if (release.tagName) {
      releaseBadge.textContent = release.tagName;
      releaseBadge.setAttribute("aria-label", "Current version " + release.tagName);
    }

    if (release.dmgAsset && release.dmgAsset.url) {
      downloadButton.href = release.dmgAsset.url;
      downloadButton.setAttribute("download", release.dmgAsset.name);
    } else {
      downloadButton.href = release.htmlUrl || fallbackUrl;
      downloadButton.removeAttribute("download");
    }
  }

  function readCachedRelease(allowExpired) {
    try {
      var cached = JSON.parse(window.localStorage.getItem(releaseCacheKey));
      if (!cached || !cached.release || !cached.savedAt) return null;
      if (!allowExpired && Date.now() - cached.savedAt > releaseCacheTtl) return null;
      return cached.release;
    } catch (error) {
      return null;
    }
  }

  function writeCachedRelease(release) {
    try {
      window.localStorage.setItem(
        releaseCacheKey,
        JSON.stringify({ release: release, savedAt: Date.now() })
      );
    } catch (error) {
      // Storage may be unavailable for local file previews or privacy-restricted browsers.
    }
  }

  async function wireLatestRelease() {
    if (!downloadButton || !releaseBadge) return;

    var cachedRelease = readCachedRelease(false);
    if (cachedRelease) {
      applyRelease(cachedRelease);
      return;
    }

    try {
      var response = await fetch(
        "https://api.github.com/repos/premsathisha/text-shot/releases/latest",
        { headers: { Accept: "application/vnd.github+json" } }
      );

      if (!response.ok) throw new Error("Failed to fetch latest release");

      var release = normalizeRelease(await response.json());
      writeCachedRelease(release);
      applyRelease(release);
    } catch (error) {
      var staleRelease = readCachedRelease(true);
      if (staleRelease) {
        applyRelease(staleRelease);
      } else {
        downloadButton.href = fallbackUrl;
      }
      console.error("Unable to load latest release", error);
    }
  }

  function addBlur() {
    root.classList.add("window-blurred");
  }

  function removeBlur() {
    root.classList.remove("window-blurred");
  }

  function attachIconFallbacks() {
    var svgIcon = document.querySelector('link[rel="icon"][type="image/svg+xml"]');
    var alternateIcon = document.querySelector('link[rel="alternate icon"]');

    if (svgIcon && alternateIcon) {
      svgIcon.addEventListener("error", function () {
        svgIcon.href = alternateIcon.href;
      });
    }
  }

  function getFocusableElements() {
    if (!installModal) return [];
    return Array.prototype.slice
      .call(
        installModal.querySelectorAll(
          'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'
        )
      )
      .filter(function (element) {
        return element.getAttribute("aria-hidden") !== "true";
      });
  }

  function lockPageScroll() {
    lockedScrollY = window.scrollY || document.documentElement.scrollTop || 0;
    previousBodyStyles = {
      top: document.body.style.top,
      width: document.body.style.width,
      paddingRight: document.body.style.paddingRight,
    };
    var scrollbarWidth = window.innerWidth - document.documentElement.clientWidth;
    document.body.style.top = "-" + lockedScrollY + "px";
    document.body.style.width = "100%";
    if (scrollbarWidth > 0) document.body.style.paddingRight = scrollbarWidth + "px";
    document.body.classList.add("install-modal-open");
  }

  function unlockPageScroll() {
    document.body.classList.remove("install-modal-open");
    if (previousBodyStyles) {
      document.body.style.top = previousBodyStyles.top;
      document.body.style.width = previousBodyStyles.width;
      document.body.style.paddingRight = previousBodyStyles.paddingRight;
    }
    window.scrollTo(0, lockedScrollY);
  }

  function hideBackgroundFromAssistiveTechnology() {
    if (!shell) return;
    previousShellAriaHidden = shell.getAttribute("aria-hidden");
    previousShellInert = Boolean(shell.inert);
    shell.setAttribute("aria-hidden", "true");
    shell.inert = true;
  }

  function restoreBackgroundForAssistiveTechnology() {
    if (!shell) return;
    if (previousShellAriaHidden === null) shell.removeAttribute("aria-hidden");
    else shell.setAttribute("aria-hidden", previousShellAriaHidden);
    shell.inert = previousShellInert;
  }

  function closeInstallDialog() {
    if (!installOverlay) return;
    installOverlay.classList.remove("open");
    installOverlay.setAttribute("aria-hidden", "true");
    installTrigger.setAttribute("aria-expanded", "false");
    restoreBackgroundForAssistiveTechnology();
    unlockPageScroll();
    if (previouslyFocusedElement) previouslyFocusedElement.focus({ preventScroll: true });
  }

  function openInstallDialog() {
    if (!installOverlay || !installModal) return;
    previouslyFocusedElement = document.activeElement;
    lockPageScroll();
    hideBackgroundFromAssistiveTechnology();
    installOverlay.classList.add("open");
    installOverlay.setAttribute("aria-hidden", "false");
    installTrigger.setAttribute("aria-expanded", "true");
    dialogClose.focus({ preventScroll: true });
  }

  function trapModalFocus(event) {
    if (event.key !== "Tab" || !installOverlay.classList.contains("open")) return;

    var focusableElements = getFocusableElements();
    if (!focusableElements.length) {
      event.preventDefault();
      installModal.focus({ preventScroll: true });
      return;
    }

    var firstFocusable = focusableElements[0];
    var lastFocusable = focusableElements[focusableElements.length - 1];
    var activeElement = document.activeElement;

    if (!installModal.contains(activeElement)) {
      event.preventDefault();
      firstFocusable.focus();
    } else if (event.shiftKey && activeElement === firstFocusable) {
      event.preventDefault();
      lastFocusable.focus();
    } else if (!event.shiftKey && activeElement === lastFocusable) {
      event.preventDefault();
      firstFocusable.focus();
    }
  }

  function attachInstallDialog() {
    if (!installTrigger || !installOverlay || !installModal || !dialogClose) return;

    installTrigger.addEventListener("click", openInstallDialog);
    dialogClose.addEventListener("click", closeInstallDialog);
    installOverlay.addEventListener("click", function (event) {
      if (event.target === installOverlay) closeInstallDialog();
    });
    installOverlay.addEventListener(
      "touchmove",
      function (event) {
        if (event.target === installOverlay) event.preventDefault();
      },
      { passive: false }
    );
    document.addEventListener("keydown", function (event) {
      if (!installOverlay.classList.contains("open")) return;
      if (event.key === "Escape") closeInstallDialog();
      else trapModalFocus(event);
    });
  }

  runModeBlur();
  wireLatestRelease();
  attachIconFallbacks();
  attachInstallDialog();

  window.addEventListener("blur", addBlur);
  window.addEventListener("focus", removeBlur);
})();
