-- 002_add_stock_counts.up.sql
-- Adds stock count session management tables

CREATE TABLE stock_counts (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name         VARCHAR(255) NOT NULL,
    status       VARCHAR(20)  NOT NULL DEFAULT 'planned'
                 CHECK (status IN ('planned','in_progress','completed','cancelled')),
    outlet_id    UUID NOT NULL REFERENCES outlets(id),
    created_by   UUID NOT NULL REFERENCES users(id),
    planned_date DATE NOT NULL,
    started_at   TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    notes        TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE stock_count_items (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stock_count_id   UUID NOT NULL REFERENCES stock_counts(id) ON DELETE CASCADE,
    product_id       UUID NOT NULL REFERENCES products(id),
    variant_id       UUID NOT NULL REFERENCES product_variants(id),
    product_name     VARCHAR(255) NOT NULL,
    variant_size     VARCHAR(50)  NOT NULL,
    sku              VARCHAR(100),
    frozen_qty       INT NOT NULL DEFAULT 0,
    actual_qty       INT,
    difference       INT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_stock_counts_outlet  ON stock_counts(outlet_id);
CREATE INDEX idx_stock_counts_status  ON stock_counts(status);
CREATE INDEX idx_stock_count_items_sc ON stock_count_items(stock_count_id);
