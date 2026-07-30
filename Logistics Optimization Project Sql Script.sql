-- =========================================
-- LOGISTICS OPTIMIZATION PROJECT
-- =========================================
CREATE DATABASE logistics_project;
USE logistics_project; 
-- =========================================
-- TASK 1: Data Cleaning & Preparation
-- =========================================
SHOW TABLES;
SELECT * FROM orders LIMIT 10;

-- 1. Identify duplicate Order_ID records
SELECT Order_ID , COUNT(*) AS count
FROM orders
GROUP BY Order_ID
HAVING COUNT(*) > 1;

-- 2. Check for NULL Traffic_Delay_Min values
SELECT * 
FROM routes
WHERE Traffic_Delay_Min is NULL;

-- 3. Check date format consistency
SELECT Order_Date, Expected_Delivery_Date, Actual_Delivery_Date
FROM orders
LIMIT 10;

-- 4. Identify invalid dates (Actual < Order Date)
SELECT *
FROM orders
WHERE Actual_Delivery_Date < Order_Date;

-- 5. Add flag column for invalid dates
ALTER TABLE orders
ADD COLUMN Invalid_Date_Flag VARCHAR(10);

SELECT * FROM orders;

-- 6. Update invalid date records
UPDATE orders
SET Invalid_Date_Flag = 'Invalid'
WHERE Actual_Delivery_Date < Order_Date;

SELECT * FROM orders;

-- View flagged records
SELECT *
FROM orders
WHERE Invalid_Date_Flag = 'Invalid';
SET SQL_SAFE_UPDATES = 0;
UPDATE orders
SET Invalid_Date_Flag = 'Invalid'
WHERE Actual_Delivery_Date < Order_Date;

-- =========================================
-- TASK 2: Delivery Delay Analysis
-- =========================================

-- 1. Calculate delivery delay (in days)
SELECT
     Order_ID,
     Expected_Delivery_Date,
     Actual_Delivery_Date,
     DATEDIFF(Actual_Delivery_Date,Expected_Delivery_Date) AS Delay_Days
FROM orders
LIMIT 10;
-- Add Delay_Days column
ALTER TABLE orders
ADD COLUMN Delay_Days INT;
UPDATE orders
SET Delay_Days = DATEDIFF(Actual_Delivery_Date,Expected_Delivery_Date);
-- 2. Top 10 delayed routes (average delay)
SELECT 
    Route_ID,
    AVG(Delay_days) AS Avg_Delay
FROM orders
GROUP BY Route_ID
ORDER BY Avg_Delay DESC
LIMIT 10;
-- 3. Rank orders by delay within each warehouse
SELECT 
    Order_ID,
    Warehouse_ID,
    Delay_Days,
    RANK() OVER (
        PARTITION BY Warehouse_ID 
        ORDER BY Delay_Days DESC
    ) AS Delay_Rank
FROM orders;

-- =========================================
-- TASK 3: Route Optimization Insights
-- =========================================

-- 1. Calculate route metrics
SELECT 
    o.Route_ID,
    -- Avg delivery time
    AVG(DATEDIFF(o.Actual_Delivery_Date, o.Order_Date)) AS Avg_Delivery_Time_Days,
    -- Avg traffic delay
    AVG(r.Traffic_Delay_Min) AS Avg_Traffic_Delay,
    -- Efficiency ratio
    (r.Distance_KM / r.Average_Travel_Time_Min) AS Efficiency_Ratio
FROM orders o
JOIN routes r 
ON o.Route_ID = r.Route_ID
GROUP BY 
    o.Route_ID, r.Distance_KM, r.Average_Travel_Time_Min;
-- 2. Identify 3 worst efficiency routes   
SELECT 
    Route_ID,
    (Distance_KM / Average_Travel_Time_Min) AS Efficiency_Ratio
FROM routes
ORDER BY Efficiency_Ratio ASC
LIMIT 3;

SELECT 
    Route_ID,
    Start_Location,
    End_Location,
    (Distance_KM / Average_Travel_Time_Min) AS Efficiency_Ratio
FROM routes
ORDER BY Efficiency_Ratio ASC
LIMIT 3;
-- 3. Routes with >20% delayed shipments
SELECT 
    Route_ID,
    COUNT(*) AS Total_Orders,
    SUM(CASE 
        WHEN Delay_Days > 0 THEN 1 
        ELSE 0 
    END) AS Delayed_Orders,
    (SUM(CASE 
        WHEN Delay_Days > 0 THEN 1 
        ELSE 0 
    END) * 100.0 / COUNT(*)) AS Delay_Percentage
FROM orders
GROUP BY Route_ID
HAVING Delay_Percentage > 20;

-- 4. Recommendations
/*High delay routes should be optimized using better path selection
Low efficiency routes require improved travel time management
Traffic delays can be reduced using real-time routing
Critical routes should be prioritized for monitoring*/

-- =========================================
-- TASK 4: Warehouse Performance
-- =========================================
-- 1. Top 3 warehouses with highest processing time
SELECT 
    Warehouse_ID,
    AVG(DATEDIFF(Actual_Delivery_Date, Order_Date)) AS Avg_Processing_Time
FROM orders
GROUP BY Warehouse_ID
ORDER BY Avg_Processing_Time DESC
LIMIT 3;

-- 2. Total vs delayed shipments
SELECT 
    Warehouse_ID,
    COUNT(*) AS Total_Shipments,
    SUM(CASE 
        WHEN Delay_Days > 0 THEN 1 
        ELSE 0 
    END) AS Delayed_Shipments
FROM orders
GROUP BY Warehouse_ID;
-- 3. Bottleneck warehouses (above global average)
SELECT 
    Warehouse_ID,
    AVG(DATEDIFF(Actual_Delivery_Date, Order_Date)) AS Avg_Processing_Time
FROM orders
GROUP BY Warehouse_ID
HAVING Avg_Processing_Time > (
    SELECT AVG(DATEDIFF(Actual_Delivery_Date, Order_Date))
    FROM orders
);
-- 4. Rank warehouses by on-time %
SELECT 
    Warehouse_ID,
    COUNT(*) AS Total_Orders,
    SUM(CASE 
        WHEN Delay_Days <= 0 THEN 1 
        ELSE 0 
    END) AS OnTime_Orders,
    (SUM(CASE 
        WHEN Delay_Days <= 0 THEN 1 
        ELSE 0 
    END) * 100.0 / COUNT(*)) AS OnTime_Percentage
FROM orders
GROUP BY Warehouse_ID
ORDER BY OnTime_Percentage DESC;

-- =========================================
-- TASK 5: Delivery Agent Performance
-- =========================================
-- 1. Rank agents per route by on-time %
SELECT 
    da.Agent_ID,
    o.Route_ID,
    (SUM(CASE 
        WHEN o.Delay_Days <= 0 THEN 1 
        ELSE 0 
    END) * 100.0 / COUNT(*)) AS OnTime_Percentage,
    RANK() OVER (
        PARTITION BY o.Route_ID
        ORDER BY 
        (SUM(CASE 
            WHEN o.Delay_Days <= 0 THEN 1 
            ELSE 0 
        END) * 100.0 / COUNT(*)) DESC
    ) AS Rank_Agent
FROM orders o
JOIN deliveryagents da
ON o.Route_ID = da.Route_ID
GROUP BY da.Agent_ID, o.Route_ID;

-- 2. Agents with <80% on-time performance
SELECT 
    da.Agent_ID,
    (SUM(CASE 
        WHEN o.Delay_Days <= 0 THEN 1 
        ELSE 0 
    END) * 100.0 / COUNT(*)) AS OnTime_Percentage
FROM orders o
JOIN deliveryagents da
ON o.Route_ID = da.Route_ID
GROUP BY da.Agent_ID
HAVING OnTime_Percentage < 80;

-- 3. Compare speed of top 5 vs bottom 5 agents

SELECT 
    'Top 5 Agents' AS Category,
    AVG(Avg_Speed_KM_HR) AS Avg_Speed
FROM (
    SELECT Avg_Speed_KM_HR
    FROM deliveryagents
    ORDER BY On_Time_Percentage DESC
    LIMIT 5
) AS top_agents
UNION
SELECT 
    'Bottom 5 Agents',
    AVG(Avg_Speed_KM_HR)
FROM (
    SELECT Avg_Speed_KM_HR
    FROM deliveryagents
    ORDER BY On_Time_Percentage ASC
    LIMIT 5
) AS bottom_agents;

-- =========================================
-- TASK 6: Shipment Tracking Analytics
-- =========================================

-- 1. Last checkpoint per order
SELECT 
    Order_ID,
    MAX(Checkpoint_Time) AS Last_Checkpoint_Time
FROM shipment
GROUP BY Order_ID;
-- 2. Most common delay reasons
SELECT 
    Delay_Reason,
    COUNT(*) AS Frequency
FROM shipment
WHERE Delay_Reason IS NOT NULL
AND Delay_Reason <> 'None'
GROUP BY Delay_Reason
ORDER BY Frequency DESC;
-- 3. Orders with >2 delayed checkpoints
SELECT 
    Order_ID,
    COUNT(*) AS Delayed_Checkpoints
FROM shipment
WHERE Delay_Reason IS NOT NULL
AND Delay_Reason <> 'None'
GROUP BY Order_ID
HAVING COUNT(*) > 2;


-- =========================================
-- TASK 7: Advanced KPI Reporting
-- =========================================

-- 1. Avg delivery delay per region
SELECT 
    r.Start_Location,
    AVG(o.Delay_Days) AS Avg_Delivery_Delay
FROM orders o
JOIN routes r
ON o.Route_ID = r.Route_ID
GROUP BY r.Start_Location;
-- 2. Overall on-time delivery %
SELECT 
    (SUM(CASE 
        WHEN Delay_Days <= 0 THEN 1 
        ELSE 0 
    END) * 100.0 / COUNT(*)) AS OnTime_Percentage
FROM orders;
-- 3. Avg traffic delay per route
SELECT 
    Route_ID,
    AVG(Traffic_Delay_Min) AS Avg_Traffic_Delay
FROM routes
GROUP BY Route_ID;





