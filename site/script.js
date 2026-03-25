const storageKey = "prem-website-theme";
const body = document.body;
const timeNode = document.getElementById("mst-time");
const timeIconNode = document.getElementById("footer-time-icon-svg");
const themeToggle = document.getElementById("theme-toggle");
const versionPill = document.getElementById("version-pill");

const formatter = new Intl.DateTimeFormat("en-US", {
  hour: "2-digit",
  minute: "2-digit",
  hour12: false,
  timeZone: "America/Phoenix",
});

const footerTimeIconMarkup = {
  sunrise: `
    <path d="M12 2v8" />
    <path d="m4.93 10.93 1.41 1.41" />
    <path d="M2 18h2" />
    <path d="M20 18h2" />
    <path d="m19.07 10.93-1.41 1.41" />
    <path d="M22 22H2" />
    <path d="m8 6 4-4 4 4" />
    <path d="M16 18a4 4 0 0 0-8 0" />
  `,
  sun: `
    <circle cx="12" cy="12" r="4" />
    <path d="M12 2v2" />
    <path d="M12 20v2" />
    <path d="m4.93 4.93 1.41 1.41" />
    <path d="m17.66 17.66 1.41 1.41" />
    <path d="M2 12h2" />
    <path d="M20 12h2" />
    <path d="m6.34 17.66-1.41 1.41" />
    <path d="m19.07 4.93-1.41 1.41" />
  `,
  moon: `
    <path d="M20.985 12.486a9 9 0 1 1-9.473-9.472c.405-.022.617.46.402.803a6 6 0 0 0 8.268 8.268c.344-.215.825-.004.803.401" />
  `,
};

function getPhoenixHour(date) {
  const phoenixHour = new Intl.DateTimeFormat("en-US", {
    hour: "2-digit",
    hour12: false,
    timeZone: "America/Phoenix",
  }).format(date);

  return Number.parseInt(phoenixHour, 10);
}

function renderFooterTimeIcon(date) {
  if (!timeIconNode) return;

  const hour = getPhoenixHour(date);
  const iconKey = hour >= 5 && hour < 9 ? "sunrise" : hour >= 9 && hour < 18 ? "sun" : "moon";
  const nextMarkup = footerTimeIconMarkup[iconKey];

  if (timeIconNode.dataset.icon !== iconKey) {
    timeIconNode.innerHTML = nextMarkup;
    timeIconNode.dataset.icon = iconKey;
  }
}

function renderMstTime() {
  if (!timeNode) return;
  const now = new Date();
  timeNode.textContent = `${formatter.format(now)} MST`;
  renderFooterTimeIcon(now);
}

function applyTheme(theme) {
  const nextTheme = theme === "dark" ? "dark" : "light";
  body.dataset.theme = nextTheme;

  if (themeToggle) {
    const isDark = nextTheme === "dark";
    themeToggle.setAttribute("aria-pressed", String(isDark));
    themeToggle.setAttribute("aria-label", isDark ? "Switch to light mode" : "Switch to dark mode");
  }
}

function getInitialTheme() {
  const storedTheme = window.localStorage.getItem(storageKey);
  if (storedTheme === "light" || storedTheme === "dark") return storedTheme;

  return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
}

async function loadLatestVersion() {
  if (!versionPill) {
    return;
  }

  try {
    const response = await fetch("./dist-appcast/appcast.xml", { cache: "no-store" });
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    const xmlText = await response.text();
    const xml = new DOMParser().parseFromString(xmlText, "application/xml");
    const version =
      xml.querySelector("sparkle\\:shortVersionString")?.textContent ||
      xml.querySelector("sparkle\\:version")?.textContent ||
      xml.querySelector("item > title")?.textContent;

    if (!version) {
      throw new Error("Missing version");
    }

    versionPill.textContent = `Latest version: ${version}`;
  } catch (error) {
    versionPill.textContent = "Latest version available on GitHub Releases";
    console.error("Unable to load appcast version", error);
  }
}

applyTheme(getInitialTheme());
renderMstTime();
loadLatestVersion();
window.setInterval(renderMstTime, 1000);

if (themeToggle) {
  themeToggle.addEventListener("click", () => {
    const nextTheme = body.dataset.theme === "dark" ? "light" : "dark";
    applyTheme(nextTheme);
    window.localStorage.setItem(storageKey, nextTheme);
  });
}
