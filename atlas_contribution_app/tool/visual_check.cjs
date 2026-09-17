const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const fs = require('node:fs/promises');
(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  try {
    await fs.mkdir('build/ui-checks', { recursive: true });
    for (const width of [360, 412]) {
      const page = await browser.newPage({ viewport: { width, height: width === 360 ? 800 : 915 } });
      const errors=[];page.on('pageerror', e=>errors.push(e.message));
      await page.goto('http://127.0.0.1:8790/', { waitUntil: 'networkidle' });
      await page.waitForTimeout(1500);
      await page.screenshot({ path: `build/ui-checks/annotation-${width}.png`, fullPage: true });
      await page.mouse.click(width/2,350);
      await page.waitForTimeout(300);
      await page.mouse.click(width/2,width===360?630:670);
      await page.waitForTimeout(500);
      await page.screenshot({path:`build/ui-checks/picker-${width}.png`,fullPage:true});
      console.log(JSON.stringify({width,errors,screenshot:`build/ui-checks/annotation-${width}.png`}));
      await page.close();
      if(errors.length) throw Error('Browser runtime error');
    }
  } finally { await browser.close(); }
})().catch(e => { console.error(e);process.exitCode=1; });
