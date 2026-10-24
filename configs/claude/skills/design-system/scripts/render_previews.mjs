// Render every design-system component preview at one width in every theme, roughly as the
// artifact page frames them, and report any page that scrolls sideways.
//
// The claude.ai page can't be resized below desktop from a browser extension, so this is how to
// check phone width (and dark mode) before publishing. Needs Playwright: point --playwright at a
// project's node_modules/playwright (its index.mjs), or install it in a scratch folder.
//
// Usage: node render_previews.mjs <system-dir> <out-dir> [--width 375] [--playwright <path/to/playwright/index.mjs>]
// Prints "OVERFLOW <Component> <theme>" per offender (the cover overflows by design: it is a
// fixed 960px layout the page scales down). Then look at the PNGs.
import { mkdirSync, readFileSync, readdirSync } from 'node:fs'
import { join, resolve } from 'node:path'
import { pathToFileURL } from 'node:url'

// Bump on every change to this file: ci/lint-skill-versions.sh (codespaces-setup) fails a change
// that doesn't.
const SCRIPT_VERSION = 1

const args = process.argv.slice(2)
const option = (flag, fallback) => (args.includes(flag) ? args[args.indexOf(flag) + 1] : fallback)
const [system, out] = args
if (!system || !out) {
  console.error('usage: node render_previews.mjs <system-dir> <out-dir> [--width 375] [--playwright <index.mjs>]')
  process.exit(2)
}
const project = resolve(system, 'project')
const width = Number(option('--width', '375'))
const playwright = option('--playwright', resolve('node_modules/playwright/index.mjs'))
const { chromium } = await import(pathToFileURL(playwright))

const tokens = JSON.parse(readFileSync(join(project, 'tokens.json'), 'utf8'))
const themes = tokens.color.themes.map((t) => t.id)
const val = (t, th) => (typeof t.value === 'string' ? t.value : t.value[th] ?? t.value[themes[0]])
let css = ''
for (const th of themes) {
  const sel = th === themes[0] ? `:root, [data-theme="${th}"]` : `[data-theme="${th}"]`
  const themed = [...tokens.color.tokens, ...(tokens.shadow?.tokens ?? [])]
  css += `${sel} {${themed.map((t) => `--${t.name}:${val(t, th)};`).join('')}}\n`
}
const scales = ['spacing', 'radius'].flatMap((f) => tokens[f]?.tokens ?? [])
css += `:root {${scales.map((t) => `--${t.name}:${t.value};`).join('')}`
css += Object.entries(tokens.type.families).map(([k, v]) => `--font-${k}:${v};`).join('') + '}\n'
for (const g of tokens.type.groups) for (const s of g.styles) {
  css += `.${s.name}{font-family:var(--font-${s.family ?? g.family});font-size:${s.fontSize};line-height:${s.lineHeight};font-weight:${s.fontWeight};letter-spacing:${s.letterSpacing ?? 0}}\n`
}
for (const f of tokens.type.fonts ?? []) {
  if (f.file) css += `@font-face{font-family:"${f.family}";src:url("${pathToFileURL(join(project, f.file))}");font-weight:${f.weight}}\n`
}

mkdirSync(out, { recursive: true })
const browser = await chromium.launch()
const page = await browser.newPage({ viewport: { width, height: 800 } })
for (const comp of readdirSync(join(project, 'components'))) {
  let html
  try { html = readFileSync(join(project, 'components', comp, 'preview.html'), 'utf8') } catch { continue }
  html = html.replace(/^<!-- @dsCard\b[^>]*-->\n?/, '') // a comment before <!doctype> means quirks mode
  for (const th of themes) {
    const doc = html.replace('<head>', `<head><style>${css}</style>`).replace('<html', `<html data-theme="${th}"`)
    await page.setContent(doc, { waitUntil: 'load' })
    await page.evaluate(() => document.fonts.ready)
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth)
    await page.screenshot({ path: join(out, `${comp}-${th}.png`), fullPage: true })
    if (overflow) console.log(`OVERFLOW ${comp} ${th}`)
  }
}
await browser.close()
console.log(`rendered into ${out}`)
