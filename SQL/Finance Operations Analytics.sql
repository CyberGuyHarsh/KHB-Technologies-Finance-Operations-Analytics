
--1. Which customers contribute the highest revenue but consistently delay payments?

WITH highestrevenue AS (
    SELECT customername,sum(sales) AS Total_Revenue,
    (
SELECT COUNT(*) FROM orders o2
WHERE o2.customerid = c.customerid AND 
(o2.paymentdate-o2.duedate)>30 )AS Total_Delay_Payments 
FROM customers c
JOIN orders o ON c.customerid = o.customerid
GROUP BY c.customername , c.customerid
ORDER BY Total_Revenue DESC,
Total_Delay_Payments DESC
LIMIT 10
)

SELECT * FROM highestrevenue
WHERE Total_Delay_Payments>0





-- 2. Which products generate high sales but low profit because of excessive discounts?

SELECT product, sum(sales),sum(o.sales)-sum(o.qty*p.cost) AS Profit ,
SUM(o.qty*p.price)-SUM(o.sales) AS Discount FROM products p
JOIN orders o ON o.productid=p.productid
GROUP BY product
HAVING 
    SUM(o.sales) > 100000
    AND SUM(o.sales) - SUM(o.qty * p.cost) < 100000
    AND SUM(o.qty * p.price) - SUM(o.sales) > 50000
ORDER BY discount DESC


-- 3. Which sales representatives bring in the highest revenue but also the highest Late Payment Occurence?
SELECT sum(sales) AS Total_Revenue,salesrep, COUNT(
CASE 
when Paymentstatus='Late'
THEN 1 
END ) AS Late_Collection_Count FROM products p
JOIN orders o ON o.productid=p.productid
GROUP BY salesrep
ORDER BY Total_Revenue DESC

--4. Which branches have the worst payment collection performance?

SELECT branch, COUNT(
CASE 
when Paymentstatus='Late' --OR Paymentstatus='Pending'
THEN 1 
END ) AS late_collection FROM orders o
JOIN customers c ON c.customerid=o.customerid
GROUP BY branch
ORDER BY late_collection DESC

-- 5. Which products generate high sales but low profit because of excessive discounts?

SELECT product, sum(sales),sum(o.sales)-sum(o.qty*p.cost) AS Profit ,
SUM(o.qty*p.price)-SUM(o.sales) AS Discount FROM products p
JOIN orders o ON o.productid=p.productid
GROUP BY product
HAVING 
    SUM(o.sales) > 100000
    AND SUM(o.sales) - SUM(o.qty * p.cost) < 100000
    AND SUM(o.qty * p.price) - SUM(o.sales) > 50000
ORDER BY discount DESC;


--6. Which customers are likely to exceed their credit limit within the next month?


WITH MonthlyPayments AS (
    SELECT 
        c.CustomerID,
        c.CustomerName,
        c.CreditLimit,
        DATE_TRUNC('month', o.OrderDate) AS Month_Date,
        SUM(o.Sales) AS Monthly_Sales
    FROM Customers c
    JOIN Orders o
        ON c.CustomerID = o.CustomerID
    GROUP BY
        c.CustomerID,
        c.CustomerName,
        c.CreditLimit,
        DATE_TRUNC('month', o.OrderDate)
),

CCSalesTrend AS (
    SELECT
        CustomerID,
        CustomerName,
        CreditLimit,
        Month_Date,
        Monthly_Sales,

        AVG(Monthly_Sales) OVER (
            PARTITION BY CustomerID
            ORDER BY Month_Date
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS Avg_Sales,

        ROW_NUMBER() OVER (
            PARTITION BY CustomerID
            ORDER BY Month_Date DESC
        ) AS rn

    FROM MonthlyPayments
)

SELECT
    st.CustomerID,
    st.CustomerName,
    st.Month_Date,
    st.CreditLimit,
    ROUND(st.Avg_Sales,2) AS Avg_Sales,

    SUM(
        CASE
            WHEN o.PaymentStatus = 'Pending'
            THEN o.Sales
            ELSE 0
        END
    ) AS Outstanding,

    st.CreditLimit -
    SUM(
        CASE
            WHEN o.PaymentStatus = 'Pending'
            THEN o.Sales
            ELSE 0
        END
    ) AS RemainingCredit

FROM CCSalesTrend st

JOIN Orders o
    ON st.CustomerID = o.CustomerID
   AND DATE_TRUNC('month', o.OrderDate) = st.Month_Date

GROUP BY
    st.CustomerID,
    st.CustomerName,
    st.Month_Date,
    st.CreditLimit,
    st.Avg_Sales

HAVING
    SUM(
        CASE
            WHEN o.PaymentStatus = 'Pending'
            THEN o.Sales
            ELSE 0
        END
    ) + st.Avg_Sales > st.CreditLimit

ORDER BY
    st.CustomerName,
    st.Month_Date;


--7. During which months does revenue increase while cash collection decreases?


WITH MonthlyData AS
(
    SELECT
        SUM(Sales) AS Revenue,
        SUM(
            CASE
                WHEN paymentstatus = 'Paid' THEN Sales
                ELSE 0
            END
        ) AS CashCollection,
        EXTRACT(MONTH FROM paymentdate) AS Month
    FROM Orders
    GROUP BY EXTRACT(MONTH FROM paymentdate)
)

SELECT
    Revenue,
    CashCollection,
    Month
FROM
(
    SELECT *,
           LAG(Revenue) OVER(ORDER BY Month) AS PrevRevenue,
           LAG(CashCollection) OVER(ORDER BY Month) AS PrevCashCollection
    FROM MonthlyData
) t
WHERE CashCollection < PrevCashCollection
  AND Revenue > PrevRevenue;


SELECT
    PaymentDate,
    EXTRACT(MONTH FROM PaymentDate) AS Month
FROM Orders
LIMIT 10;


-- SELECT DISTINCT paymentstatus
-- FROM orders;


--8. Which invoices should the finance team prioritize for collection?
--I am using three conditions for priortity: 1. pending amount 2.due date is already pass 3.One month Pass


SELECT ORDERID, invoicedate,duedate,duedate < CURRENT_DATE-INTERVAL '30 DAYS'  AS One_Month_Over , 
(CURRENT_DATE-duedate) AS OverDays FROM orders
WHERE paymentstatus = 'Pending' AND duedate > invoicedate AND duedate < CURRENT_DATE-INTERVAL '30 DAYS'


-- 9. Which regions have the highest percentage of repeat late-paying customers?
-- Business Impact:
-- Improve regional credit policy.

WITH latecus AS (
    SELECT
        c.customerid,
        COUNT(*) AS late_count
    FROM customers c
    JOIN orders o
        ON c.customerid = o.customerid
    WHERE paymentstatus = 'Late'
    GROUP BY c.customerid
    HAVING COUNT(*) > 1
),
totallatecus AS (
    SELECT DISTINCT
        c.customerid,
        c.region
    FROM customers c
    JOIN orders o
        ON c.customerid = o.customerid
    WHERE paymentstatus = 'Late'
)

SELECT
    cc.region,
    COUNT(l.customerid) AS repeat_late_customers,
    COUNT(cc.customerid) AS total_late_customers,
    ROUND(COUNT(l.customerid) * 100.0 / COUNT(cc.customerid), 2) AS repeat_late_percentage
FROM totallatecus cc
LEFT JOIN latecus l
    ON cc.customerid = l.customerid
GROUP BY cc.region
ORDER BY repeat_late_percentage DESC;

