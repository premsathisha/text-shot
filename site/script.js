(function () {
  var root = document.documentElement;
  var shell = document.querySelector(".site-shell");
  var prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
  var downloadButton = document.getElementById("download-button");
  var releaseBadge = document.getElementById("release-badge");
  var fallbackUrl = "https://github.com/premsathisha/text-shot/releases/latest";

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

  async function wireLatestRelease() {
    if (!downloadButton || !releaseBadge) return;

    try {
      var response = await fetch(
        "https://api.github.com/repos/premsathisha/text-shot/releases/latest",
        {
          headers: { Accept: "application/vnd.github+json" },
          cache: "no-store",
        }
      );

      if (!response.ok) {
        throw new Error("Failed to fetch latest release");
      }

      var release = await response.json();
      var dmgAsset = Array.isArray(release.assets)
        ? release.assets.find(function (asset) {
            return typeof asset.name === "string" && /\.dmg$/i.test(asset.name);
          })
        : null;

      if (release.tag_name) {
        releaseBadge.textContent = release.tag_name;
      }

      if (dmgAsset && dmgAsset.browser_download_url) {
        downloadButton.href = dmgAsset.browser_download_url;
        downloadButton.setAttribute("download", dmgAsset.name);
      } else if (release.html_url) {
        downloadButton.href = release.html_url;
      } else {
        downloadButton.href = fallbackUrl;
      }
    } catch (error) {
      downloadButton.href = fallbackUrl;
      console.error("Unable to load latest release", error);
    }
  }

  function addBlur() {
    root.classList.add("window-blurred");
  }

  function removeBlur() {
    root.classList.remove("window-blurred");
  }

  runModeBlur();
  wireLatestRelease();

  if (window.lucide && typeof window.lucide.createIcons === "function") {
    window.lucide.createIcons();
  }

  window.addEventListener("blur", addBlur);
  window.addEventListener("focus", removeBlur);
})();
