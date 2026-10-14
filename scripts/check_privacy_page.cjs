const {chromium} = require('playwright');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
const fs = require('node:fs/promises');

async function main() {
  const root = path.resolve(__dirname, '..');
  await fs.mkdir(path.join(root, 'build', 'privacy-review'), {recursive: true});
  const browser = await chromium.launch({
    executablePath: process.env.CHROME_PATH || 'C:/Program Files/Google/Chrome/Application/chrome.exe',
    headless: true,
  });
  try {
    for (const [name, width, height] of [['phone', 360, 800], ['desktop', 1280, 900]]) {
      const page = await browser.newPage({viewport: {width, height}});
      const errors = [];
      page.on('pageerror', error => errors.push(error.message));
      await page.goto(pathToFileURL(path.join(root, 'docs', 'index.html')).href);
      const state = await page.evaluate(() => ({
        overflow: document.documentElement.scrollWidth > innerWidth,
        text: document.body.innerText,
        email: document.querySelector('a[href="mailto:seandyadryan2@gmail.com"]') !== null,
        language: document.documentElement.lang,
      }));
      if (state.overflow || !state.email || state.language !== 'en' || !state.text.includes('PT Deploy Dulu Pulang Nanti') || errors.length) {
        throw new Error(`Privacy page validation failed on ${name}`);
      }
      await page.screenshot({path: path.join(root, 'build', 'privacy-review', `${name}.png`), fullPage: true});
      console.log(`Privacy page: ${name} passed, no horizontal overflow.`);
      await page.close();
    }
  } finally {
    await browser.close();
  }
}

main().catch(error => {console.error(error); process.exitCode = 1;});
