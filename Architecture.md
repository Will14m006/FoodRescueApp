# Architecture: Food Rescue App

## 1. Purpose
Membantu restoran atau kafe (Mitra) menjual makanan surplus layak konsumsi di akhir jam operasional kepada pengguna (Pembeli) dengan harga diskon. Aplikasi ini mengelola ketersediaan stok secara *real-time* dan menggunakan sistem validasi kode *pick-up* untuk pengambilan di tempat.

## 2. Tech Stack
* **Frontend:** React + TypeScript + Vite + Tailwind CSS
* **Backend:** Node.js + TypeScript + Express
* **Database:** MySQL
* **ORM:** Prisma
* **API style:** REST API
* **Infrastruktur:** Docker Compose for MySQL
* **Environment:** Use `.env.example` for database URL and optional ports.

## 3. Code Rules
* Do not add comments unless truly necessary.
* Use PascalCase for all classes, types, interfaces, enums, React components, database models, API DTOs, and JSON property names.
* Local variables may use camelCase.
* Keep code lines below 150 characters where practical.
* Use a clean and simple folder structure.
* Do not add authentication in this first version. Assume role selection is done manually on the frontend.

## 4. Main Entities

### 1. Merchant
* Id
* Name
* StoreName
* Address
* CreatedAt

### 2. Buyer
* Id
* Name
* Email
* CreatedAt

### 3. SurplusFood
* Id
* MerchantId
* Name
* OriginalPrice
* DiscountPrice
* Quota
* IsActive
* CreatedAt

### 4. Order
* Id
* BuyerId
* SurplusFoodId
* PickupCode
* Status
* CreatedAt

## 5. Database Rules
* `PickupCode` must be unique across all active orders.
* Never hard-delete existing order data.
* Never replace existing transaction records.
* When an `Order` is created, automatically decrement the `Quota` in `SurplusFood`.
* Use Prisma migrations and seed one example Merchant, three Buyers, and five SurplusFoods.

## 6. Backend Features

1. **CRUD Merchant & Buyer**
   * Create, list, detail, update profiles.
2. **CRUD Surplus Food**
   * Add, edit, delete (soft delete using `IsActive`) surplus food for a merchant.
3. **Order Management & Validation**
   * Endpoint to create an order and generate a unique `PickupCode`.
   * Endpoint for merchant to validate `PickupCode` and change status to `COMPLETED`.
4. **Dashboard API**
   * Return merchant summary: Total Active Foods, Total Orders, Quota Remaining.
   * Return buyer progress: Total Orders, Active Orders.
   * Order Status rules:
     * `PENDING`: Order created, waiting for pickup.
     * `COMPLETED`: Food picked up and code validated.
     * `CANCELLED`: Order cancelled by buyer or merchant.

## 7. Frontend Pages

1. **Merchant Dashboard**
   * Summary cards: total active foods, total pending orders.
   * Table showing each food item, remaining quota, and status.
   * Input form to validate `PickupCode`.
2. **Buyer Catalog (Feed)**
   * List available `SurplusFood` where `IsActive` is true and `Quota > 0`.
   * Form to create an order.
3. **Order History**
   * Table showing commit message/order details, pickup code, date, and status badge.

## 8. UI Requirements
* Use Indonesian language for all labels, buttons, messages, and validation.
* Create a clean, responsive dashboard.
* Use simple tables, cards, badges, forms, confirmation dialog before delete, and empty states.
* Use status badge colors:
  * COMPLETED: green
  * PENDING: orange
  * CANCELLED: red
* Do not add charts in the first version.

## 9. Required API Routes
* `GET /api/merchants`
* `POST /api/merchants`
* `GET /api/buyers`
* `POST /api/buyers`
* `GET /api/merchants/:Id/foods`
* `POST /api/merchants/:Id/foods`
* `PUT /api/foods/:Id`
* `DELETE /api/foods/:Id`
* `GET /api/buyers/:Id/orders`
* `POST /api/orders`
* `POST /api/orders/validate`
* `GET /api/merchants/:Id/dashboard`

## 10. Deliverables
* Complete frontend and backend source code.
* Prisma schema, migration, and seed data.
* Docker Compose file for MySQL.
* `.env.example`.
* README with installation, database migration, seed, frontend/backend startup, Docker usage.

## 11. Project Structure
Use a TypeScript monorepo with npm workspaces.

- `food-rescue-app/`
  - `apps/`
    - `web/`
    - `api/`
  - `packages/`
    - `shared/`

## 12. Shared Package Requirements
* Create `packages/shared` as `@food-rescue-app/shared`.
* Store all shared domain models, enums, API response types, and shared constants here.
* Both `apps/web` and `apps/api` must import shared types from this package.
* Do not duplicate domain model definitions between frontend and backend.

## 13. Model Rules
* Define shared TypeScript interfaces or types only once in `packages/shared`.
* Example: `Merchant`, `Buyer`, `SurplusFood`, and `OrderStatus` must be imported by both frontend and backend from `@food-rescue-app/shared`.
* Prisma models remain in the backend because they are database-specific.
* The backend maps Prisma entities to shared API models before returning responses.
* The frontend must not import Prisma types.