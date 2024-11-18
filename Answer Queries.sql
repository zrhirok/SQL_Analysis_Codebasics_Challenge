-- 1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.

select distinct market from dim_customer
where customer = 'Atliq Exclusive' and region = 'APAC';



-- 2. What is the percentage of unique product increase in 2021 vs. 2020? The final output contains these fields, 
-- unique_products_2020 unique_products_2021 percentage_chg

with cte1 as
(
select count(distinct product_code) as unique_product_count_2021 from fact_sales_monthly
where fiscal_year = 2021
),

cte2 as
(
select count(distinct product_code) as unique_product_count_2020 from fact_sales_monthly
where fiscal_year = 2020
),
cte3 as
(select unique_product_count_2021, unique_product_count_2020 from cte1
cross join cte2)

select *, (((unique_product_count_2021-unique_product_count_2020)/unique_product_count_2020)*100) as prcnt_change from cte3;


-- 3. Provide a report with all the unique product counts for each segment and sort them in 
-- descending order of product counts. The final output contains 2 fields, segment product_count

select segment,
		count(product) as unique_product_count from dim_product
group by segment
order by unique_product_count desc;


-- 4. Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? 
-- The final output contains these fields, segment product_count_2020 product_count_2021 difference

select p.segment,
		count(distinct case when f.fiscal_year=2020 then f.product_code end) as product_count_2020,
        count(distinct case when f.fiscal_year=2020 then f.product_code end) as product_count_2021,
        (count(distinct case when f.fiscal_year=2021 then f.product_code end) - count(distinct case when f.fiscal_year=2020 then f.product_code end)) as difference 
        from dim_product as p
left join fact_sales_monthly f on f.product_code = p.product_code
where f.fiscal_year in (2020,2021)
group by p.segment
order by difference desc;


-- 5. Get the products that have the highest and lowest manufacturing costs. 
-- The final output should contain these fields, product_code product manufacturing_cost

select p.product_code, p.product,
		m.manufacturing_cost from dim_product p
left join fact_manufacturing_cost m on m.product_code = p.product_code
where m.manufacturing_cost = (select max(manufacturing_cost) from fact_manufacturing_cost)
union
select p.product_code, p.product,
		m.manufacturing_cost from dim_product p
left join fact_manufacturing_cost m on m.product_code = p.product_code
where m.manufacturing_cost = (select min(manufacturing_cost) from fact_manufacturing_cost)
;


-- 6. Generate a report which contains the top 5 customers who received 
-- an average high pre_invoice_discount_pct for the fiscal year 2021 and in 
-- the Indian market. The final output contains these fields, customer_code customer 
-- average_discount_percentage

with cte1 as
(select a.customer_code, 
			a.customer, 
			a.market,
            b.fiscal_year,
            b.pre_invoice_discount_pct from dim_customer as a
			join fact_pre_invoice_deductions as b on a.customer_code=b.customer_code
),
cte2 as
(		select customer_code, 
			customer, 
			market,
            fiscal_year,
            avg(pre_invoice_discount_pct) as average_discount_percentage from cte1
            where fiscal_year = 2021 and market = 'India'
            group by customer_code, 
			customer, 
			market,
            fiscal_year
)
select customer_code, Customer, round(average_discount_percentage*100, 2) from cte2
order by average_discount_percentage desc
limit 5;



-- 7. Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” 
-- for each month . This analysis helps to get an idea of low and high-performing months and 
-- take strategic decisions. The final report contains these columns: Month Year Gross sales Amount

with cte1 as 
(

			select a.customer_code,
            a.customer,
			b.date,
            b.product_code,
            b.fiscal_year,
            b.sold_quantity
            from dim_customer as a
            join fact_sales_monthly as b
            on a.customer_code = b.customer_code
            where a.customer = 'Atliq Exclusive'
),
cte2 as (
		select a.customer_code,
			   a.customer,
               a.date,
               a.product_code,
               a.fiscal_year,
               a.sold_quantity,
               b.gross_price from cte1 as a
        join fact_gross_price as b
        on a.product_code = b.product_code
        )
        
	select monthname(date) as Month,
			fiscal_year as Year,
            round(sum(sold_quantity*gross_price)/1000000, 2) as gross_sales_amt,
            'Millions' as Unit
            from cte2
            group by monthname(date), fiscal_year;
            


-- 8. In which quarter of 2020, got the maximum total_sold_quantity? The final output contains these 
-- fields sorted by the total_sold_quantity, Quarter total_sold_quantity

select case
			when date between '2019-09-01' and '2019-11-01' then 1
            when date between '2019-12-01' and '2020-02-01' then 2
            when date between '2020-03-01' and '2020-05-01' then 3
            when date between '2020-06-01' and '2020-08-01' then 4
            end    as Quarters,
            
            format(sum(sold_quantity), 0) as total_sold_quantity
            from fact_sales_monthly
            where fiscal_year = 2020
            group by Quarters
            order by total_sold_quantity desc;
            

-- 9. Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage 
-- of contribution? The final output contains these fields, channel gross_sales_mln percentage


with cte1 as 
(
			select a.channel,
            b.product_code,
            b.fiscal_year,
            b.sold_quantity
            from dim_customer as a
            join fact_sales_monthly as b
            on a.customer_code = b.customer_code
            where fiscal_year = 2021
),

cte2 as (
		select a.channel, a.product_code, a.sold_quantity, b.gross_price
        from cte1 as a
        join fact_gross_price as b
        on a.product_code = b.product_code
        ),
        
        cte3 as (
        select channel,
			round(sum(sold_quantity*gross_price)/1000000, 2) as gross_sales_mln
            from cte2
            group by channel)
            
            
	select channel, gross_sales_mln,
			round((gross_sales_mln/total_sales)*100, 2) as pct_contrib
     from cte3,
		(select sum(gross_sales_mln) as total_sales from cte3) as total
        order by gross_sales_mln desc;
        


-- 10. Get the Top 3 products in each division that have a high total_sold_quantity 
-- in the fiscal_year 2021? The final output contains these fields, division product_code codebasics
-- product total_sold_quantity rank_order

with cte1 as 

(
			select a.division,
            a.product_code,
            a.product,
            sum(b.sold_quantity) as total_sold_quantity
            from dim_product as a
            join fact_sales_monthly as b
            on a.product_code = b.product_code
            where b.fiscal_year = 2021
            group by a.division, a.product_code, a.product
),


cte2 as (
	select *, rank() over (partition by division order by total_sold_quantity desc) as rnk
    from cte1

)

select * from cte2
where rnk <= 3;



