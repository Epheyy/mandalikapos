-- 001_initial_schema.up.sql
-- Mandalika POS — Initial Database Schema
-- Fix: promotion_products PRIMARY KEY cannot use COALESCE()

-- Enable UUID generation (built into PostgreSQL 13+)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ─────────────────────────────────────────────
-- USERS
-- ─────────────────────────────────────────────
CREATE TABLE users (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid  VARCHAR(128) UNIQUE NOT NULL,
    display_name  VARCHAR(255) NOT NULL,
    email         VARCHAR(255) UNIQUE NOT NULL,
    role          VARCHAR(20) NOT NULL DEFAULT 'cashier'
                  CHECK (role IN ('admin', 'manager', 'cashier')),
    photo_url     TEXT,
    outlet_id     UUID,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- USER PERMISSIONS
-- ─────────────────────────────────────────────
CREATE TABLE user_permissions (
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    permission VARCHAR(50) NOT NULL,
    PRIMARY KEY (user_id, permission)
);

-- ─────────────────────────────────────────────
-- OUTLETS
-- ─────────────────────────────────────────────
CREATE TABLE outlets (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name       VARCHAR(255) NOT NULL,
    address    TEXT,
    phone      VARCHAR(50),
    is_active  BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- CATEGORIES
-- ─────────────────────────────────────────────
CREATE TABLE categories (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        VARCHAR(100) NOT NULL,
    description TEXT,
    sort_order  INT NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- PRODUCTS
-- ─────────────────────────────────────────────
CREATE TABLE products (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name         VARCHAR(255) NOT NULL,
    brand        VARCHAR(100) NOT NULL DEFAULT 'Mandalika',
    category_id  UUID NOT NULL REFERENCES categories(id),
    description  TEXT,
    image_url    TEXT,
    is_active    BOOLEAN NOT NULL DEFAULT TRUE,
    is_featured  BOOLEAN NOT NULL DEFAULT FALSE,
    is_favourite BOOLEAN NOT NULL DEFAULT FALSE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- PRODUCT VARIANTS
-- ─────────────────────────────────────────────
CREATE TABLE product_variants (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    size       VARCHAR(50) NOT NULL,
    price      BIGINT NOT NULL CHECK (price >= 0),
    stock      INT NOT NULL DEFAULT 0 CHECK (stock >= 0),
    sku        VARCHAR(100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (product_id, size)
);

-- ─────────────────────────────────────────────
-- CUSTOMERS
-- ─────────────────────────────────────────────
CREATE TABLE customers (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        VARCHAR(255) NOT NULL,
    phone       VARCHAR(50) NOT NULL,
    email       VARCHAR(255),
    points      INT NOT NULL DEFAULT 0,
    total_spent BIGINT NOT NULL DEFAULT 0,
    visit_count INT NOT NULL DEFAULT 0,
    last_visit  TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- PROMOTIONS
-- ─────────────────────────────────────────────
CREATE TABLE promotions (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name             VARCHAR(255) NOT NULL,
    description      TEXT,
    type             VARCHAR(20) NOT NULL CHECK (type IN ('percentage','fixed','bogo')),
    value            BIGINT NOT NULL DEFAULT 0,
    min_purchase     BIGINT NOT NULL DEFAULT 0,
    combinable       BOOLEAN NOT NULL DEFAULT FALSE,
    active_from_hour VARCHAR(5),
    active_to_hour   VARCHAR(5),
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,
    start_date       DATE,
    end_date         DATE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- PROMOTION PRODUCTS
-- Fix: variant_size uses NOT NULL DEFAULT '' instead of COALESCE in PK
-- ─────────────────────────────────────────────
CREATE TABLE promotion_products (
    promotion_id UUID        NOT NULL REFERENCES promotions(id) ON DELETE CASCADE,
    product_id   UUID        NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    variant_size VARCHAR(50) NOT NULL DEFAULT '',
    PRIMARY KEY (promotion_id, product_id, variant_size)
);

-- ─────────────────────────────────────────────
-- PROMOTION ACTIVE DAYS
-- ─────────────────────────────────────────────
CREATE TABLE promotion_active_days (
    promotion_id UUID NOT NULL REFERENCES promotions(id) ON DELETE CASCADE,
    day_of_week  INT  NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
    PRIMARY KEY (promotion_id, day_of_week)
);

-- ─────────────────────────────────────────────
-- DISCOUNT CODES
-- ─────────────────────────────────────────────
CREATE TABLE discount_codes (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code         VARCHAR(50) UNIQUE NOT NULL,
    type         VARCHAR(20) NOT NULL CHECK (type IN ('percentage','fixed')),
    value        BIGINT NOT NULL DEFAULT 0,
    min_purchase BIGINT NOT NULL DEFAULT 0,
    usage_limit  INT,
    usage_count  INT NOT NULL DEFAULT 0,
    is_active    BOOLEAN NOT NULL DEFAULT TRUE,
    start_date   DATE,
    end_date     DATE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- SHIFTS
-- ─────────────────────────────────────────────
CREATE TABLE shifts (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    outlet_id      UUID NOT NULL REFERENCES outlets(id),
    cashier_id     UUID NOT NULL REFERENCES users(id),
    status         VARCHAR(10) NOT NULL DEFAULT 'open'
                   CHECK (status IN ('open','closed')),
    opened_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    closed_at      TIMESTAMPTZ,
    starting_cash  BIGINT NOT NULL DEFAULT 0,
    closing_cash   BIGINT,
    total_sales    BIGINT NOT NULL DEFAULT 0,
    total_orders   INT    NOT NULL DEFAULT 0,
    total_refunds  BIGINT NOT NULL DEFAULT 0,
    cash_sales     BIGINT NOT NULL DEFAULT 0,
    card_sales     BIGINT NOT NULL DEFAULT 0,
    transfer_sales BIGINT NOT NULL DEFAULT 0,
    qris_sales     BIGINT NOT NULL DEFAULT 0,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- ORDERS
-- ─────────────────────────────────────────────
CREATE TABLE orders (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_number     VARCHAR(20) UNIQUE NOT NULL,
    outlet_id        UUID NOT NULL REFERENCES outlets(id),
    cashier_id       UUID NOT NULL REFERENCES users(id),
    salesman_id      UUID REFERENCES users(id),
    customer_id      UUID REFERENCES customers(id),
    shift_id         UUID REFERENCES shifts(id),
    subtotal         BIGINT NOT NULL,
    discount_amount  BIGINT NOT NULL DEFAULT 0,
    discount_type    VARCHAR(20),
    discount_value   BIGINT,
    discount_code    VARCHAR(50),
    tax_amount       BIGINT NOT NULL DEFAULT 0,
    surcharge_amount BIGINT NOT NULL DEFAULT 0,
    total            BIGINT NOT NULL,
    payment_method   VARCHAR(20) NOT NULL
                     CHECK (payment_method IN ('cash','card','transfer','qris')),
    amount_paid      BIGINT NOT NULL,
    change_amount    BIGINT NOT NULL DEFAULT 0,
    status           VARCHAR(20) NOT NULL DEFAULT 'completed'
                     CHECK (status IN ('completed','refunded','cancelled')),
    notes            TEXT,
    refund_reason    TEXT,
    refunded_at      TIMESTAMPTZ,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- ORDER ITEMS
-- ─────────────────────────────────────────────
CREATE TABLE order_items (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id     UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id   UUID NOT NULL REFERENCES products(id),
    variant_id   UUID NOT NULL REFERENCES product_variants(id),
    product_name VARCHAR(255) NOT NULL,
    variant_size VARCHAR(50)  NOT NULL,
    price        BIGINT NOT NULL,
    quantity     INT    NOT NULL CHECK (quantity > 0),
    subtotal     BIGINT NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- APP SETTINGS (key-value store)
-- ─────────────────────────────────────────────
CREATE TABLE app_settings (
    key        VARCHAR(100) PRIMARY KEY,
    value      JSONB NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- CASH FLOWS
-- ─────────────────────────────────────────────
CREATE TABLE cash_flows (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    outlet_id   UUID NOT NULL REFERENCES outlets(id),
    cashier_id  UUID NOT NULL REFERENCES users(id),
    shift_id    UUID REFERENCES shifts(id),
    type        VARCHAR(3) NOT NULL CHECK (type IN ('in','out')),
    amount      BIGINT NOT NULL,
    description TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- AUDIT LOGS
-- ─────────────────────────────────────────────
CREATE TABLE audit_logs (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID REFERENCES users(id),
    action     VARCHAR(100) NOT NULL,
    table_name VARCHAR(100),
    record_id  UUID,
    old_data   JSONB,
    new_data   JSONB,
    ip_address INET,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- PERFORMANCE INDEXES
-- ─────────────────────────────────────────────
CREATE INDEX idx_orders_cashier    ON orders(cashier_id);
CREATE INDEX idx_orders_customer   ON orders(customer_id);
CREATE INDEX idx_orders_created    ON orders(created_at DESC);
CREATE INDEX idx_orders_status     ON orders(status);
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_variants_product  ON product_variants(product_id);
CREATE INDEX idx_shifts_cashier    ON shifts(cashier_id);
CREATE INDEX idx_shifts_status     ON shifts(status);
CREATE INDEX idx_audit_logs_user   ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_created ON audit_logs(created_at DESC);