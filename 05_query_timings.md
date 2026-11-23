
# Query Timing Results

Each query was executed three times. The average execution time was calculated using the three recorded runs.

## READ Queries

| Query | Type | What it does | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) | Scan type |
|---|---|---|---:|---:|---:|---:|---|
| R1 | READ | Admin login lookup | 0.041 | 0.034 | 0.039 | 0.038 | Seq Scan |
| R2 | READ | Check admin count | 0.050 | 0.060 | 0.049 | 0.053 | Seq Scan |
| R3 | READ | Get foods with optional category filter | 2.405 | 0.074 | 0.069 | 0.849 | (Seq Scan + Sort) |
| R4 | READ | Get food by ID | 0.019 | 0.041 | 0.065 | 0.042 | Index Scan |
| R5 | READ | Check food availability | 0.034 | 0.046 | 0.037 | 0.039 | (Index Scan + Filter) |
| R6 | READ | Get order details with items | 0.193 | 0.069 | 0.104 | 0.122 | (Index Scan + Seq Scan) |
| R7 | READ | Get filtered orders with items | 0.155 | 0.121 | 0.115 | 0.130 | (Seq Scans + Hash Joins + Sort) |
| R8 | READ | Dashboard statistics | 0.188 | 0.215 | 0.133 | 0.179 | (Seq Scan + Aggregate) |

## WRITE Queries

| Query | Type | What it does | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) | Scan type |
|---|---|---|---:|---:|---:|---:|---|
| W1 | WRITE | Create admin | 0.303 | 0.095 | 0.080 | 0.159 | Insert |
| W2 | WRITE | Add food | 0.181 | 0.093 | 0.123 | 0.132 | Insert |
| W3 | WRITE | Update food | 1.009 | 0.129 | 0.109 | 0.416 | (Index Scan + Update) |
| W4 | WRITE | Delete food | 0.273 | 0.138 | 0.149 | 0.187 | (Index Scan + Delete + Foreign Key Trigger) |
| W5 | WRITE | Create order with order items | 1.594 | 0.629 | 0.545 | 0.923 | CTE + Insert |
| W6 | WRITE | Update order status | 0.214 | 0.230 | 0.161 | 0.202 | (Index Scan + Update) |


## Conclusion

The benchmarking of all 14 queries (8 READ queries and 6 WRITE queries) helped us understand how PostgreSQL executes different database operations.

The results show that:

1. **READ operations:** Simple queries generally performed quickly on our seed dataset. Queries involving multiple tables, joins, sorting, and aggregation required additional processing.

2. **WRITE operations:** INSERT, UPDATE, and DELETE operations were also executed efficiently. Queries involving primary key lookups benefited from index scans.

3. **Index usage:** PostgreSQL used primary key indexes to locate specific records in queries such as fetching food by ID, updating food details, deleting food, and updating order status.

4. **Query complexity:** Queries involving multiple tables and aggregate calculations required more execution steps than simple SELECT queries.

5. **Transaction safety:** We used `BEGIN` and `ROLLBACK` while benchmarking write queries so that the database remained unchanged after each test.

6. **Execution time variation:** Execution times varied slightly between runs due to factors such as caching, database activity, and query execution overhead.

Overall, this experiment helped us understand how PostgreSQL uses execution plans, indexes, sequential scans, joins, and aggregation to execute queries. It also provided practical experience in measuring and comparing query performance using `EXPLAIN (ANALYZE, BUFFERS)`.

**Note:** These results are based on our current seed dataset. Performance may change when the database contains a much larger amount of data.