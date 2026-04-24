# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Mandalika POS** is a point-of-sale system for a perfume retailer. It consists of:
- `backend/` — Go REST API (Chi router, PostgreSQL, Redis)
- `flutter_app/` — Flutter mobile app (Android/iOS) for cashiers
- `bi_service/` — Python BI service skeleton (not yet implemented)
- `docker-compose.yml` — Local dev: PostgreSQL 16 + Redis 7

## Commands

### Backend (Go)

```bash
cd backend

# Start infrastructure
docker-compose up -d           # from repo root

# Run dev server
go run ./cmd/api/main.go

# Build binary
go build -o bin/api ./cmd/api

# Database migrations run automatically at startup from backend/migrations/
```

### Flutter App

```bash
cd flutter_app

flutter pub get
flutter run                     # run on connected device/emulator
flutter analyze                 # lint
dart format lib/                # format
flutter test                    # unit tests
flutter build apk --release     # Android APK
flutter build appbundle --release  # Google Play AAB
```

### Environment Setup

Backend requires `backend/.env`:
```
DATABASE_URL=postgres://mandalika_user:Mandalika2023!@localhost:5432/mandalika_pos
REDIS_URL=redis://:Redis2023!@localhost:6379/0
FIREBASE_PROJECT_ID=<your-project>
PORT=8080
```

Flutter app requires `flutter_app/.env`:
```
API_BASE_URL=http://10.0.2.2:8080/api/v1   # emulator → host
```

## Architecture

### Backend Layers

```
chi.Router (cmd/api/main.go)
  → Middleware: CORS, RequireAuth (Firebase token verify), RequireRole
  → Handlers (internal/handlers/) — HTTP decode/encode only
  → Services (internal/services/) — business logic, DB queries, cache ops
  → PostgreSQL (pgxpool, 10 max conns) + Redis cache
```

Key patterns:
- Services take DB pool + Redis client via constructor injection
- Redis cache-aside: `CacheGet` checks cache before DB; writes invalidate `products:*` / `categories:*` patterns
- Product creation uses DB transactions for atomicity
- All migration SQL lives in `backend/migrations/`; runs at startup via `golang-migrate`

**Route groups:**
- `GET /health` — unauthenticated
- `/auth/me` — authenticated, any role
- `/api/v1/products`, `/api/v1/categories`, `/api/v1/orders` — authenticated cashier routes
- `/api/v1/admin/*` — requires admin or manager role

### Flutter App Structure

```
lib/
  main.dart                    # App entry; watches authStateProvider
  core/
    network/api_client.dart    # Dio instance; interceptor adds Bearer token
    config/app_config.dart     # Loads .env values
    auth/                      # Firebase + SecureStorage token management
    bluetooth/                 # ESC/POS thermal printer via BLE
  features/
    auth/      # Google Sign-In → Firebase → backend /auth/me
    products/  # FutureProvider fetches product list from API
    cart/      # StateNotifier; holds CartItem list + totals
    cashier/   # Main POS screen (product grid + cart panel)
    orders/    # Order model + checkout flow
  shared/theme/  # App-wide colors/typography
```

State management is Riverpod throughout:
- `authStateProvider` (StreamProvider) — Firebase auth stream
- `currentUserProvider` (FutureProvider) — backend user profile
- `productsProvider` (FutureProvider) — API product list
- `cartProvider` (StateNotifierProvider) — mutable cart state
- `apiClientProvider` — Dio singleton with auth interceptor

### Auth Flow

1. Flutter: Google Sign-In → Firebase ID token
2. Token stored in `flutter_secure_storage` (never SharedPreferences)
3. Dio interceptor injects `Authorization: Bearer <token>` on every request
4. Backend: Firebase Admin SDK verifies token, extracts UID + role
5. Role stored in PostgreSQL `users` table; checked by `RequireRole` middleware

### Database Schema Highlights

Core tables: `users`, `outlets`, `products`, `product_variants`, `categories`, `orders`, `order_items`, `customers`, `promotions`, `discount_codes`, `shifts`, `cash_flows`, `audit_logs`, `app_settings`.

Products have variants (size/price/stock). Orders link to cashier user, optional customer, and payment method. Shifts track opening/closing cash per cashier.

### Bluetooth Printing

`flutter_app/lib/core/bluetooth/` handles thermal receipt printing via `print_bluetooth_thermal` + `esc_pos_utils_plus`. Receipt is formatted and sent after successful checkout.

## Tech Stack Reference

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter/Dart, Riverpod, Dio, go_router |
| Backend | Go, Chi v5, pgx v5, golang-migrate |
| Cache | Redis 7 (go-redis/v9), 5–10 min TTLs |
| Database | PostgreSQL 16 |
| Auth | Firebase Auth + Google Sign-In |
| Images | Cloudinary |
| Printer | BLE thermal (ESC/POS) |
