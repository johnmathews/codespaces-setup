// Accessibility and phone-width gate for an app built on the design system.
// Copy into the project's Playwright suite (e.g. e2e/a11y.spec.ts) and list its real pages.
// Needs: @playwright/test, @axe-core/playwright.
//
// Two lessons are baked in:
// - Components animate colour, outline and size (`transition-all` in shadcn-vue). Measuring right
//   after a theme switch or a focus change reads a half-way value, so wait before asserting.
// - Dark mode is flipped directly on <html> rather than by emulating the media query, so the test
//   doesn't depend on how the app reads the preference.
//
// DARK must match the selector tokens.css was generated with (design_preview.py --dark-selector,
// default `.dark`). If they disagree, flipping it changes nothing and every "dark" audit quietly
// re-runs light; the first test below exists to fail in exactly that case.
import AxeBuilder from '@axe-core/playwright'
import { expect, test, type Page } from '@playwright/test'

const PAGES = ['/'] // every public page, including the depth pages
const SETTLE_MS = 600 // longer than the slowest transition

// Tailwind and shadcn-vue apps: { class: 'dark' }. A [data-theme] app: { attribute: 'data-theme' }.
const DARK: { class: string } | { attribute: string } = { class: 'dark' }

async function setTheme(page: Page, theme: 'light' | 'dark') {
  await page.evaluate(
    ({ dark, on }) => {
      const root = document.documentElement
      if ('class' in dark) root.classList.toggle(dark.class, on)
      else root.setAttribute(dark.attribute, on ? 'dark' : 'light')
    },
    { dark: DARK, on: theme === 'dark' },
  )
  await page.waitForTimeout(SETTLE_MS)
}

test('switching to dark changes the page (DARK matches tokens.css)', async ({ page }) => {
  await page.goto(PAGES[0])
  // The token itself, not a painted colour: an app may put its background on <html> or <body>.
  const canvas = () =>
    page.evaluate(() => getComputedStyle(document.documentElement).getPropertyValue('--canvas').trim())
  await setTheme(page, 'light')
  const light = await canvas()
  await setTheme(page, 'dark')
  expect(await canvas(), '--canvas is identical in both themes').not.toBe(light)
})

for (const path of PAGES) {
  for (const theme of ['light', 'dark'] as const) {
    test(`${path} has no WCAG A/AA violations in ${theme}`, async ({ page }) => {
      await page.goto(path)
      await setTheme(page, theme)
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
