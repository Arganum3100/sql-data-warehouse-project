/*
===============================================================================
Procedure: silver.load_silver

Description:
  Loads data from the Bronze layer into the Silver layer by applying
  data cleansing, standardization, validation, and business rules to
  produce high-quality, analysis-ready datasets.

Transformation Summary:
  - Remove duplicate records.
  - Clean and standardize text values.
  - Validate and convert date fields.
  - Standardize categorical values.
  - Correct inconsistent sales and pricing data.
  - Standardize customer and product identifiers.
  - Calculate product validity periods.
===============================================================================
*/

CREATE OR REPLACE PROCEDURE silver.load_silver()
LANGUAGE plpgsql
AS $$
BEGIN

	RAISE NOTICE '>> Truncating Table silver.crm_cust_info';
	TRUNCATE TABLE silver.crm_cust_info;
	RAISE NOTICE '>> Inserting bronze.crm_cust_info Into Table silver.crm_cust_info';
	INSERT INTO silver.crm_cust_info(
		cst_id ,
		cst_key,
		cst_firstname,
		cst_lastname,
		cst_marital_status,
		cst_gndr,
		cst_create_date)
	
	SELECT
	cst_id,
	cst_key,
	TRIM(cst_firstname) AS cst_firstname,
	TRIM(cst_lastname) AS cst_lastname,
  --Data Standardization: Convert martial status codes to readable format.
	CASE UPPER(TRIM(cst_marital_status)) 
		 WHEN 'S' THEN 'Single'
		 WHEN 'M' THEN 'Married'
		 ELSE 'n/a'
	END AS cst_marital_status,
  --Data Standardization: Convert gender codes to readable format.
	CASE UPPER(TRIM(cst_gndr))
		 WHEN 'F' THEN 'Female'
		 WHEN 'M' THEN 'Male'
		 ELSE 'n/a'
	END AS cst_gndr,
	cst_create_date
  --Business Rule: Remove duplicate customer records by retaining the latest creation date of each customer.
	FROM (
		SELECT
		*,
		ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) as flag_latest
		FROM bronze.crm_cust_info
		WHERE cst_id IS NOT NULL
	) t WHERE flag_latest = 1;
	
	RAISE NOTICE '>> Truncating Table silver.crm_prd_info';
	TRUNCATE TABLE silver.crm_prd_info;
	RAISE NOTICE '>> Inserting bronze.crm_prd_info Into Table silver.crm_prd_info';
	INSERT INTO silver.crm_prd_info(
		prd_id,
		prd_cat,
		prd_key,
		prd_nm,
		prd_cost,
		prd_line,
		prd_start_dt,
		prd_end_dt)
	
	SELECT
	prd_id,
  --Data Standardization: Extract the category identifier used to join with the ERP product category table.
	REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
  --Data Standardization: Extract the product identifier by removing the category prefix.
	SUBSTRING(prd_key, 7, LENGTH(prd_key)) AS prd_key,
	TRIM(prd_nm) AS prd_nm,
  --Data Cleansing: Replace NULL product costs with 0 to ensure a valid numeric value.
	COALESCE(prd_cost, 0) AS prd_cost,
  --Data Standardization: Convert product lines to readable format.
	CASE UPPER(TRIM(prd_line))
		 WHEN 'S' THEN 'Other Sales'
		 WHEN 'M' THEN 'Mountain'
		 WHEN 'R' THEN 'Road'
		 WHEN 'T' THEN 'Touring'
		 ELSE 'n/a'
	END AS prd_line,
	CAST(prd_start_dt AS DATE) AS prd_start_dt,
  --Business Rule: Prevent overlapping product validity periods by assigning each product version an end date equal to one day before the next version begins.
	CAST(LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) AS DATE) - 1 AS prd_end_dt
	FROM bronze.crm_prd_info;
	
	RAISE NOTICE '>> Truncating Table silver.crm_sales_details';
	TRUNCATE TABLE silver.crm_sales_details;
	RAISE NOTICE '>> Inserting bronze.crm_sales_details Into Table silver.crm_sales_details';
	INSERT INTO silver.crm_sales_details(
		sls_ord_num,
		sls_prd_key,
		sls_cust_id,
		sls_order_dt,
		sls_ship_dt,
		sls_due_dt,
		sls_sales,
		sls_quantity,
		sls_price)
	
	SELECT
	sls_ord_num,
	sls_prd_key,
	sls_cust_id,
  --Data Validation: Convert invalid order, ship, and due dates to NULL before converting valid values to the DATE data type.
	CASE WHEN sls_order_dt = 0 OR LENGTH(CAST(sls_order_dt AS VARCHAR)) != 8 THEN NULL
		 ELSE TO_DATE(CAST(sls_order_dt AS TEXT), 'YYYYMMDD')
	END AS sls_order_dt,
	CASE WHEN sls_ship_dt = 0 OR LENGTH(CAST(sls_ship_dt AS VARCHAR)) != 8 THEN NULL
		 ELSE TO_DATE(CAST(sls_ship_dt AS TEXT), 'YYYYMMDD')
	END AS sls_ship_dt,
	CASE WHEN sls_due_dt = 0 OR LENGTH(CAST(sls_due_dt AS VARCHAR)) != 8 THEN NULL
		 ELSE TO_DATE(CAST(sls_due_dt AS TEXT), 'YYYYMMDD')
	END AS sls_due_dt,
  --Data Validation: Validate sales and price values against the formula: Sales = Quantity × Unit Price.
	CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price) THEN sls_quantity * ABS(sls_price)
		 ELSE sls_sales
	END AS sls_sales,
	sls_quantity,
	CASE WHEN sls_price IS NULL OR sls_price <= 0 THEN sls_sales / NULLIF(sls_quantity, 0)
		 ELSE sls_price
	END AS sls_price
	FROM bronze.crm_sales_details;
	
	RAISE NOTICE '>> Truncating Table silver.erp_cust_az12';
	TRUNCATE TABLE silver.erp_cust_az12;
	RAISE NOTICE '>> Inserting bronze.erp_cust_az12 Into Table silver.erp_cust_az12';
	INSERT INTO silver.erp_cust_az12 (
		cid,
		bdate,
		gen)
	
	SELECT
  --Data Standardization: Remove 'NAS' from the prefix of customer ID to ensure consistent identifier.
	CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LENGTH(cid))
		 ELSE cid
	END AS cid,
  --Data Validation: Remove impossible dates.
	CASE WHEN bdate < '1926-01-01' OR bdate > CURRENT_DATE THEN NULL
		 ELSE bdate
	END AS bdate,
  --Data Standardization: Convert gender codes to readable format.
	CASE UPPER(TRIM(gen))
		 WHEN 'F' THEN 'Female'
		 WHEN 'M' THEN 'Male'
		 ELSE 'n/a'
	END AS gen
	FROM bronze.erp_cust_az12;
	
	RAISE NOTICE '>> Truncating Table silver.erp_loc_a101';
	TRUNCATE TABLE silver.erp_loc_a101;
	RAISE NOTICE '>> Inserting bronze.erp_loc_a101 Into Table silver.erp_loc_a101';
	INSERT INTO silver.erp_loc_a101 (
		cid,
		cntry
		)
	
	SELECT
	REPLACE(cid, '-', ''),
  --Data Standardization: Convert country to readable format.
	CASE 
		 WHEN TRIM(cntry) = 'DE' THEN 'Germany'
		 WHEN TRIM(cntry) IN ('US', 'USA')  THEN 'United States'
		 WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
		 ELSE TRIM(cntry)
	END AS cntry
	FROM bronze.erp_loc_a101;
	
	RAISE NOTICE '>> Truncating Table silver.erp_px_cat_g1v2';
	TRUNCATE TABLE silver.erp_px_cat_g1v2;
	RAISE NOTICE '>> Inserting bronze.erp_px_cat_g1v2 Into Table silver.erp_px_cat_g1v2';
	INSERT INTO silver.erp_px_cat_g1v2 (
		id,
		cat,
		subcat,
		maintenance
	)
	
	SELECT
	id,
	cat,
	subcat,
	maintenance
	FROM bronze.erp_px_cat_g1v2;
END;
$$;
