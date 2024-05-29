-- Inspect the entire sales data sample table
select * from [dbo].[sales_data_sample]

-- Checking for Unique Values

-- Get distinct values of status
select distinct status from [dbo].[sales_data_sample]; -- plot in Tableau

-- Get distinct values of year_id
select distinct year_id from [dbo].[sales_data_sample];

-- Get distinct values of PRODUCTLINE
select distinct PRODUCTLINE from [dbo].[sales_data_sample]; -- plot in Tableau

-- Get distinct values of COUNTRY
select distinct COUNTRY from [dbo].[sales_data_sample]; -- plot in Tableau

-- Get distinct values of DEALSIZE
select distinct DEALSIZE from [dbo].[sales_data_sample]; -- plot in Tableau

-- Get distinct values of TERRITORY
select distinct TERRITORY from [dbo].[sales_data_sample]; -- plot in Tableau


-- Group sales by PRODUCTLINE and order by revenue
select PRODUCTLINE, sum(sales) as revenue
from [dbo].[sales_data_sample]
group by PRODUCTLINE
order by revenue desc;


-- Group sales by YEAR_ID and order by revenue
select YEAR_ID, sum(sales) as revenue
from [dbo].[sales_data_sample]
group by YEAR_ID
order by revenue desc;


-- Explore the data and investigate why the revenue generated is very low in comparison to other years

-- Check distinct months for the year 2005
select distinct MONTH_ID from [dbo].[sales_data_sample]
where year_id = 2005; -- only 5 months sales were considered


-- Group sales by DEALSIZE and order by revenue
select DEALSIZE, sum(sales) as revenue
from [dbo].[sales_data_sample]
group by DEALSIZE
order by revenue desc;

-- Best month for sales in 2003
select MONTH_ID, sum(sales) as revenue, count(ORDERNUMBER) as frequency
from [dbo].[sales_data_sample]
where YEAR_ID = 2003
group by MONTH_ID
order by revenue desc;

-- Best month for sales in 2004
select MONTH_ID, sum(sales) as revenue, count(ORDERNUMBER) as frequency
from [dbo].[sales_data_sample]
where YEAR_ID = 2004
group by MONTH_ID
order by revenue desc;

-- Best Month for Sales and Earnings by Product Line

-- Sales and earnings by PRODUCTLINE for November 2004
select MONTH_ID, PRODUCTLINE, sum(sales) as revenue, count(ORDERNUMBER) as frequency
from [dbo].[sales_data_sample]
where YEAR_ID = 2004 and MONTH_ID = 11
group by MONTH_ID, PRODUCTLINE
order by revenue desc;

-- Sales and earnings by PRODUCTLINE for November 2003
select MONTH_ID, PRODUCTLINE, sum(sales) as revenue, count(ORDERNUMBER) as frequency
from [dbo].[sales_data_sample]
where YEAR_ID = 2003 and MONTH_ID = 11
group by MONTH_ID, PRODUCTLINE
order by revenue desc;


-- Identifying the Best Customer

-- Identify the best customer by various metrics
select 
    CUSTOMERNAME,
    sum(sales) as MonetaryValue,
    avg(sales) as AvgMonetaryValue,
    count(ORDERNUMBER) as Frequency,
    max(ORDERDATE) as last_order_date,
    (select max(ORDERDATE) from [dbo].[sales_data_sample]) as max_order_date,
    DATEDIFF(DD, max(ORDERDATE), (select max(ORDERDATE) from [dbo].[sales_data_sample])) as Recency
from [dbo].[sales_data_sample]
group by CUSTOMERNAME;

-- RFM Segmentation 
-- Dropping the temporary table if exists
DROP TABLE IF EXISTS #rfm;

-- RFM segmentation calculation
;WITH rfm AS (
    select 
        CUSTOMERNAME, 
        sum(sales) as monetary_value,
        avg(sales) as avg_monetary_value,
        count(ORDERNUMBER) as frequency,
        max(ORDERDATE) as last_order_date,
        (select max(ORDERDATE) from [dbo].[sales_data_sample]) as max_order_date,
        DATEDIFF(DD, max(ORDERDATE), (select max(ORDERDATE) from [dbo].[sales_data_sample])) as recency
    from [dbo].[sales_data_sample]
    group by CUSTOMERNAME
),
rfm_calc AS (
    select r.*,
        NTILE(4) OVER (order by recency desc) as rfm_recency,
        NTILE(4) OVER (order by frequency) as rfm_frequency,
        NTILE(4) OVER (order by monetary_value) as rfm_monetary
    from rfm r
)
select 
    c.*, 
    rfm_recency + rfm_frequency + rfm_monetary as rfm_sum,
    cast(rfm_recency as varchar) + cast(rfm_frequency as varchar) + cast(rfm_monetary as varchar) as rfm_concat
into #rfm
from rfm_calc c;

-- Categorize customers based on RFM segments
select 
    CUSTOMERNAME, 
    rfm_recency, 
    rfm_frequency, 
    rfm_monetary,
    case 
        when rfm_concat in ('111', '112', '121', '122', '123', '132', '211', '212', '114', '141') then 'lost_customers'
        when rfm_concat in ('133', '134', '143', '244', '334', '343', '344', '144') then 'slipping away, cannot lose'
        when rfm_concat in ('311', '411', '331', '421') then 'new customers'
        when rfm_concat in ('222', '223', '233', '322') then 'potential churners'
        when rfm_concat in ('323', '333', '321', '422', '332', '432') then 'active'
        when rfm_concat in ('433', '434', '443', '444') then 'loyal'
    end as rfm_segment
from #rfm;


-- Find products most often sold together
select distinct ORDERNUMBER, stuff(
    (
        select ',' + PRODUCTCODE
        from [dbo].[sales_data_sample] p
        where ORDERNUMBER in (
            select ORDERNUMBER
            from (
                select ORDERNUMBER, count(*) as rn
                from [dbo].[sales_data_sample]
                where STATUS = 'Shipped'
                group by ORDERNUMBER
            ) m
            where rn = 3
        )
        and p.ORDERNUMBER = s.ORDERNUMBER
        for xml path ('')
    ), 1, 1, ''
) as ProductCodes
from [dbo].[sales_data_sample] s
order by ProductCodes desc;
