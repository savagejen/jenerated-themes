// Screenshots each palette in the Palette Creator's preview, for
// palettes/README.md. Run by screenshots.py, which starts the Palette Creator
// (on a copy of the repository) and provides Playwright.
//
// Usage: node screenshots.js <page-url> <screenshots-dir> <palette-file>...
// Each palette file is named as the Palette Creator lists them, like
// Dark/<slug>-palette.toml, and its screenshot is written to the same folder
// of <screenshots-dir>, like <screenshots-dir>/Dark/<slug>.png.

const { chromium } = require("playwright");
const path = require("path");

const [, , base, screenshotsDir, ...files] = process.argv;

(async () => {
  const browser = await chromium.launch();
  // Every address below is a path on the Palette Creator's page (base).
  const page = await browser.newPage({ baseURL: base, viewport: { width: 1440, height: 900 } });
  const errors = [];
  page.on("pageerror", (error) => errors.push(error.message));

  // Open the page once; each palette below reloads it.
  await page.goto("/");

  for (const file of files) {
    const slug = path.basename(file).replace(/-palette\.toml$/, "");
    const out = path.join(screenshotsDir, path.dirname(file), `${slug}.png`);
    // Load the palette the way the page's "Load from..." does.
    const response = await page.request.post("/api/load", { data: { filename: file } });
    const result = await response.json();
    if (!result.ok) throw new Error(`${file}: ${result.error || "not loaded"}`);

    // Reload the page, so it shows the palette just loaded.
    await page.reload();
    await page.waitForFunction(
      () => document.getElementById("status").textContent.startsWith("Looks good"));
    // Keep the mouse off the preview, so nothing is highlighted.
    await page.mouse.move(0, 0);
    await page.locator("#preview").screenshot({ path: out });
    console.log(`Screenshot of ${slug}`);
  }

  await browser.close();
  if (errors.length) throw new Error(`the page had errors: ${errors.join("; ")}`);
})().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
