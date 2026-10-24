// Accessibility and phone-width gate for an app built on the design system.
// Copy into the project's Playwright suite (e.g. e2e/a11y.spec.ts) and list its real pages.
// Needs: @playwright/test, @axe-core/playwright.
//
// Two lessons are baked in:
// - Components animate colour, outline and size (`transition-all` in shadcn-vue). Measuring right
//   after a theme switch or a focus change reads a half-way value, so wait before asserting.
// - Dark mode is a .dark class on <html>; flip it directly rather than emulating the media query,
//   so the test doesn't depend on how the app reads the preference.
import AxeBuilder from '@axe-core/playwright'
import { expect, test } from '@playwright/test'

const PAGES = ['/'] // every public page, including the depth pages
const SETTLE_MS = 600 // longer than the slowest transition

for (const path of PAGES) {
  for (const theme of ['light', 'dark'] as const) {
    test(`${path} has no WCAG A/AA violations in ${theme}`, async ({ page }) => {
      await page.goto(path)
      await page.evaluate((t) => document.documentElement.classList.toggle('dark', t === 'dark'), theme)
      await page.waitForTimeout(SETTLE_MS)
      const { violations } = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa']).analyze()
      expect(violations.map((v) => `${v.id}: ${v.nodes.map((n) => n.target.join(' ')).join(', ')}`)).toEqual([])
    })
  }

  test(`${path} does not scroll sideways at 375px`, async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 800 })
    await page.goto(path)
    await page.waitForTimeout(SETTLE_MS)
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true)
  })
}

test('the focus ring is a solid 2px outline at a 2px offset', async ({ page }) => {
  await page.goto(PAGES[0])
  await page.keyboard.press('Tab')
  await page.waitForTimeout(SETTLE_MS)
  const ring = await page.evaluate(() => {
    const s = getComputedStyle(document.activeElement as Element)
    return `${s.outlineStyle} ${s.outlineWidth} ${s.outlineOffset}`
  })
  expect(ring).toBe('solid 2px 2px')
})
