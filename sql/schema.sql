-- ========================================================================
-- E-COMMERCE SHIPPING & DELIVERY PERFORMANCE ANALYSIS — SCHEMA
-- ========================================================================
-- Tool: SQL Server (SSMS)
-- Purpose: Defines the table structure for the ecommerce_shipping dataset.
-- ========================================================================

CREATE TABLE [dbo].[ecommerce_shipping](
	[order_id] [nvarchar](50) NOT NULL,
	[order_date] [date] NOT NULL,
	[customer_id] [nvarchar](50) NOT NULL,
	[customer_segment] [nvarchar](50) NOT NULL,
	[customer_city] [nvarchar](50) NOT NULL,
	[customer_country] [nvarchar](50) NOT NULL,
	[warehouse_id] [nvarchar](50) NOT NULL,
	[warehouse_city] [nvarchar](50) NOT NULL,
	[product_category] [nvarchar](50) NOT NULL,
	[product_weight_kg] [decimal](10, 2) NULL,
	[order_value_usd] [decimal](10, 2) NULL,
	[shipping_method] [nvarchar](50) NOT NULL,
	[carrier] [nvarchar](50) NOT NULL,
	[distance_km] [decimal](10, 2) NULL,
	[promised_delivery_days] [tinyint] NOT NULL,
	[actual_delivery_days] [tinyint] NOT NULL,
	[delivery_status] [nvarchar](50) NOT NULL,
	[late_delivery] [varchar](5) NULL,
	[delivery_delay_days] [tinyint] NOT NULL,
	[shipping_cost_usd] [decimal](10, 2) NULL,
	[package_size] [nvarchar](50) NOT NULL,
	[payment_method] [nvarchar](50) NOT NULL,
	[order_priority] [nvarchar](50) NOT NULL,
	[weather_condition] [nvarchar](50) NOT NULL,
	[customer_rating] [tinyint] NOT NULL,
	[return_requested] [varchar](5) NULL,
	[return_reason] [nvarchar](50) NOT NULL,
	[delivery_attempts] [tinyint] NOT NULL,
	[warehouse_processing_hours] [decimal](10, 2) NULL,
	[tracking_status] [nvarchar](50) NOT NULL,
	[order_day] [nvarchar](50) NOT NULL,
	[order_month] [tinyint] NOT NULL,
	[shipping_cost_per_kg] [decimal](10, 2) NULL,
	[delivery_variance_days] [smallint] NOT NULL,
	[delivery_performance] [nvarchar](50) NOT NULL
) ON [PRIMARY]