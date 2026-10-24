// Render every design-system component preview at one width in every theme, roughly as the
// artifact page frames them, and report any page that scrolls sideways.
//
// The claude.ai page can't be resized below desktop from a browser extension, so this is how to
// check phone width (and dark mode) before publishing. Needs Playwright: point --playwright at a
// project's node_modules/playwright (its index.mjs), or install it in a scratch folder. Needs
// python3 too: the token CSS comes from design_preview.py beside this file, so the previews here
// and in the gallery are styled by one compiler, not two that drift apart.
//
// Usage: node render_previews.mjs <system-dir> <out-dir> [--width 375] [--playwright <path/to/playwright/index.mjs>]
//        node render_previews.mjs --selftest
// Prints "OVERFLOW <Component> <theme>" per offender (the cover overflows by design: it is a
// fixed 960px layout the page scales down). Then look at the PNGs.
import { spawnSync } from 'node:child_process'
import { mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

// Bump on every change to this file: ci/lint-skill-versions.sh (codespaces-setup) fails a change
// that doesn't.
const SCRIPT_VERSION = 1

const here = dirname(fileURLToPath(import.meta.url))

// tokens.css as design_preview.py compiles it, with the dark theme on [data-theme], which is how
// themedDoc switches themes (and how the artifact page does).
export function tokensCss(system) {
  const scratch = mkdtempSync(join(tmpdir(), 'render-previews-'))
  try {
    const out = join(scratch, 'tokens.css')
    const fonts = pathToFileURL(resolve(system, 'project', 'fonts')).href
    const args = [join(here, 'design_preview.py'), system, '--tokens-css', out,
      '--dark-selector', '[data-theme="dark"]', '--font-base', fonts]
    const run = spawnSync('python3', args, { encoding: 'utf8' })
    if (run.status !== 0) throw new Error(`design_preview.py failed: ${run.stderr || run.error}`)
    return readFileSync(out, 'utf8')
  } finally {
    rmSync(scratch, { recursive: true, force: true })
  }
}

// One preview as a standalone page in one theme.
export function themedDoc(preview, css, theme) {
  return preview
    .replace(/^<!-- @dsCard\b[^>]*-->\n?/, '') // a comment before <!doctype> means quirks mode
    .replace('<head>', `<head><style>${css}</style>`)
    .replace('<html', `<html data-theme="${theme}"`)
}

function selftest() {
  const scratch = mkdtempSync(join(tmpdir(), 'render-previews-test-'))
  const checks = []
  try {
    const project = join(scratch, 'project')
    mkdirSync(join(project, 'components'), { recursive: true })
    const tokens = {
      color: { themes: [{ id: 'light' }, { id: 'dark' }],
        tokens: [{ name: 'ink', value: { light: '#111111', dark: '#eeeeee' }, usage: 'Text.' }] },
      type: { families: { sans: 'system-ui' }, fonts: [{ family: 'Acme', file: 'fonts/acme.woff2', weight: '400' }],
        groups: [{ name: 'Text', family: 'sans', styles: [{ name: 'body', fontSize: '16px', lineHeight: '24px', fontWeight: 400 }] }] },
    }
    writeFileSync(join(project, 'tokens.json'), JSON.stringify(tokens))
    const css = tokensCss(scratch)
    checks.push(['the CSS comes from design_preview.py', css.includes('generated from tokens.json')])
    checks.push(['dark sits on [data-theme], which themedDoc sets', css.includes('[data-theme="dark"] {') && css.includes('--ink: #eeeeee;')])
    checks.push(['fonts resolve to the system\'s fonts/ folder', css.includes(pathToFileURL(join(project, 'fonts')).href + '/acme.woff2')])
    const doc = themedDoc('<!-- @dsCard group="Basics" height=90 -->\n<!doctype html><html><head></head><body>Go</body></html>', 'X{}', 'dark')
    checks.push(['the marker is stripped, so the doctype comes first', doc.startsWith('<!doctype html>')])
    checks.push(['the theme is set on <html>', doc.includes('<html data-theme="dark">')])
    checks.push(['the CSS is injected into <head>', doc.includes('<head><style>X{}</style>')])
  } finally {
    rmSync(scratch, { recursive: true, force: true })
  }
  for (const [name, ok] of checks) console.log(`${ok ? 'ok  ' : 'FAIL'} ${name}`)
  return checks.every(([, ok]) => ok) ? 0 : 1
}

async function render(args) {
  const option = (flag, fallback) => (args.includes(flag) ? args[args.indexOf(flag) + 1] ?? fallback : fallback)
  const [system, out] = args
  if (!system || !out || system.startsWith('-')) {
    console.error('usage: node render_previews.mjs <system-dir> <out-dir> [--width 375] [--playwright <index.mjs>]')
    return 2
  }
  const project = resolve(system, 'project')
  const width = Number(option('--width', '375'))
  const playwright = option('--playwright', resolve('node_modules/playwright/index.mjs'))
  const { chromium } = await import(pathToFileURL(playwright))
  const themes = JSON.parse(readFileSync(join(project, 'tokens.json'), 'utf8')).color.themes.map((t) => t.id)
  const css = tokensCss(system)

  mkdirSync(out, { recursive: true })
  const browser = await chromium.launch()
  const page = await browser.newPage({ viewport: { width, height: 800 } })
  for (const comp of readdirSync(join(project, 'components'))) {
    let preview
    try { preview = readFileSync(join(project, 'components', comp, 'preview.html'), 'utf8') } catch { continue }
    for (const th of themes) {
      await page.setContent(themedDoc(preview, css, th), { waitUntil: 'load' })
      await page.evaluate(() => document.fonts.ready)
      const overflow = await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth)
      await page.screenshot({ path: join(out, `${comp}-${th}.png`), fullPage: true })
      if (overflow) console.log(`OVERFLOW ${comp} ${th}`)
    }
  }
  await browser.close()
  console.log(`rendered into ${out}`)
  return 0
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2)
  if (args[0] === '--version') console.log(`render_previews.mjs ${SCRIPT_VERSION}`)
  else process.exitCode = args[0] === '--selftest' ? selftest() : await render(args)
}
