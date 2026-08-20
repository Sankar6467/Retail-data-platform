
USE DATABASE RETAIL_DB;

-- ---------------------------------------------------------------------
-- RAW.CUSTOMERS
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS RAW.CUSTOMERS (
    customer_id      VARCHAR(20),
    first_name       VARCHAR(100),
    last_name        VARCHAR(100),
    email            VARCHAR(255),
    phone            VARCHAR(50),
    address_line1    VARCHAR(255),
    city             VARCHAR(100),
    state            VARCHAR(50),
    postal_code      VARCHAR(20),
    country          VARCHAR(50),
    loyalty_tier     VARCHAR(20),
    signup_date      DATE,
    updated_at       TIMESTAMP_NTZ,
    _ingested_at     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_file     VARCHAR(255),
    _batch_id        VARCHAR(100)
);

-- ---------------------------------------------------------------------
-- RAW.PRODUCTS
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS RAW.PRODUCTS (
    product_id     VARCHAR(20),
    sku             VARCHAR(50),
    product_name    VARCHAR(255),
    category        VARCHAR(100),
    subcategory     VARCHAR(100),
    brand           VARCHAR(100),
    unit_cost       NUMBER(12,2),
    unit_price      NUMBER(12,2),
    is_active       VARCHAR(10),
    created_at      TIMESTAMP_NTZ,
    updated_at      TIMESTAMP_NTZ,
    _ingested_at    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_file    VARCHAR(255),
    _batch_id       VARCHAR(100)
);

-- ---------------------------------------------------------------------
-- RAW.STORES
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS RAW.STORES (
    store_id        VARCHAR(20),
    store_name      VARCHAR(255),
    store_type      VARCHAR(20),
    region          VARCHAR(50),
    city            VARCHAR(100),
    state           VARCHAR(50),
    country         VARCHAR(50),
    open_date       DATE,
    updated_at      TIMESTAMP_NTZ,
    _ingested_at    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_file    VARCHAR(255),
    _batch_id       VARCHAR(100)
);

-- ---------------------------------------------------------------------
-- RAW.ORDERS
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS RAW.ORDERS (
    order_id        VARCHAR(20),
    customer_id     VARCHAR(20),
    store_id        VARCHAR(20),
    order_date      TIMESTAMP_NTZ,
    order_status    VARCHAR(20),
    payment_method  VARCHAR(30),
    currency        VARCHAR(10),
    updated_at      TIMESTAMP_NTZ,
    _ingested_at    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_file    VARCHAR(255),
    _batch_id       VARCHAR(100)
);

-- ---------------------------------------------------------------------
-- RAW.ORDER_ITEMS
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS RAW.ORDER_ITEMS (
    order_item_id    VARCHAR(20),
    order_id         VARCHAR(20),
    product_id       VARCHAR(20),
    quantity         NUMBER(10,0),
    unit_price       NUMBER(12,2),
    discount_amount  NUMBER(12,2),
    line_total       NUMBER(12,2),
    updated_at       TIMESTAMP_NTZ,
    _ingested_at     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_file     VARCHAR(255),
    _batch_id        VARCHAR(100)
);

-- ---------------------------------------------------------------------
-- RAW.INVENTORY_SNAPSHOTS
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS RAW.INVENTORY_SNAPSHOTS (
    snapshot_date        DATE,
    store_id             VARCHAR(20),
    product_id           VARCHAR(20),
    quantity_on_hand     NUMBER(10,0),
    quantity_reserved    NUMBER(10,0),
    reorder_point        NUMBER(10,0),
    updated_at           TIMESTAMP_NTZ,
    _ingested_at         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_file         VARCHAR(255),
    _batch_id            VARCHAR(100)
);