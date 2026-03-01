import { test, expect } from '@playwright/test';

test.describe('Responsive Sidebar', () => {
  test('should toggle sidebar visibility at 1280px (xl breakpoint)', async ({ page }) => {
    // Navigate to a sample page
    await page.goto('/Lean/Structure.html');

    // --- Desktop View (Wide: 1440px) ---
    await page.setViewportSize({ width: 1440, height: 900 });
    const sidebar = page.locator('nav.nav');
    
    // On wide desktop, sidebar should be visible and not translated
    await expect(sidebar).toBeVisible();
    
    // The hamburger menu (label for nav_toggle in header) should be hidden on xl+
    const hamburger = page.locator('header label[for="nav_toggle"]');
    await expect(hamburger).not.toBeVisible();

    // --- Tablet/Smaller Desktop View (Narrow: 1024px - below xl) ---
    await page.setViewportSize({ width: 1024, height: 900 });
    
    // On narrower screens, the sidebar should be hidden
    await expect(sidebar).not.toBeInViewport();
    
    // Hamburger menu in header should now be visible
    await expect(hamburger).toBeVisible();

    // --- Interaction Test: Open Sidebar on Mobile ---
    await hamburger.click();
    
    // Wait for the CSS transition to complete
    await page.waitForTimeout(300);

    // Sidebar should now be visible
    await expect(sidebar).toBeInViewport();
    await expect(sidebar).toBeVisible();

    // Close it by clicking the X inside the nav
    const closeBtn = page.locator('nav.nav label[for="nav_toggle"]');
    await closeBtn.click();
    await page.waitForTimeout(300);
    await expect(sidebar).not.toBeInViewport();
  });
});
