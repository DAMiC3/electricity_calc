# Branding Approach: White-Label Food Ordering App

## 1. Business Model
- **Primary:** You (the developer) customize and sell the app to restaurants, especially at first.
- **Scalability:** Over time, allow restaurants to self-serve (customize their own branding and menu via admin panel).
- **Monetization:** Subscription-based model, with optional extra fee if you do the setup/customization for them.

## 2. Branding Elements (Customizable)
- Logo (displayed in app)
- Primary color
- Secondary color
- Restaurant name
- Contact information
- Social media links
- Menu items and categories
- Restaurant description
- App icon (see limitation below)
- (Splash screen: to be decided later)

## 3. Branding Storage & Loading
- **Hybrid approach:**
  - Branding is loaded from the server when the app starts (ensures up-to-date info).
  - Branding is cached locally for offline use and fast startup.
  - Most branding changes (logo, colors, contact info, menu) can be updated instantly via the admin panel, without needing a new app build or app store update.

## 4. App Icon & Logo Limitation
- **Logo inside the app:**
  - Can be updated dynamically at any time via the admin panel.
  - Appears on menus, headers, etc.
- **App icon (the icon on the user's phone):**
  - Cannot be changed dynamically after the app is installed.
  - To change the app icon, a new app build must be created and published to the app store (requires app store approval and user update).
  - This is a limitation of both Android and iOS platforms.

## 5. Flexibility & Control
- Core branding (e.g., "Spur" app stays "Spur") is locked, but restaurants can update contact info, colors, and logo (inside the app) as needed.
- You can offer setup as a service for an extra fee, or let restaurants do it themselves via the admin panel.

---
*Status: Step 4 Complete - Ready for Step 5 (Admin Panel Design)* 