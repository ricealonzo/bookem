// Takes screenshots of the main pages for review. Used by CI.
// Usage: node script/screenshots.mjs http://localhost:3000 out-dir
import { chromium } from "playwright"

const base = process.argv[2] || "http://localhost:3000"
const out = process.argv[3] || "shots"

const sizes = {
  desktop: { width: 1280, height: 900 },
  phone: { width: 390, height: 844 },
}

async function logIn(page, email) {
  await page.goto(`${base}/users/sign_in`)
  await page.fill("#user_email", email)
  await page.fill("#user_password", "password")
  await Promise.all([page.waitForNavigation(), page.click("input[type=submit]")])
}

async function shoot(page, name, fullPage = true) {
  await page.waitForLoadState("networkidle").catch(() => {})
  await page.screenshot({ path: `${out}/${name}.png`, fullPage })
  console.log(`saved ${name}`)
}

const browser = await chromium.launch()

for (const [label, viewport] of Object.entries(sizes)) {
  for (const theme of label === "desktop" ? ["light", "dark"] : ["light"]) {
    const context = await browser.newContext({ viewport, colorScheme: theme })
    const page = await context.newPage()
    page.on("pageerror", (error) => console.log(`::warning::${label} page error: ${error.message}`))
    const suffix = theme === "dark" ? `${label}-dark` : label

    await page.goto(base)
    await shoot(page, `home-${suffix}`)

    const firstLocation = await page.locator(".location-card").first().getAttribute("href")

    await page.goto(`${base}${firstLocation}`)
    await shoot(page, `location-visitor-${suffix}`)

    if (theme === "light") {
      await page.goto(`${base}/users/sign_in`)
      await shoot(page, `login-${suffix}`, false)

      await logIn(page, "guest1@example.com")
      await page.goto(`${base}${firstLocation}`)
      const day = page.locator(".day-pick").nth(3)
      if (await day.count()) await day.click()
      await page.waitForTimeout(600)
      await shoot(page, `location-guest-${suffix}`)

      await page.goto(`${base}/bookings`)
      await shoot(page, `bookings-guest-${suffix}`)

      await page.goto(`${base}/locations/new`)
      await shoot(page, `new-location-${suffix}`)

      await context.clearCookies()
      await logIn(page, process.env.HOST_EMAIL || "host1@example.com")
      await page.goto(`${base}/bookings`)
      await shoot(page, `bookings-host-${suffix}`)
    }

    await context.close()
  }
}

await browser.close()
