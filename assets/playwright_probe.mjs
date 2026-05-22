import {chromium} from "playwright-core"

const url = process.argv[2]

if (!url) {
  console.error("usage: node playwright_probe.mjs <url>")
  process.exit(2)
}

const browser = await chromium.launch({headless: true})
const page = await browser.newPage({viewport: {width: 960, height: 640}})

try {
  await page.goto(url, {waitUntil: "networkidle", timeout: 10_000})
  const title = await page.title()
  const before = await page.locator("#state").textContent({timeout: 2_000}).catch(() => null)
  await page.locator("#demo-action").click({timeout: 2_000})
  const after = await page.locator("#state").textContent({timeout: 2_000}).catch(() => null)
  const screenshot = await page.screenshot({type: "png", fullPage: false})

  console.log(JSON.stringify({
    url,
    title,
    summary: `Clicked demo page action: ${before || "unknown"} -> ${after || "unknown"}`,
    steps: [
      "Navigated to target page",
      "Read initial DOM state",
      "Clicked #demo-action",
      "Read changed DOM state",
      "Captured screenshot"
    ],
    before,
    after,
    clicked: after === "clicked by browser agent",
    mode: "live",
    screenshot: `data:image/png;base64,${screenshot.toString("base64")}`
  }))
} finally {
  await browser.close()
}
