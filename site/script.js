const versionPill = document.querySelector("#version-pill");
const yearNode = document.querySelector("#year");

if (yearNode) {
  yearNode.textContent = new Date().getFullYear().toString();
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

loadLatestVersion();
