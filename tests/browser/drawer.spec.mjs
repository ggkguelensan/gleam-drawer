import { test, expect } from '@playwright/test';

test('Gleam demo opens, snaps, morphs without losing state, closes and restores focus', async ({ page }) => {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto('/');
  await expect(page.locator('#popup')).not.toBeVisible();
  await page.locator('#open').click();
  const popup = page.getByRole('dialog');
  await expect(popup).toBeVisible();
  await expect(popup).toHaveAttribute('aria-modal', 'true');
  await expect(page.locator('#app')).toHaveAttribute('inert', '');
  await expect(page.locator('#status')).toContainText('Settled');
  const compact = await popup.boundingBox();
  await page.locator('#expand').click();
  await expect.poll(async () => (await popup.boundingBox()).height).toBeGreaterThan(compact.height + 100);
  await page.locator('#notes').fill('Keep this through morphs');
  await page.locator('#morph').click();
  await expect(popup).toHaveAttribute('data-presentation', 'dialog');
  await expect(popup).not.toHaveAttribute('data-transitioning');
  await expect(page.locator('#notes')).toHaveValue('Keep this through morphs');
  await page.locator('#fit').click();
  await page.locator('#morph').click();
  await expect(popup).toHaveAttribute('data-presentation', 'sheet');
  await expect(popup).not.toHaveAttribute('data-transitioning');
  await page.keyboard.press('Escape');
  await expect(popup).not.toBeVisible();
  await expect(page.locator('#app')).not.toHaveAttribute('inert');
  await expect(page.locator('#open')).toBeFocused();
  await page.locator('#open').click();
  await expect(popup).toBeVisible();
  await page.locator('#close').click();
  await expect(popup).not.toBeVisible();
  expect(errors).toEqual([]);
});

test('backdrop dismisses and reduced motion still settles', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await page.locator('#open').click();
  await expect(page.getByRole('dialog')).toBeVisible();
  await expect(page.locator('#status')).toContainText('Settled');
  await page.locator('#backdrop').click({ position: { x: 10, y: 10 } });
  await expect(page.getByRole('dialog')).not.toBeVisible();
});

test('handle drag dismisses; body stays the scrolling region', async ({ page }) => {
  await page.goto('/');
  await page.locator('#open').click();
  await expect(page.locator('#status')).toContainText('Settled');
  expect(await page.locator('#body').evaluate(el => getComputedStyle(el).overflowY)).toBe('auto');
  const h = await page.locator('#handle').boundingBox();
  await page.mouse.move(h.x + h.width / 2, h.y + h.height / 2);
  await page.mouse.down();
  await page.mouse.move(h.x + h.width / 2, h.y + h.height / 2 + 10);
  await page.mouse.move(h.x + h.width / 2, h.y + h.height / 2 + 180, { steps: 12 });
  await page.mouse.up();
  await expect(page.getByRole('dialog')).not.toBeVisible();
});

test('fast drag tracks the pointer once and remains under gesture control', async ({ page }) => {
  await page.goto('/');
  await page.locator('#open').click();
  await expect(page.locator('#status')).toContainText('Settled');
  const popup = page.locator('#popup');
  const initial = await popup.boundingBox();
  const handle = await page.locator('#handle').boundingBox();
  const x = handle.x + handle.width / 2, y = handle.y + handle.height / 2;
  await page.mouse.move(x, y);
  await page.mouse.down();
  // One event leaves the small handle before crossing the activation threshold.
  await page.mouse.move(x, y - 100);
  await expect(popup).toHaveAttribute('data-swiping');
  await expect.poll(async () => (await popup.boundingBox()).y).toBeCloseTo(initial.y - 100, 0);
  // ResizeObserver and any previous WAAPI clock must not pull the sheet back.
  await page.waitForTimeout(320);
  expect((await popup.boundingBox()).y).toBeCloseTo(initial.y - 100, 0);
  expect(await popup.evaluate(el => el.getAnimations().length)).toBe(0);
  await page.mouse.move(x, y - 150);
  await expect.poll(async () => (await popup.boundingBox()).y).toBeCloseTo(initial.y - 150, 0);
  await page.mouse.up();
  await expect(popup).not.toHaveAttribute('data-swiping');
});

test('downward drag translates without collapsing content and release stays continuous', async ({ page }) => {
  await page.goto('/');
  await page.locator('#open').click();
  await expect(page.locator('#status')).toContainText('Settled');
  const popup = page.locator('#popup');
  const initial = await popup.boundingBox();
  const handle = await page.locator('#handle').boundingBox();
  const x = handle.x + handle.width / 2, y = handle.y + handle.height / 2;
  await page.mouse.move(x, y);
  await page.mouse.down();
  await page.mouse.move(x, y + 45, { steps: 15 });
  await expect.poll(async () => (await popup.boundingBox()).y).toBeCloseTo(initial.y + 45, 0);
  expect((await popup.boundingBox()).height).toBeCloseTo(initial.height, 0);
  await page.waitForTimeout(150); // Release without a fling, returning to the same snap.
  await page.evaluate(() => {
    window.dragFrames = [];
    const sample = () => {
      window.dragFrames.push(document.querySelector('#popup').getBoundingClientRect().y);
      if (window.dragFrames.length < 24) requestAnimationFrame(sample);
    };
    requestAnimationFrame(sample);
  });
  await page.mouse.up();
  await expect.poll(async () => (await popup.boundingBox()).y).toBeCloseTo(initial.y, 0);
  const frames = await page.evaluate(() => window.dragFrames);
  expect(Math.max(...frames.slice(1).map((y, i) => Math.abs(y - frames[i])))).toBeLessThan(20);
});

test('grabbing an in-flight snap cancels its clock and holds the new position', async ({ page }) => {
  await page.goto('/');
  await page.locator('#open').click();
  await expect(page.locator('#status')).toContainText('Settled');
  // Dispatch a real DOM click without Playwright waiting for the moving handle.
  await page.locator('#expand').evaluate(el => el.click());
  const popup = page.locator('#popup');
  await expect.poll(() => popup.evaluate(el => el.getAnimations().length)).toBeGreaterThan(0);
  // Hold a real WAAPI clock halfway so the moving 30px hit target cannot
  // escape between separate automation commands. The gesture must cancel it.
  await popup.evaluate(el => {
    for (const animation of el.getAnimations()) {
      animation.pause();
      animation.currentTime = Number(animation.effect.getTiming().duration) / 2;
    }
  });
  const handle = await page.locator('#handle').boundingBox();
  const x = handle.x + handle.width / 2, y = handle.y + handle.height / 2;
  await page.mouse.move(x, y);
  await page.mouse.down();
  await page.mouse.move(x, y - 40);
  await expect(popup).toHaveAttribute('data-swiping');
  await page.waitForTimeout(40);
  const held = await popup.boundingBox();
  await page.waitForTimeout(320);
  expect((await popup.boundingBox()).y).toBeCloseTo(held.y, 0);
  expect(await popup.evaluate(el => el.getAnimations().length)).toBe(0);
  await page.mouse.up();
  await expect(popup).not.toHaveAttribute('data-swiping');
});

test('touch capture tracks a fast swipe outside the handle', async ({ page, browserName }) => {
  test.skip(browserName !== 'chromium', 'CDP touch injection is Chromium-only');
  await page.goto('/');
  await page.locator('#open').click();
  await expect(page.locator('#status')).toContainText('Settled');
  const popup = page.locator('#popup');
  const initial = await popup.boundingBox();
  const h = await page.locator('#handle').boundingBox();
  const client = await page.context().newCDPSession(page);
  const point = { x: h.x + h.width / 2, y: h.y + h.height / 2, id: 1 };
  await client.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [point] });
  await client.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ ...point, y: point.y - 100 }] });
  await expect(popup).toHaveAttribute('data-swiping');
  await expect.poll(async () => (await popup.boundingBox()).y).toBeCloseTo(initial.y - 100, 0);
  await client.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  await expect(popup).not.toHaveAttribute('data-swiping');
  await client.detach();
});
