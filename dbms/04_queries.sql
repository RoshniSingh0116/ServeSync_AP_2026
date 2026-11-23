-- AP PROJECT - SQL QUERIES
-- Database: PostgreSQL
-- ALL READ QUERIES FIRST, FOLLOWED BY ALL WRITE QUERIES
-- READ QUERIES: R1 - R8
-- WRITE QUERIES: W1 - W6


-- READ QUERIES

-- R1
-- Admin login using username or email.
-- $1 = username or email.
SELECT
    id,
    username,
    email,
    password,
    role,
    created_at
FROM admins
WHERE LOWER(username) = LOWER($1)
   OR LOWER(email) = LOWER($1)
LIMIT 1;


-- R2
-- Check whether an admin account already exists.
SELECT COUNT(*) AS admin_count
FROM admins;


-- R3
-- Get all foods, optionally filtered by category.
-- $1 = category. Pass NULL to return all categories.
SELECT
    id,
    name,
    description,
    price,
    category,
    image,
    is_veg,
    is_popular,
    is_available,
    created_at,
    updated_at
FROM foods
WHERE ($1::varchar IS NULL OR category = $1)
ORDER BY category ASC, name ASC;


-- R4
-- Get details of a particular food item.
-- $1 = food ID.
SELECT
    id,
    name,
    description,
    price,
    category,
    image,
    is_veg,
    is_popular,
    is_available,
    created_at,
    updated_at
FROM foods
WHERE id = $1;


-- R5
-- Check whether a particular food item is available.
-- $1 = food ID.
SELECT
    id,
    name,
    price,
    is_available
FROM foods
WHERE id = $1
  AND is_available = TRUE;


-- R6
-- Get complete details of a particular order,
-- including its order items.
-- $1 = order ID.
SELECT
    o.id AS order_id,
    o.table_number,
    o.total_amount,
    o.status,
    o.special_instructions,
    o.created_at,
    o.updated_at,
    oi.id AS order_item_id,
    oi.food_id,
    oi.food_name,
    oi.unit_price,
    oi.quantity,
    (oi.unit_price * oi.quantity) AS item_total,
    f.category AS current_food_category
FROM orders AS o
LEFT JOIN order_items AS oi
    ON o.id = oi.order_id
LEFT JOIN foods AS f
    ON oi.food_id = f.id
WHERE o.id = $1
ORDER BY oi.id;


-- R7
-- Get orders with their items.
-- $1 = status filter (NULL means every status).
-- $2 = table number filter (NULL means every table).
SELECT
    o.id AS order_id,
    o.table_number,
    o.total_amount,
    o.status,
    o.special_instructions,
    o.created_at,
    o.updated_at,
    oi.id AS order_item_id,
    oi.food_id,
    oi.food_name,
    oi.unit_price,
    oi.quantity,
    (oi.unit_price * oi.quantity) AS item_total,
    f.category AS current_food_category
FROM orders AS o
LEFT JOIN order_items AS oi
    ON o.id = oi.order_id
LEFT JOIN foods AS f
    ON oi.food_id = f.id
WHERE ($1::varchar IS NULL OR o.status = $1)
  AND ($2::integer IS NULL OR o.table_number = $2)
ORDER BY o.created_at DESC, o.id, oi.id;


-- R8
-- Get dashboard statistics for foods and orders.
SELECT
    (SELECT COUNT(*) FROM foods) AS total_foods,
    (SELECT COUNT(*) FROM foods WHERE is_available = TRUE) AS available_foods,
    (SELECT COUNT(*) FROM foods WHERE is_available = FALSE) AS unavailable_foods,
    (SELECT COUNT(*) FROM orders) AS total_orders,
    (SELECT COUNT(*) FROM orders WHERE status = 'pending') AS pending_orders,
    (SELECT COUNT(*) FROM orders WHERE status = 'preparing') AS preparing_orders,
    (SELECT COUNT(*) FROM orders WHERE status = 'ready') AS ready_orders,
    (SELECT COUNT(*) FROM orders WHERE status = 'completed') AS completed_orders;


-- WRITE QUERIES

-- W1
-- Optional one-time admin creation.
-- $1 = username, $2 = email, $3 = securely hashed password.

INSERT INTO admins (username, email, password, role)
VALUES ($1, $2, $3, 'admin')
ON CONFLICT (username) DO NOTHING
RETURNING id, username, email, role, created_at;


-- W2
-- Add a new food item.
-- $1=name, $2=description, $3=price, $4=category, $5=image,
-- $6=is_veg, $7=is_popular, $8=is_available.

INSERT INTO foods (
    name,
    description,
    price,
    category,
    image,
    is_veg,
    is_popular,
    is_available
)
VALUES (
    $1, $2, $3, $4,
    COALESCE($5, ''),
    COALESCE($6, FALSE),
    COALESCE($7, FALSE),
    COALESCE($8, TRUE)
)
RETURNING *;


-- W3
-- Update an existing food item.
-- $1=id, $2=name, $3=description, $4=price, $5=category, $6=image,
-- $7=is_veg, $8=is_popular, $9=is_available.

UPDATE foods
SET
    name         = COALESCE($2::varchar, name),
    description  = COALESCE($3::text, description),
    price        = COALESCE($4::numeric, price),
    category     = COALESCE($5::varchar, category),
    image        = COALESCE($6::text, image),
    is_veg       = COALESCE($7::boolean, is_veg),
    is_popular   = COALESCE($8::boolean, is_popular),
    is_available = COALESCE($9::boolean, is_available),
    updated_at   = CURRENT_TIMESTAMP
WHERE id = $1
RETURNING *;


-- W4
-- Delete a food item.
-- $1 = food ID.

DELETE FROM foods
WHERE id = $1
RETURNING id;


-- W5
-- Create an order and insert its items in one transaction.
-- $1 = table_number, $2 = total_amount, $3 = special_instructions.
-- Step 1: Start the transaction.

BEGIN;
-- Step 2: Insert the new order.
INSERT INTO orders (
    table_number,
    total_amount,
    status,
    special_instructions
)
VALUES ($1, $2, 'pending', $3)
RETURNING id;
-- Step 3: Insert the order items.
-- $1 = new order ID, $2 = food ID, $3 = quantity.
INSERT INTO order_items (
    order_id,
    food_id,
    food_name,
    unit_price,
    quantity
)
SELECT
    $1,
    id,
    name,
    price,
    $3
FROM foods
WHERE id = $2
  AND is_available = TRUE;

-- Step 4: Commit the transaction.

COMMIT;


-- W6
-- Update the status of an order.
-- $1 = order ID, $2 = new status.
-- Allowed status transitions:
-- pending   -> preparing
-- preparing -> ready
-- ready     -> completed

UPDATE orders
SET
    status = $2,
    updated_at = CURRENT_TIMESTAMP
WHERE id = $1
  AND (
        (status = 'pending'   AND $2 = 'preparing')
     OR (status = 'preparing' AND $2 = 'ready')
     OR (status = 'ready'     AND $2 = 'completed')
  )
RETURNING *;


