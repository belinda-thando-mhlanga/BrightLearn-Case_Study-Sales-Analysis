SELECT *
FROM "SALES"."CASESTUDY"."SALESANALYSIS" LIMIT 10;

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Check row count
SELECT COUNT(*) AS total_rows FROM "SALES"."CASESTUDY"."SALESANALYSIS";


-- Check for NULL values
SELECT 
    COUNT(*) AS total_rows,
    COUNT(date) AS dates_populated,
    COUNT(sales) AS sales_populated,
    COUNT(cost_of_sales) AS cost_populated,
    COUNT(quantity_sold) AS quantity_populated,
    SUM(CASE WHEN date IS NULL THEN 1 ELSE 0 END) AS null_dates,
    SUM(CASE WHEN sales IS NULL THEN 1 ELSE 0 END) AS null_sales,
    SUM(CASE WHEN cost_of_sales IS NULL THEN 1 ELSE 0 END) AS null_costs,
    SUM(CASE WHEN quantity_sold IS NULL THEN 1 ELSE 0 END) AS null_quantities
FROM "SALES"."CASESTUDY"."SALESANALYSIS";

-- Check date range
SELECT 
    MIN(TO_DATE(date, 'DD/MM/YYYY')) AS earliest_date,
    MAX(TO_DATE(date, 'DD/MM/YYYY')) AS latest_date,
    DATEDIFF(day, MIN(TO_DATE(date, 'DD/MM/YYYY')), MAX(TO_DATE(date, 'DD/MM/YYYY'))) AS days_span
FROM "SALES"."CASESTUDY"."SALESANALYSIS";

-- Quick summary statistics
SELECT 
    ROUND(AVG(sales), 2) AS avg_daily_sales,
    ROUND(MIN(sales), 2) AS min_daily_sales,
    ROUND(MAX(sales), 2) AS max_daily_sales,
    ROUND(AVG(quantity_sold), 0) AS avg_daily_quantity,
    ROUND(AVG(sales / NULLIF(quantity_sold, 0)), 2) AS avg_price_per_unit
FROM "SALES"."CASESTUDY"."SALESANALYSIS";

-- =====================================================
--MAIN ANALYSIS
-- =====================================================
WITH base AS (
    SELECT 
        TO_DATE(date, 'DD/MM/YYYY') AS transaction_date,
        
        -- Original data
        sales AS total_sales,
        cost_of_sales,
        quantity_sold,

        -- Daily calculations
        ROUND(sales / NULLIF(quantity_sold, 0), 2) AS daily_price_per_unit,
        ROUND(sales - cost_of_sales, 2) AS daily_gross_profit_amount,
        ROUND(((sales - cost_of_sales) / NULLIF(sales, 0)) * 100, 2) AS daily_gross_profit_percent,
        ROUND(((sales - cost_of_sales) / NULLIF(sales, 0)) * 100, 2) AS daily_gross_profit_per_unit_percent,
        ROUND(cost_of_sales / NULLIF(quantity_sold, 0), 2) AS daily_cost_per_unit,
        ROUND((sales - cost_of_sales) / NULLIF(quantity_sold, 0), 2) AS profit_per_unit,

        -- Promo flag
        CASE 
            WHEN ROUND(sales / NULLIF(quantity_sold, 0), 2) < 32 THEN 'promotion'
            ELSE 'normal price'
        END AS price_status,

        -- Profit / Loss
        CASE 
            WHEN cost_of_sales > sales THEN 'loss'
            ELSE 'profit'
        END AS profit_status,

        -- Date dimensions
        DAYNAME(TO_DATE(date, 'DD/MM/YYYY')) AS day_of_week,
        MONTHNAME(TO_DATE(date, 'DD/MM/YYYY')) AS month_name,
        YEAR(TO_DATE(date, 'DD/MM/YYYY')) AS year,
        QUARTER(transaction_date) AS quarter,
        
        CASE 
            WHEN DAYNAME(TO_DATE(date, 'DD/MM/YYYY')) IN ('Sat', 'Sun') THEN 'weekend'
            ELSE 'weekday'
        END AS time_of_week,

        -- PED calculation
        ROUND(
            (
                (quantity_sold - LAG(quantity_sold) OVER (ORDER BY TO_DATE(date,'DD/MM/YYYY')))
                /
                NULLIF(LAG(quantity_sold) OVER (ORDER BY TO_DATE(date,'DD/MM/YYYY')), 0)
            )
            /
            (
                (
                    (sales / NULLIF(quantity_sold, 0))
                    -
                    LAG(sales / NULLIF(quantity_sold, 0)) OVER (ORDER BY TO_DATE(date,'DD/MM/YYYY'))
                )
                /
                NULLIF(LAG(sales / NULLIF(quantity_sold, 0)) OVER (ORDER BY TO_DATE(date,'DD/MM/YYYY')), 0)
            )
        , 2) AS price_elasticity_of_demand
    FROM SALES.CASESTUDY.SALESANALYSIS
)

-- ===========================================
-- Daily-level output with PED classification
-- ===========================================
SELECT
    *,
    CASE
        WHEN price_elasticity_of_demand < -1 THEN 'better on promotion (elastic)'
        WHEN price_elasticity_of_demand >= -1 THEN 'worse on promotion (inelastic)'
        ELSE 'no result'
    END AS ped_classification,
    
    -- Overall average unit sales price (subquery)
    (
        SELECT ROUND(AVG(sales / NULLIF(quantity_sold, 0)), 2)
        FROM SALES.CASESTUDY.SALESANALYSIS
    ) AS avg_unit_sales_price

FROM base
ORDER BY transaction_date;

-- ===========================================
--Promo summary per quarter
-- ===========================================
SELECT
    price_status,
    QUARTER(transaction_date) AS quarter,
    MIN(transaction_date) AS promo_start_date,
    MAX(transaction_date) AS promo_end_date,
    COUNT(*) AS days_on_promo
FROM base
WHERE price_status = 'promotion'
GROUP BY price_status, QUARTER(transaction_date)
ORDER BY quarter;
