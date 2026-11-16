-- =========================================================================
-- E-commerce Shipping & Delivery Performance Analysis - SQL
-- =========================================================================
-- Author: Sahil Bhowad
-- Tool: SQL Server (SSMS)
-- Table: ecommerce_shipping (50,000 rows)
-- Purpose: 
--   1. Replicate and validate the core delivery bottleneck and 
--      logistics metrics originally built in Python/Pandas.
--   2. Demonstrate advanced SQL proficiency (Aggregate Functions, 
--      CTEs, Window Functions) for deeper supply chain insights.
-- ========================================================================

-- Create Database
CREATE DATABASE ECommerceDeliveryDB;

USE ECommerceDeliveryDB;

-- NOTE: Table was created via SSMS's Import Flat File wizard, using
-- ecommerce_shipping_cleaned.csv. ALTER statements below refine column types.

-- Ensure the column is explicitly set to decimal with 2 decimal places
ALTER TABLE ecommerce_shipping
ALTER COLUMN product_weight_kg DECIMAL(10,2);

ALTER TABLE ecommerce_shipping
ALTER COLUMN order_value_usd DECIMAL(10,2);

ALTER TABLE ecommerce_shipping
ALTER COLUMN distance_km DECIMAL(10,2);

ALTER TABLE ecommerce_shipping
ALTER COLUMN shipping_cost_usd DECIMAL(10,2);

ALTER TABLE ecommerce_shipping
ALTER COLUMN warehouse_processing_hours DECIMAL(10,2);

ALTER TABLE ecommerce_shipping
ALTER COLUMN shipping_cost_per_kg DECIMAL(10,2);




-- View entire Table (Data)
SELECT * FROM ecommerce_shipping ;

-- =========================================================================
-- 1. Foundation Aggregates
-- =========================================================================

-- -------------------------------------------------------------------------
-- Q1. What % of orders are Early, On-time or Delayed ?
-- -------------------------------------------------------------------------

SELECT 
	delivery_performance, COUNT(*) AS order_count, 
	ROUND(COUNT(*)  * 100 / CAST(SUM(COUNT(*)) OVER()AS FLOAT),2)
	AS percentage
FROM ecommerce_shipping 
GROUP BY delivery_performance
;

-- Insight: 56.32% of orders are delayed — this is the baseline problem size.


-- ------------------------------------------------------------------------
-- Q2. Which warehouse has the worst average delay ? 
-- -------------------------------------------------------------------------

SELECT 
	warehouse_city, 
	ROUND(AVG(CAST(delivery_delay_days AS FLOAT)),2) AS delay_average
FROM ecommerce_shipping 
GROUP BY warehouse_city
ORDER BY delay_average DESC
;

-- Insight: Sydney has the highest average delay at 1.32 days.


-- -------------------------------------------------------------------------
-- Q3. What is the late delivery rate of each carrier ?
-- -------------------------------------------------------------------------

SELECT 
	carrier,
	COUNT(*) AS total_orders,
	ROUND(SUM(CASE WHEN late_delivery = 'Yes' THEN 1 ELSE 0 END) * 100 / CAST(COUNT(*) AS FLOAT),2) AS percentage
FROM ecommerce_shipping
GROUP BY carrier
;

-- Insight: Carrier-level view, before drilling into carrier + method combos below.


-- -------------------------------------------------------------------------
-- Q4. What is the average shipping cost per kg, by shipping method?
-- -------------------------------------------------------------------------

SELECT
	shipping_method, 
	ROUND(AVG(shipping_cost_per_kg),2) AS average_cost
FROM ecommerce_shipping
GROUP BY shipping_method
ORDER BY average_cost
;

-- Insight: International shipping costs ~$463/kg vs ~$106/kg for Economy.


-- =========================================================================
-- 2. CONDITIONAL LOGIC (CASE WHEN)
-- =========================================================================

-- -------------------------------------------------------------------------
-- Q5. Sort late orders by how bad the delay was.
-- -------------------------------------------------------------------------

SELECT delivery_delay_days , 
	COUNT(*) AS total_orders,
	CASE 
		WHEN delivery_delay_days BETWEEN 1 AND 3 THEN 'Low Risk'
		WHEN delivery_delay_days BETWEEN 4 AND 5 THEN 'Medium Risk'
		ELSE 'High Risk' 
	END AS order_risk
FROM ecommerce_shipping 
WHERE delivery_delay_days > 0
GROUP BY delivery_delay_days
ORDER BY delivery_delay_days DESC
	;

-- Insight: Delay severity drops off sharply; 
-- While 1-day and 2-day delays affect thousands of orders, extreme delays exceeding 10 days impact only a handful of shipments.


-- -------------------------------------------------------------------------
-- Q6. Group orders into warehouse processing-speed tiers.
-- -------------------------------------------------------------------------

SELECT
	CASE
		WHEN warehouse_processing_hours <=12 THEN 'Fast'
		WHEN warehouse_processing_hours <=24 THEN 'Moderate'
		ELSE 'Slow'
	END AS  processing_speed_tier,
	count(*) AS total_orders,
	ROUND(AVG(CAST(delivery_delay_days AS FLOAT)),2) AS avg_delay
FROM ecommerce_shipping
GROUP BY 
	CASE
		WHEN warehouse_processing_hours <=12 THEN 'Fast'
		WHEN warehouse_processing_hours <=24 THEN 'Moderate'
		ELSE 'Slow'
	END
;

-- Insight: Confirms slower warehouse processing correlates with higher delay —
-- Matches the pandas groupby finding from the notebook.


-- -------------------------------------------------------------------------
-- Q7. Cross-tab of customer satisfaction tier vs delivery performance
-- -------------------------------------------------------------------------

SELECT
	delivery_performance,
	CASE 
		WHEN customer_rating <=2 THEN 'Dissatisfied'
		WHEN customer_rating >=4 THEN 'Satisfied'
		ELSE 'Neutral'
		End AS rating_tier,
	COUNT(*) AS total_orders
FROM ecommerce_shipping
GROUP BY 
	delivery_performance,
	CASE 
		WHEN customer_rating <=2 THEN 'Dissatisfied'
		WHEN customer_rating >=4 THEN 'Satisfied'
		ELSE 'Neutral'
	End 
ORDER BY delivery_performance,rating_tier DESC
;

-- Insight: Shows how satisfaction clusters differently across Early/On-time/Delayed orders.


-- =========================================================================
-- 3. WINDOW FUNCTIONS
-- =========================================================================

-- -------------------------------------------------------------------------
-- Q8. Rank all warehouses by delay severity
-- -------------------------------------------------------------------------

SELECT
	warehouse_city,
	ROUND(AVG(CAST(delivery_delay_days AS FLOAT)),2) AS avg_delay_days,
	RANK() OVER (ORDER BY AVG(CAST(delivery_delay_days AS FLOAT)) DESC) AS delay_rank
FROM ecommerce_shipping
GROUP BY warehouse_city
;

-- Insight: Sydney ranks number one for delays, requiring immediate regional supply chain review.


-- -------------------------------------------------------------------------
-- Q9. Rank each carrier's shipping methods against each other
-- (partitioned ranking — shows each carrier's own worst method,
-- not just the single global worst)
-- -------------------------------------------------------------------------

SELECT 
	carrier,
	shipping_method,
	ROUND(SUM(CASE WHEN late_delivery = 'Yes' THEN 1 ELSE 0 END) *100 / CAST(COUNT(*) AS FLOAT),2) AS delay_pct ,
	RANK() OVER (
		PARTITION BY carrier
		ORDER BY SUM(CASE WHEN late_delivery = 'Yes' THEN 1 ELSE 0 END) *100 / CAST(COUNT(*) AS FLOAT) DESC 
		) AS rank_within_carrier
FROM ecommerce_shipping
GROUP BY
carrier,shipping_method
ORDER BY carrier,delay_pct DESC
;

-- Insight: Every carrier has its own weak point — this surfaces each one individually,
-- which a single global ranking would hide.

-- -------------------------------------------------------------------------
-- Q10. Compare each order's delay to its own warehouse's average
-- (window function without collapsing rows via GROUP BY)
-- -------------------------------------------------------------------------

SELECT
	order_id,
	warehouse_city,
	delivery_delay_days,
	ROUND(AVG(CAST(delivery_delay_days AS FLOAT)) OVER (PARTITION BY warehouse_city),2) AS avg_delay_warehouse,
	ROUND(delivery_delay_days - AVG(CAST(delivery_delay_days AS FLOAT)) OVER (PARTITION BY warehouse_city),2) AS diff_warehouse_delay
FROM ecommerce_shipping
ORDER BY order_id 
;

-- Insight: Flags individual orders that are unusually bad even for an already-slow warehouse —
-- useful for spotting outlier cases, not just average trends.


-- -------------------------------------------------------------------------
-- Q11. Running (cumulative) order count by month
-- -------------------------------------------------------------------------

SELECT
	order_month,
	COUNT(*) AS monthly_orders,
	SUM(COUNT(*)) OVER (ORDER BY order_month) AS cumulative_orders
FROM ecommerce_shipping
GROUP BY order_month
ORDER BY order_month
;

-- Insight: Tracks business growth month-over-month by showing total accumulated order volume.


-- =========================================================================
-- 4. CTEs / SUBQUERIES (multi-step logic)
-- =========================================================================

-- -------------------------------------------------------------------------
-- Q12. Which warehouses perform worse than the network-wide average?
-- -------------------------------------------------------------------------

WITH warehouse_avg AS (
	SELECT
		warehouse_city,
		ROUND(AVG(CAST(delivery_delay_days AS FLOAT)),2) AS warehouse_avg
	FROM ecommerce_shipping
	GROUP BY warehouse_city
),
overall_avg AS (
	SELECT
		ROUND(AVG(CAST(delivery_delay_days AS FLOAT)),2) AS network_avg
	FROM ecommerce_shipping
)
SELECT 
	w.warehouse_city,
	w.warehouse_avg AS warehouse_avg_delay,
	o.network_avg AS network_avg_delay
FROM warehouse_avg W , overall_avg O
WHERE w.warehouse_avg > o.network_avg
ORDER BY warehouse_avg DESC
;

-- Insight: Identifies exactly which warehouses are dragging the network average down,
-- rather than just ranking all of them without a benchmark.


-- -------------------------------------------------------------------------
-- Q13. Top 5 worst carrier + method combos, filtered for reliability
-- (late rate alone can mislead if volume is tiny — filtering out
-- low-volume noise makes this a more trustworthy "worst offenders" list)
-- -------------------------------------------------------------------------

WITH combo_stats AS (
	SELECT
		carrier,
		shipping_method,
		COUNT(*) AS total_orders,
		SUM(CASE WHEN late_delivery = 'Yes' THEN 1 ELSE 0 END) AS late_orders
	FROM ecommerce_shipping
	GROUP BY carrier,shipping_method
)
SELECT
	carrier,
	shipping_method,
	total_orders,
	ROUND(late_orders * 100.0 / CAST(total_orders AS FLOAT) ,2) AS late_rate_pct
FROM combo_stats
WHERE total_orders > 100
ORDER BY late_rate_pct DESC
OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY
;

-- Insight: Filters low-volume noise to reliably identify worst-performing carrier and method combinations.


-- =========================================================================
-- 5. BUSINESS-READY / STAKEHOLDER OUTPUT
-- =========================================================================

-- -------------------------------------------------------------------------
-- Q14. Executive summary — one row per warehouse, all key metrics combined.
-- -------------------------------------------------------------------------

SELECT
	warehouse_city,
	COUNT(*) AS total_orders,
	ROUND(AVG(CAST(delivery_delay_days AS FLOAT)),2) AS avg_delay_days,
	ROUND(SUM(CASE WHEN late_delivery = 'Yes' THEN 1 ELSE 0 END) * 100 / CAST(COUNT(*) AS FLOAT),2) AS late_pct,
	ROUND(AVG(CAST(customer_rating AS FLOAT)),2) AS avg_customer_rating,
	ROUND(SUM(CASE WHEN return_requested = 'Yes' THEN 1 ELSE 0 END) * 100 / CAST(COUNT(*) AS FLOAT),2) AS return_pct
FROM ecommerce_shipping
GROUP BY warehouse_city
;

-- Insight: This single table could be handed directly to an operations manager —
-- combines delay, satisfaction, and return impact per warehouse in one view.

-- -------------------------------------------------------------------------
-- Q15. Month-over-month late delivery rate trend
-- -------------------------------------------------------------------------

SELECT 
	order_month,
	COUNT(*) AS total_orders,
	ROUND(SUM(CASE WHEN late_delivery = 'Yes' THEN 1 ELSE 0 END) * 100 / CAST(COUNT(*) AS FLOAT),2) AS late_delivery_pct
FROM ecommerce_shipping
GROUP BY order_month
ORDER BY order_month
;

-- Insight: Reveals whether delays are seasonal or trending in a direction over time.


-- =========================================================================
-- 6. DASHBOARD VALIDATION (Tableau cross-check)
-- =========================================================================

-- -------------------------------------------------------------------------
-- Q16. Page 1 headline KPIs
-- -------------------------------------------------------------------------

SELECT
	COUNT(*) AS total_orders,
	CAST(SUM(CASE WHEN late_delivery = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,1)) AS late_delivery_rate,
	CAST(AVG(delivery_delay_days * 1.0) AS DECIMAL(5,1)) AS avg_delay,
	CAST(AVG(customer_rating * 1.0) AS DECIMAL(5,1))AS avg_rating,
	CAST(SUM(CASE WHEN return_requested = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,1)) AS return_rate
FROM ecommerce_shipping
;

-- Insight: Out of 50,000 total orders, 56.3% arrive late with an average delay of 1.3 days, 
-- customer ratings down to 3.4/5.0 and pushing the return rate to 17.3%.


-- -------------------------------------------------------------------------
-- Q17. Late % by order priority
-- -------------------------------------------------------------------------

SELECT
	order_priority,
	SUM(CASE WHEN late_delivery = 'Yes' THEN 1 ELSE 0 END) AS delayed_orders,
	CAST(SUM(CASE WHEN late_delivery = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,1)) AS late_delivery_rate
FROM ecommerce_shipping
GROUP BY order_priority
ORDER BY late_delivery_rate DESC
;

-- Insight: Low priority orders suffer the highest late rate (81.7%), while Urgent orders perform best with the lowest delays (25.7%).


-- -------------------------------------------------------------------------
-- Q18. Top 10 customer countries by late %
-- -------------------------------------------------------------------------

SELECT TOP 10 
	customer_country,
	SUM(CASE WHEN late_delivery = 'Yes' THEN 1 ELSE 0 END) AS delayed_orders,
	CAST(SUM(CASE WHEN late_delivery = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,1)) AS late_delivery_rate
FROM ecommerce_shipping
GROUP BY customer_country
ORDER BY late_delivery_rate DESC
;

-- Insight: Brazil leads with the highest late delivery rate at 70.7%, followed closely by India at 69.0%.


-- -------------------------------------------------------------------------
-- Q19. Warehouse late % vs network average, in percentage points (pp)
-- -------------------------------------------------------------------------

SELECT
	warehouse_city,
	SUM(CASE WHEN late_delivery = 'Yes' THEN 1 ELSE 0 END) AS delayed_orders,
	CAST(SUM(CASE WHEN late_delivery = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,1)) AS late_delivery_rate,
	CAST(SUM(CASE WHEN late_delivery = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*)
	- (SELECT SUM(CASE WHEN late_delivery = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) FROM ecommerce_shipping) AS DECIMAL(5,2)) AS pp_warehouse_vs_network
FROM ecommerce_shipping
GROUP BY warehouse_city
ORDER BY pp_warehouse_vs_network DESC
; 

-- Insight: Sydney has the highest negative deviation (+1.26 pp) above the network average, while Singapore performs best at -2.01 pp below average.'


-- -------------------------------------------------------------------------
-- Q20. Average warehouse processing hours by delivery performance
-- -------------------------------------------------------------------------

SELECT 
	delivery_performance,
	CAST(AVG(warehouse_processing_hours) AS DECIMAL(5,1)) AS avg_processing_hours
FROM ecommerce_shipping
GROUP BY delivery_performance
ORDER BY avg_processing_hours
;

-- Insight: Delayed orders experience significantly longer warehouse processing times (16.6 hours) compared to Early shipments (8.8 hours).


-- -------------------------------------------------------------------------
-- Q21. Average rating and return rate by delivery performance
-- -------------------------------------------------------------------------

SELECT
	delivery_performance,
	CAST(AVG(customer_rating * 1.0) AS DECIMAL(5,1)) AS avg_customer_rating,
	CAST(SUM(CASE WHEN return_requested = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,1)) AS return_rate
FROM ecommerce_shipping
GROUP BY delivery_performance
ORDER BY avg_customer_rating DESC, return_rate
;

-- Insight: On-time and early deliveries maintain a high customer rating of 4.2, which drops sharply to 2.7 for delayed shipments.


-- -------------------------------------------------------------------------
-- Q22. Average rating by number of delivery attempts
-- -------------------------------------------------------------------------

SELECT
	 delivery_attempts,
	 COUNT(*) AS total_orders,
	 CAST(AVG(customer_rating * 1.0) AS DECIMAL(5,1)) AS avg_customer_rating
FROM ecommerce_shipping
GROUP BY delivery_attempts
ORDER BY delivery_attempts, avg_customer_rating
;

-- Insight: Customer ratings remain stable at 3.3 to 3.4 for 1-2 delivery attempts, but drop sharply to 2.4 when attempts reach 3.


-- -------------------------------------------------------------------------
-- Q23. Average delay by weather condition
-- -------------------------------------------------------------------------

SELECT 
	weather_condition,
	COUNT(*) AS total_orders,
	CAST(AVG(delivery_delay_days * 1.0) AS DECIMAL(5,1)) AS avg_delay_days
FROM ecommerce_shipping
GROUP BY weather_condition
ORDER BY avg_delay_d desc
;

-- Insight: Snow conditions cause the longest average delivery delays at 3.2 days, 
-- followed by Storms at 2.8 days, while Clear weather sees the lowest delay at 0.5 days.


-- -------------------------------------------------------------------------
-- Q24. Shipping cost per kg by method 
-- -------------------------------------------------------------------------

SELECT
	shipping_method,
	CAST(AVG(shipping_cost_PER_KG) AS DECIMAL(5,1)) AS cost_per_kg
FROM ecommerce_shipping
GROUP BY shipping_method
ORDER BY cost_per_kg DESC
;

-- Insight: International shipping incurs the highest average cost per kg at 463.5, while Economy is the most cost-efficient at 106.5.
