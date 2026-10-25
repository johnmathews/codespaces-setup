// Render a built mockup (mockup.py build) as the person will see it: desktop and phone width, in
// the viewer's light and dark theme, full page. Look at every PNG before showing anyone.
//
// Each option already shows its stage in both themes side by side; the two page themes check the
// mockup's own frame and anything that follows the viewer. Needs Playwright: point --playwright at
// a project's node_modules/playwright (its index.mjs), or install it in a scratch folder.
//
// Usage: node render_mockup.mjs <mockup-dir>/dist <out-dir> [--playwright <path/to/playwright/index.mjs>]
//        node render_mockup.mjs --selftest | --version
// Writes desktop-light.png, desktop-dark.png, phone-light.png, phone-dark.png, and prints one line
// per problem: "OVERFLOW <shot>" (the page scrolls sideways), "CONSOLE <shot> <text>" (an error),
// "FAILED <shot> <url>" (a file that didn't load). No lines means none.
import { existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'
import { pathToFileURL } from 'node:url'

// Bump on every change to this file: ci/lint-skill-versions.sh (codespaces-setup) fails a change
// that doesn't.
const SCRIPT_VERSION = 1

// The shots: name, viewport width, the viewer's theme.
export const SHOTS = [
  ['desktop-light', 1280, 'light'],
  ['desktop-dark', 1280, 'dark'],
  ['phone-light', 390, 'light'],
  ['phone-dark', 390, 'dark'],
]

export function pageOf(dist) {
  const page = join(resolve(dist), 'preview.html')
  if (!existsSync(page)) throw new Error(`${page} is missing: run mockup.py build <mockup-dir> first`)
  return page
}

function selftest() {
  const scratch = mkdtempSync(join(tmpdir(), 'render-mockup-test-'))
  const checks = []
  try {
    checks.push(['four shots, each width in each theme',
      SHOTS.length === 4 && new Set(SHOTS.map(([, w, t]) => `${w}${t}`)).size === 4])
    checks.push(['a phone shot is phone width', SHOTS.some(([n, w]) => n.startsWith('phone') && w <= 400)])
    let refused = false
    try { pageOf(scratch) } catch { refused = true }
    checks.push(['refuses a folder with no preview.html', refused])
    writeFileSync(join(scratch, 'preview.html'), '<!doctype html>')
    checks.push(['finds a built preview', pageOf(scratch).endsWith('preview.html')])
  } finally {
    rmSync(scratch, { recursive: true, force: true })
  }
  for (const [name, ok] of checks) console.log(`${ok ? 'ok' : 'FAIL'}  ${name}`)
  return checks.every(([, ok]) => ok) ? 0 : 1
}

async function render(args) {
  const option = (flag, fallback) => (args.includes(flag) ? args[args.indexOf(flag) + 1] ?? fallback : fallback)
  const [dist, out] = args
  if (!dist || !out || dist.startsWith('--')) {
    console.error('usage: node render_mockup.mjs <mockup-dir>/dist <out-dir> [--playwright <index.mjs>] | --selftest | --version')
    return 2
  }
  const url = pathToFileURL(pageOf(dist)).href
  mkdirSync(out, { recursive: true })
  const playwright = option('--playwright', resolve('node_modules/playwright/index.mjs'))
  const { chromium } = await import(pathToFileURL(playwright))
  const browser = await chromium.launch()
  try {
    for (const [name, width, theme] of SHOTS) {
      const page = await browser.newPage({ viewport: { width, height: 900 }, deviceScaleFactor: 2, colorScheme: theme })
      page.on('console', (m) => { if (m.type() === 'error') console.log(`CONSOLE ${name} ${m.text()}`) })
      page.on('requestfailed', (r) => console.log(`FAILED ${name} ${r.url()}`))
      await page.goto(url)
      await page.evaluate(() => document.fonts.ready)
      await page.waitForTimeout(200) // let 120ms colour transitions settle
      if (await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth)) console.log(`OVERFLOW ${name}`)
      await page.screenshot({ path: join(out, `${name}.png`), fullPage: true })
      await page.close()
    }
  } finally {
    await browser.close()
  }
  return 0
}

const args = process.argv.slice(2)
if (args[0] === '--version') console.log(`render_mockup.mjs ${SCRIPT_VERSION}`)
else if (process.argv[1] && resolve(process.argv[1]) === resolve(new URL(import.meta.url).pathname)) {
  process.exitCode = args[0] === '--selftest' ? selftest() : await render(args)
}
