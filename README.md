# 📦 E-Commerce Shipping & Delivery Performance Analysis

**End-to-end delivery analytics project investigating why 56% of orders in a 50,000-order 
e-commerce dataset arrive late — pinpointing the exact warehouses, carriers, and shipping 
methods driving delays, and connecting them to real business costs like returns and 
customer ratings. Built with Python (pandas, seaborn) and SQL Server (T-SQL).**

📓 **[View Notebook](notebook/e-commerce_delivery_analysis.ipynb)** | 🗄️ **[View SQL Queries](sql/queries.sql)** | 🐍 Python + SQL | 📊 50,000 Orders Analyzed

---

## 📌 The Business Problem

Late deliveries don't just annoy customers — they drive returns, tank ratings, and quietly 
cost the business money. This project analyzes a **50,000-order e-commerce shipping dataset** 
to answer a specific operational question: **which warehouse-carrier-shipping method 
combinations are causing the most delays, and what's actually driving them?**

**Dataset:** 50,000 orders | 30+ columns | includes order dates, promised vs. actual delivery 
days, warehouse locations, carriers, shipping methods, delivery attempts, customer ratings, 
and return reasons.

---

## 🛠️ Technical Approach

| Stage | Tools & Method |
|---|---|
| **Data Validation** | Verified structure, types, and null patterns using `.info()`, `.isnull()`, `.describe()` |
| **Data Cleaning** | Confirmed actual date format via inspection (not assumption), removed duplicates, handled structural nulls in `return_reason` |
| **Data Integrity Check** | Validated the dataset's pre-built `delivery_delay_days` column against a manual calculation — found it floors early deliveries to 0, confirmed via `clip(lower=0)` that reduced mismatches from 5,536 to 0 |
| **Feature Engineering** | Built `delivery_variance_days` (signed delay, preserves early deliveries) and `delivery_performance` (Early / On-Time / Delayed classification) — features not present in the raw data |
| **Exploratory Analysis** | Bottleneck analysis across warehouses, carriers, shipping methods, order priority, and cost efficiency using pandas groupby + seaborn visualizations |
| **SQL Layer** | 15 queries in SQL Server, spanning aggregates, CASE WHEN logic, window functions (RANK, partitioned windows), and CTEs — reproducing and extending the Python analysis |

**Sample validation logic (data integrity check):**
```python
# Validated the dataset's pre-built delay column instead of blindly trusting it
df_shipping['delivery_variance_days'] = df_shipping['actual_delivery_days'] - df_shipping['promised_delivery_days']
mismatch_count = (df_shipping['delivery_variance_days'] != df_shipping['delivery_delay_days']).sum()
# Found 5,536 mismatches — all early deliveries, since the dataset floors delay at 0
```

**Data Flow:** Raw data was cleaned and feature-engineered in Python, then exported and 
loaded into SQL Server for the query layer — reflecting a typical real-world pipeline where 
SQL operates on a trusted, pre-validated dataset.

---

## 🗄️ SQL Highlights

**Partitioned Ranking — Each Carrier's Own Worst Shipping Method:**
```sql
SELECT 
    carrier, shipping_method,
    ROUND(SUM(CASE WHEN late_delivery = 'Yes' THEN 1 ELSE 0 END) * 100 / CAST(COUNT(*) AS FLOAT), 2) AS delay_pct,
    RANK() OVER (
        PARTITION BY carrier 
        ORDER BY SUM(CASE WHEN late_delivery = 'Yes' THEN 1 ELSE 0 END) * 100 / CAST(COUNT(*) AS FLOAT) DESC
    ) AS rank_within_carrier
FROM ecommerce_shipping
GROUP BY carrier, shipping_method;
```
*Ranks shipping methods within each carrier individually, surfacing every carrier's own 
weak point — a single global ranking would hide this.*

**CTE — Warehouses Underperforming the Network Average:**
```sql
WITH warehouse_avg AS (
    SELECT warehouse_city, AVG(delivery_delay_days) AS warehouse_avg
    FROM ecommerce_shipping GROUP BY warehouse_city
),
overall_avg AS (
    SELECT AVG(delivery_delay_days) AS network_avg FROM ecommerce_shipping
)
SELECT w.warehouse_city, w.warehouse_avg, o.network_avg
FROM warehouse_avg w, overall_avg o
WHERE w.warehouse_avg > o.network_avg
ORDER BY w.warehouse_avg DESC;
```
*Identifies exactly which warehouses are dragging the network average down, using a real 
benchmark rather than a simple ranking.*

**Full query file, organized by SQL skill tier** (aggregates → CASE WHEN → window functions 
→ CTEs → stakeholder-ready output): [`sql/queries.sql`](sql/queries.sql) | Schema: [`sql/schema.sql`](sql/schema.sql)

---

## 💡 Key Business Insights

**Delivery Performance Baseline**
- **56.32%** of all orders are delivered late — the single most common outcome
- Only **32.60%** arrive exactly on time, **11.08%** arrive early

**Warehouse Bottlenecks**
- **Sydney warehouse** has the highest average delay at **1.32 days**
- **Berlin, New York, Paris, and Sydney** show the highest delivery *variance* (1.85) — 
  these warehouses aren't just slow, they're unpredictable, swinging between early and 
  very late rather than being consistently off by a fixed amount

**Carrier & Shipping Method**
- **GlobalExpress + International shipping** is the worst-performing combination in the 
  dataset, with a **77.6%** late rate
- International shipping is also the **most expensive method** (~$463/kg avg.) vs. Economy 
  (~$106/kg) — the business is paying a premium for the least reliable option

**Root Cause Signal**
- Delayed orders show noticeably higher **warehouse processing time** before shipment — 
  the delay often starts before the package leaves the building, not just in transit

**Customer Impact**
- Average rating drops to **~2.7 stars** for delayed orders vs. **4.2+ stars** for 
  on-time/early orders
- Ratings also decline as delivery attempts increase, even for orders eventually delivered
- Delayed orders are returned at a noticeably higher rate than on-time or early orders

**Priority Handling**
- **Urgent** orders have a **25.69%** delay rate — far better than **Low/Normal** priority 
  orders, delayed **over 63%** of the time, showing the priority system works, but only 
  for the top tier

---

## 📊 Visual Highlights

**Delivery Performance Distribution**
![Delivery Performance](images/delivery_performance_distribution.png)

**Average Delay by Warehouse**
![Warehouse Delay](images/warehouse_delay.png)

**Late Delivery Rate — Carrier × Shipping Method**
![Carrier Heatmap](images/carrier_shipping_heatmap.png)

---

## 🎯 Business Recommendations

1. **Audit the Sydney warehouse first** — highest average delay in the network, the 
   single biggest lever for improving overall on-time performance.
2. **Fix the GlobalExpress + International route** — slowest (77.6% late) *and* most 
   expensive shipping method. Renegotiate the SLA or reroute volume elsewhere.
3. **Address warehouse processing time, not just transit time** — delays are visible 
   before the package even ships, making this the higher-leverage fix.
4. **Extend priority-level handling further down the order queue** — Low/Normal priority 
   orders are delayed over 2.5x more often than Urgent ones.
5. **Treat inconsistent warehouses (Berlin, Paris) differently from slow ones (Sydney)** — 
   high-variance warehouses need better forecasting and scheduling, not just "work faster."

---

## ⚠️ Limitations & Next Steps

**Limitations**
- Dataset doesn't capture *why* individual orders were delayed (traffic, staffing, 
  weather) — findings are pattern-based, not root-cause confirmed
- Customer ratings and return reasons are self-reported and may reflect factors beyond 
  delivery speed
- Single snapshot in time — no historical trend to confirm whether patterns are 
  improving or worsening

**Next Steps**
- Build a simple model to flag high-risk-of-delay orders at the time of order placement
- Incorporate cost data to evaluate operational fixes against ROI
- Track these metrics monthly to monitor trend direction

---

## 📁 Repo Structure
```
ecommerce-delivery-bottleneck-analysis/
├── README.md
├── data/ → raw & cleaned datasets (CSV)
│ ├── e-commerce_Delivery_Raw.csv
│ └── e-commerce_Delivery_cleaned.csv
├── notebook/ → Python analysis (Jupyter Notebook, pandas + seaborn)
│ └── e-commerce_delivery_analysis.ipynb
├── sql/ → SQL Server queries & schema (T-SQL)
│ ├── schema.sql
│ └── queries.sql
├── images/ → exported charts & SQL result screenshots
├── requirements.txt → Python dependencies
├── LICENSE
└── .gitignore
```
---


## 🚀 How to Run

**Python analysis:**
```bash
pip install -r requirements.txt
jupyter notebook notebook/e-commerce_delivery_analysis.ipynb
```

**SQL analysis:**
1. Run `sql/schema.sql` in SQL Server (SSMS) to create the table structure
2. Import `data/e-commerce_Delivery_cleaned.csv` into the table via SSMS's Import Flat File wizard
3. Run `sql/queries.sql` for the full 15-query analysis
