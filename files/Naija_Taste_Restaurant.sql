-- To Create customers Table
CREATE TABLE customers (
   customer_id SERIAL PRIMARY KEY,
   name VARCHAR(100),
   phone VARCHAR(25),
   email VARCHAR(100),
   gender VARCHAR(10),
   age INT,
   location VARCHAR(100)
);

-- products table
CREATE TABLE products (
   product_id SERIAL PRIMARY KEY,
   product_name VARCHAR(100),
   price NUMERIC
);

-- sales table
CREATE TABLE sales (
   sale_id SERIAL PRIMARY KEY,
   customer_id INT REFERENCES customers(customer_id),
   product_id INT REFERENCES products(product_id),
   quantity INT,
   total_price NUMERIC,
   payment_method VARCHAR(100),
   sale_date DATE
);

-- To check my table values
SELECT * FROM customers
SELECT * FROM products
SELECT * FROM sales

-- To check for missing values in the customers table
SELECT COUNT(*) AS missing
FROM customers
WHERE customer_id IS NULL;

-- To check for missing values in the products table
SELECT COUNT(*) AS missing
FROM products
WHERE product_id IS NULL;

-- To check for missing values in the sales table
SELECT COUNT(*) AS missing
FROM sales
WHERE sale_id IS NULL;

-- To check for duplicate values in the customer table
SELECT email, COUNT(*) 
FROM customers 
GROUP BY email 
HAVING COUNT(*) > 1;

-- To check for duplicate values in the products table
SELECT product_id, COUNT(*)
FROM products
GROUP BY product_id
HAVING COUNT(*) > 1;

-- To check for duplicates in the sales table
SELECT customer_id, product_id, sale_date, COUNT(*) 
FROM sales 
GROUP BY customer_id, product_id, sale_date 
HAVING COUNT(*) > 1;

-- To see the duplicate rows to determine if it is an error or not
SELECT * FROM sales
WHERE (customer_id = 42 AND product_id = 3 AND sale_date = '2024-11-25')
    OR(customer_id = 44 AND product_id = 6 AND sale_date = '2024-12-19')
ORDER BY customer_id, product_id, sale_date;	

-- To create backup table before making updates
CREATE TABLE customers_backup AS
SELECT * FROM customers;

-- To verify the backup
SELECT * FROM customers_backup

-- To check for inconsistency in the data values
SELECT
COUNT(*) AS total_rows,
COUNT(*) FILTER (
        WHERE(s.total_price <> s.quantity * p.price)
    ) AS mismatched_rows
FROM sales   AS s
JOIN products AS p  ON p.product_id = s.product_id;

-- Customer segmentation analysis
-- Highest purchasing customer by revenue
SELECT c.customer_id,
       c.name,
	   SUM(s.total_price) AS total_spent,
	   COUNT(*) AS transaction_count,
	   AVG(s.total_price) AS avg_price
FROM customers c
JOIN sales s USING(customer_id)
GROUP BY c.customer_id, c.name
ORDER BY total_spent DESC;
	   
-- Customer segmentation by location
SELECT location, 
COUNT(*) AS location_count
FROM customers
WHERE location IS NOT NULL
GROUP BY location
ORDER BY location_count DESC;

-- Customer segmentation by age
WITH age_bands AS (
    SELECT
        customer_id,
        CASE
            WHEN age BETWEEN  0 AND 17 THEN '0-17'
            WHEN age BETWEEN 18 AND 24 THEN '18-24'
            WHEN age BETWEEN 25 AND 34 THEN '25-34'
            WHEN age BETWEEN 35 AND 44 THEN '35-44'
            WHEN age BETWEEN 45 AND 54 THEN '45-54'
            ELSE '55+'
        END AS age_group
    FROM customers
)
SELECT
    a.age_group,
    COUNT(DISTINCT c.customer_id)             AS customers,
    SUM(s.total_price)                        AS total_revenue,
    ROUND(100.0 * SUM(s.total_price) /
          SUM(SUM(s.total_price)) OVER (), 2) AS pct_of_revenue
FROM   age_bands a
JOIN   customers c USING (customer_id)
JOIN   sales    s USING (customer_id)
GROUP  BY a.age_group
ORDER  BY total_revenue DESC;

-- Sales Analysis performance
WITH latest AS (
    SELECT MAX(sale_date) AS max_dt
    FROM sales
),
product_rev AS (
    SELECT  p.product_id,
            p.product_name,
            SUM(s.total_price) AS total_revenue,
            COUNT(*)           AS transaction_count,
            AVG(s.total_price) AS avg_price
    FROM    products p
    JOIN    sales    s  USING (product_id)
    JOIN    latest   l            -- gives us latest.max_dt
      ON    s.sale_date >= l.max_dt - INTERVAL '3 months'
    GROUP   BY p.product_id, p.product_name
)
SELECT * FROM (
    SELECT * FROM product_rev
    ORDER BY total_revenue DESC
    LIMIT 5
) AS top_products
UNION ALL
SELECT * FROM (
    SELECT * FROM product_rev
    ORDER BY total_revenue ASC
    LIMIT 5
) AS bottom_products;

--Sales trend analysis
 -- busiest day on top
SELECT
    EXTRACT(DOW FROM sale_date)::int           AS dow,
    TO_CHAR(sale_date, 'Dy')                   AS day_name,
    COUNT(*)                                   AS txn_count,
    SUM(total_price)                           AS revenue
FROM   sales
GROUP  BY dow, day_name
ORDER  BY revenue DESC;                        

-- Payment method preferences
SELECT
    payment_method,
    COUNT(*)                    AS txn_count,
    SUM(total_price)            AS revenue,
    ROUND(100.0 * COUNT(*) /
          SUM(COUNT(*)) OVER (), 2)  AS pct_of_txn,
    ROUND(100.0 * SUM(total_price) /
          SUM(SUM(total_price)) OVER (), 2)  AS pct_of_rev
FROM   sales
GROUP  BY payment_method
ORDER  BY revenue DESC;

-- customer spending analysis during weekdays and weekends
WITH fact AS (
    SELECT
        CASE
            WHEN EXTRACT(DOW FROM sale_date) IN (0,6) THEN 'Weekend'
            ELSE 'Weekday'
        END                     AS day_type,
        total_price
    FROM sales
)
SELECT
    day_type,
    COUNT(*)                   AS txn_count,
    SUM(total_price)           AS revenue,
    AVG(total_price)           AS avg_ticket
FROM   fact
GROUP  BY day_type
ORDER  BY revenue DESC;


