# CP1 · Normalization of the ServeSync Database

This file shows how the database of ServeSync was designed, starting from one bigrestaurant order register and normalizing it step by step to BCNF.

The final collections are implemented in MongoDB using the `admins`, `foods`, and `orders`collections. The order items are embedded inside the `orders` collection rather than stored in a separate collection.

---

## 0. What the system has to store

- **Admins**: administrator login information, including username, password, role and email.
- **Foods**: menu items with their name, description, price, category, image and availability details.
- **Orders**: customer orders placed from restaurant tables.
- **Order items**: the food items included in each order, along with their name, price, quantity and subtotal.
- **Cart**: temporarily stores selected food items in the frontend using `CartContext.jsx`.
- **Kitchen**: displays orders and updates their status.
- **Order history**: stores order details and timestamps so that previously placed orders can be retrieved.

---

## 1. Unnormalized form (UNF): the paper register

If the restaurant maintained everything in one register, a row would look like this:

| admin_username | admin_password | food_id | food_name | category | price | order_id | table_number | items | total_amount | status |
|---|---|---|---|---|---:|---|---:|---|---:|---|
| admin | admin123 | F01 | Paneer Tikka | Starters | 200 | O101 | 5 | "Paneer Tikka × 2; Veg Burger × 1" | 520 | Pending |

**Problems**

- `items` contains multiple food items in one cell (repeating groups).
- Food details such as name, category and price are repeated across different orders.
- Administrator details would be repeated on every order row.
- Updating a food name or price would require changing multiple rows (update anomaly).
- A food item that has not been ordered yet cannot be represented properly in the order register (insertion anomaly).
- Deleting an order could also remove the only stored copy of information about a food item (deletion anomaly).

---

## 2. First Normal Form (1NF)

**Rule:** every cell holds one atomic value and there are no repeating groups.

The `items` field contains multiple food items. We separate the order information from the individual order items in a relational representation.

- `items` → one row per ordered food item: **OrderItems(order_id, order_line_id, food_id, food_name, price, quantity, subtotal)**

The register becomes:

**Orders_1NF**(`order_id`, table_number, total_amount, status, special_instructions, created_at, updated_at)

**OrderItems_1NF**(`order_line_id`, order_id, food_id, food_name, price, quantity, subtotal)

**Admins_1NF**(`admin_id`, username, password, role, email, created_at)

**Foods_1NF**(`food_id`, name, description, price, category, image, isVeg, isPopular, isAvailable, created_at, updated_at)

For example:

**Orders_1NF**

| order_id | table_number | total_amount | status |
|---|---:|---:|---|
| O101 | 5 | 520 | Pending |
| O102 | 3 | 300 | Preparing |

**OrderItems_1NF**

| order_line_id | order_id | food_id | food_name | price | quantity | subtotal |
|---|---|---|---|---:|---:|---:|
| L1 | O101 | F01 | Paneer Tikka | 200 | 2 | 400 |
| L2 | O101 | F02 | Veg Burger | 120 | 1 | 120 |
| L3 | O102 | F03 | Pizza | 300 | 1 | 300 |

All values are now atomic in the relational representation.

---

## 3. Second Normal Form (2NF)

**Rule:** 1NF, and no non-key attribute depends on only part of a composite key.

In the relational representation, `Orders_1NF` has a single-column key (`order_id`), so it is automatically in 2NF.

`Admins_1NF` and `Foods_1NF` also use single-column identifiers, so they are automatically in 2NF.

For `OrderItems_1NF`, we use `order_line_id` as the candidate key. Each order line has its own identifier, and its attributes depend on the complete key.

| FD | Problem |
|---|---|
| order_id → table_number, total_amount, status | Order-level information belongs to the order |
| order_line_id → order_id, food_id, food_name, price, quantity, subtotal | Depends on the whole key ✔ |

So we split the order information:

- **Orders**(`id`, table_number, total_amount, status, special_instructions, created_at, updated_at)
- **OrderItems**(`id`, order_id, food_id, food_name, price, quantity, subtotal)

.

---

## 4. Third Normal Form (3NF)

**Rule:** 2NF, and no non-key attribute depends on another non-key attribute (no transitive dependency).

The main data is separated into three collections:

| Collection | What it stores |
|---|---|
| `admins` | Administrator login information |
| `foods` | Menu item information |
| `orders` | Customer order information |

Functional dependencies:

| FD | Type |
|---|---|
| `_id` → username, password, role, email, createdAt (admins) | direct ✔ |
| `_id` → name, description, price, category, image, isVeg, isPopular, isAvailable, createdAt, updatedAt (foods) | direct ✔ |
| `_id` → tableNumber, items, totalAmount, status, specialInstructions, createdAt, updatedAt (orders) | direct ✔ |

We keep each group of information in its own collection:

- **Admins**(`_id`, username, password, role, email, createdAt): stores administrator information.
- **Foods**(`_id`, name, description, price, category, image, isVeg, isPopular, isAvailable, createdAt, updatedAt): stores menu information.
- **Orders**(`_id`, tableNumber, items, totalAmount, status, specialInstructions, createdAt, updatedAt): stores customer orders and their embedded items.

### Handling order items

Each order item contains:

- `foodId`
- `name`
- `price`
- `quantity`
- `subtotal`

The `foodId` refers to the original food document. However, `name` and `price` are also stored inside the order item.

These values are intentionally copied from the `foods` collection when an order is placed. This preserves the food name and price at the time of ordering, even if the menu changes later.

The `subtotal` and `totalAmount` are calculated values stored with the order for convenient retrieval.

---

## 5. Boyce-Codd Normal Form (BCNF)

**Rule:** for every non-trivial FD X → Y, X is a candidate key.

| Collection | Candidate key | Main FDs | BCNF? |
|---|---|---|---|
| admins | `_id` | `_id` → all admin attributes | ✔ |
| foods | `_id` | `_id` → all food attributes | ✔ |
| orders | `_id` | `_id` → all order attributes | ✔ |

For the main collections, `_id` uniquely identifies each document and determines its other stored attributes.

The embedded `items` array is not an independent relational table in the current MongoDB implementation. A separate relational analysis of order items would require a guaranteed unique order-line key and verification of all additional functional dependencies.

Therefore, the main collection structures use their document identifiers as determinants. A complete BCNF claim for the embedded order items cannot be made without defining and enforcing a unique order-line key.

---

## 6. Rules kept by the database and backend

| Rule | Implementation |
|---|---|
| Every food item has a unique identifier | MongoDB document `_id` |
| Every order has a unique identifier | MongoDB document `_id` |
| Every admin has a unique identifier | MongoDB document `_id` |
| Food name, description, price and category are required when adding food | Backend validation |
| Food price is retrieved from MongoDB when an order is placed | Backend order validation and calculation |
| Order quantity must be a positive integer | Backend validation |
| Item subtotal = price × quantity | Calculated by the backend |
| Order total = sum of item subtotals | Calculated by the backend |
| Order items refer to existing food documents | Backend food lookup using `foodId` |
| Kitchen updates the existing order status | Updates the `orders` collection |
| Order status follows the defined progression | Backend status validation |
| Cart is temporary | Maintained in frontend `CartContext.jsx`, not a permanent MongoDB collection |

The stored kitchen status progression is:

`Pending → Preparing → Ready → Served`

The API accepts `completed` as an input status and maps it to the stored status `Served`.

