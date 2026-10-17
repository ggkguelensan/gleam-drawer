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
