/*
===============================================================================
Silver Layer Quality Checks
===============================================================================

Purpose:
    Validate the Silver layer after data cleansing, standardization, validation,
    and business rule enforcement.

Expected Result:
    Unless otherwise specified, all queries should return zero rows.
===============================================================================
*/

-- ============================================================================
-- Table: silver.crm_cust_info
-- ============================================================================

-- Check 1: Duplicate Customer IDs
SELECT
    cst_id,
    COUNT(*) AS duplicate_count
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1;


-- Check 2: Null Customer IDs
SELECT *
FROM silver.crm_cust_info
WHERE cst_id IS NULL;


-- Check 3: Invalid Marital Status Values
SELECT DISTINCT cst_marital_status
FROM silver.crm_cust_info
WHERE cst_marital_status NOT IN ('Single', 'Married', 'n/a');


-- Check 4: Invalid Gender Values
SELECT DISTINCT cst_gndr
FROM silver.crm_cust_info
WHERE cst_gndr NOT IN ('Male', 'Female', 'n/a');


-- ============================================================================
-- Table: silver.crm_prd_info
-- ============================================================================

-- Check 5: Null Product Keys
SELECT *
FROM silver.crm_prd_info
WHERE prd_key IS NULL;


-- Check 6: Negative Product Cost
SELECT *
FROM silver.crm_prd_info
WHERE prd_cost < 0;


-- Check 7: Invalid Product Date Range
SELECT *
FROM silver.crm_prd_info
WHERE prd_end_dt IS NOT NULL
  AND prd_end_dt < prd_start_dt;


-- Check 8: Invalid Product Line Values
SELECT DISTINCT prd_line
FROM silver.crm_prd_info
WHERE prd_line NOT IN (
    'Mountain',
    'Road',
    'Touring',
    'Other Sales',
    'n/a'
);


-- ============================================================================
-- Table: silver.crm_sales_details
-- ============================================================================

-- Check 9: Null Customer References
SELECT *
FROM silver.crm_sales_details
WHERE sls_cust_id IS NULL;


-- Check 10: Null Product References
SELECT *
FROM silver.crm_sales_details
WHERE sls_prd_key IS NULL;


-- Check 11: Invalid Sales Calculation
SELECT *
FROM silver.crm_sales_details
WHERE sls_sales <> sls_quantity * ABS(sls_price);


-- Check 12: Invalid Order Timeline
SELECT *
FROM silver.crm_sales_details
WHERE (sls_ship_dt IS NOT NULL
       AND sls_order_dt IS NOT NULL
       AND sls_ship_dt < sls_order_dt)
   OR (sls_due_dt IS NOT NULL
       AND sls_order_dt IS NOT NULL
       AND sls_due_dt < sls_order_dt);


-- ============================================================================
-- Table: silver.erp_cust_az12
-- ============================================================================

-- Check 13: Customer IDs Still Containing NAS Prefix
SELECT *
FROM silver.erp_cust_az12
WHERE cid LIKE 'NAS%';


-- Check 14: Invalid Birth Dates
SELECT *
FROM silver.erp_cust_az12
WHERE bdate > CURRENT_DATE;


-- Check 15: Invalid Gender Values
SELECT DISTINCT gen
FROM silver.erp_cust_az12
WHERE gen NOT IN ('Male', 'Female', 'n/a');


-- ============================================================================
-- Table: silver.erp_loc_a101
-- ============================================================================

-- Check 16: Country Codes Not Standardized
SELECT DISTINCT cntry
FROM silver.erp_loc_a101
WHERE cntry IN ('US', 'USA', 'DE', '');


-- ============================================================================
-- Table: silver.erp_px_cat_g1v2
-- ============================================================================

-- Check 17: Duplicate Category IDs
SELECT
    id,
    COUNT(*) AS duplicate_count
FROM silver.erp_px_cat_g1v2
GROUP BY id
HAVING COUNT(*) > 1;
