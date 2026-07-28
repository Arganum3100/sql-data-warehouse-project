/*
===============================================================================
Gold Layer Quality Checks
===============================================================================

Purpose:
    Validate the integrity of the Gold layer before it is consumed by reporting
    and analytics tools.

Checks Performed:
    1. Verify surrogate keys are unique in dimension tables.
    2. Verify fact records successfully reference dimension records.
    3. Identify potential data model integrity issues.

===============================================================================
*/



-- Check 1: Customer Dimension
-- Verify that each surrogate customer key is unique.
-- Expected Result: No rows returned.
SELECT
    customer_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;


-- Check 2: Product Dimension
-- Verify that each surrogate product key is unique.
-- Expected Result: No rows returned.
SELECT
    product_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;


-- Check 3: Fact Table Referential Integrity
-- Verify that every sales record is linked to a valid customer and product dimension record.
-- Expected Result: Customer Key and Product Key should be populated for every sales record. Any NULL dimension key indicates a failed lookup or missing dimension record.
SELECT
    s.order_number,
    s.customer_key,
    s.product_key
FROM gold.fact_sales s
LEFT JOIN gold.dim_customers c
    ON c.customer_key = s.customer_key
LEFT JOIN gold.dim_products p
    ON p.product_key = s.product_key
WHERE c.customer_key IS NULL
   OR p.product_key IS NULL;
