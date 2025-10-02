# Multi-Restaurant Support Architecture

## 1. Database Structure: Single Database, Multi-Tenant

### **Approach:**
- All restaurants share one database
- Every record linked to specific restaurant via `restaurant_id`
- Strict data isolation to prevent cross-restaurant data leaks

### **Key Tables:**
- `restaurants` (branding, contact info, subscription status, location)
- `users` (linked to restaurant, roles: owner, manager, staff, customer)
- `menus` (linked to restaurant)
- `orders` (linked to restaurant and customer)
- `settings` (per-restaurant config: colors, hours, etc.)

### **Data Security Measures:**

#### **API-Level Security:**
- Every API endpoint validates `restaurant_id` from user session/token
- Database queries always include `WHERE restaurant_id = ?`
- JWT tokens include user's `restaurant_id`

#### **Database-Level Security:**
- Row-level security (RLS) in PostgreSQL
- Database views that filter by `restaurant_id`
- Stored procedures that validate restaurant access

#### **Application-Level Security:**
- Middleware validates restaurant access on every request
- Input validation to prevent SQL injection
- Rate limiting per restaurant

## 2. Restaurant Discovery: Location-Based Selection

### **How it Works:**
1. User opens the app
2. App requests location permission
3. Shows nearby restaurants, sorted by distance
4. User selects their restaurant
5. App loads that restaurant's branding and menu

### **Benefits:**
- ✅ Solves app icon problem (one app, multiple restaurants)
- ✅ No codes needed - just location
- ✅ Premium positioning for restaurants (paid placement)
- ✅ Natural discovery (users find restaurants near them)
- ✅ Restaurant can pay to appear higher in the list

### **Revenue Opportunities:**
- **Premium placement:** Restaurants pay to appear at the top
- **Featured restaurants:** Highlight certain restaurants
- **Sponsored listings:** Restaurants pay for visibility
- **Subscription tiers:** Different levels of visibility/features
- **Review management:** Restaurants can pay to remove/hide bad reviews

### **Technical Implementation:**
- Google Maps API for location services
- Geospatial queries for nearby restaurants
- Caching for performance
- Offline support for poor GPS areas

## 3. Concerns & Solutions

### **Location Permissions:**
- Clear message: "To help you find the nearest restaurants, we need your location. This helps us show you the best dining options close to you."
- Fallback to manual restaurant selection
- Privacy policy compliance

### **Restaurant Density:**
- Show multiple nearby restaurants
- Allow user to scroll through options
- **Highest paying restaurant gets top placement**
- Premium placement for preferred restaurants

### **Offline Areas:**
- Cache nearby restaurants
- Manual restaurant search
- QR code fallback for specific restaurants
- **Poor GPS:** Use estimated distance with "(estimate)" label

### **Restaurant Verification:**
- Business verification process (documents, phone verification, address verification)
- Customer reviews and ratings
- Report system for fake/inactive restaurants
- **Review Management:** Restaurants can pay to remove/hide bad reviews (premium feature)

## 4. Subscription & Billing

### **Tiers:**
- **Free:** Basic listing, standard placement
- **Premium:** Higher placement, featured listing
- **Enterprise:** Custom branding, priority support

### **Billing Management:**
- Stripe/PayFast integration
- Admin panel for subscription management
- Usage tracking and analytics

## 5. Scaling Strategy

### **Phase 1:** Single database, location-based discovery
### **Phase 2:** Add premium placement and sponsored listings
### **Phase 3:** Offer custom app builds for enterprise clients

---
*Status: Step 6 Complete - Ready for Step 7 (Build & Deployment Automation)* 