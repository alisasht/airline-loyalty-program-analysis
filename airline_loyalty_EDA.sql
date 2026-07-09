-- Exploratory Data Analysis - Airline Loyalty Program Analysis

SELECT * 
FROM airline_loyalty_data_dictionary;

SELECT * 
FROM calendar_staging;

SELECT * 
FROM customer_flight_activity_staging2;
-- table contains data on flights, a row is per month of a year

SELECT * 
FROM customer_loyalty_history_staging;
-- demographics data where each row is unique customer

-- EDA Plan:
-- 1.1. Analyse Customer Demographics - customer_loyalty_history_staging
-- 1.2. Flights EDA - customer_flight_activity_staging2
-- 1.3. Frequent flyer EDA
-- 1.4. 2018 Promotion Stats
-- 1.5. Cancelled Customers Analysis
-- 1.6. Future Improvements - Next Steps: 

-- 1.1. Analyse Customer Demographics - customer_loyalty_history_staging
-- number of customers
SELECT 
	COUNT(DISTINCT loyalty_number) AS total_customers,
	SUM(CASE WHEN cancellation_year IS NULL THEN 1 ELSE 0 END) AS active_customer,
	ROUND(SUM(CASE WHEN cancellation_year IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS pct_active,
	SUM(CASE WHEN cancellation_year IS NOT NULL THEN 1 ELSE 0 END) AS cancelled_customer,
	ROUND(SUM(CASE WHEN cancellation_year IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS pct_cancelled
FROM customer_loyalty_history_staging;
-- 16737 customers in the customer_loyalty_history table
-- 14670 customers are not cancelled, 87.65% of customers
-- 2067 customers have cancelled the loyalty program, 12.35% of customers

-- country breakdown
SELECT DISTINCT country
FROM customer_loyalty_history_staging;
-- all the customers are from Canada

-- customers demographics breakdown by province
SELECT 
	province, 
    COUNT(*) AS total_customers,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM customer_loyalty_history_staging), 2) AS pct_of_total
FROM customer_loyalty_history_staging
GROUP BY province
ORDER BY total_customers DESC;
-- Provinces of Ontario (32.29%) and British Columbia (26.34%) together make up over half of the customer base, followed by Quebec (19.72%)
-- lowest number of customers are from Prince Edward Island (0.39%) and Yukon (0.66%)

-- customers demographics breakdown by city
SELECT 
	city, 
	COUNT(*) AS total_customers,
	ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM customer_loyalty_history_staging), 2) AS pct_of_total
FROM customer_loyalty_history_staging
GROUP BY city
ORDER BY total_customers DESC;
-- 48% of customers reside in Toronto (20.02%), Vancouver (15.43%) and Montreal (12.30%) which corresponds to the provinces breakdown

-- customers demographics breakdown by gender
SELECT 
	gender, 
	COUNT(*) AS total_customers,
	ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM customer_loyalty_history_staging), 2) AS pct_of_total
FROM customer_loyalty_history_staging
GROUP BY gender
ORDER BY total_customers DESC;
-- 50.25% of the customers are Female, and 49.75% are Male

-- customers demographics breakdown by education 
SELECT 
	education, 
	COUNT(*) AS total_customers,
	ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM customer_loyalty_history_staging), 2) AS pct_of_total
FROM customer_loyalty_history_staging
GROUP BY education
ORDER BY total_customers DESC;
-- 70% of customers have a Bachelor degree and higher

-- customers demographics breakdown by salary (excluding the 25% with NULL values) 
SELECT
	MIN(salary), 
    MAX(salary),
    ROUND(AVG(salary), 2)
FROM customer_loyalty_history_staging
WHERE salary IS NOT NULL;
-- for those customers where salary data is available, salary ranges from $9,081 to $407,228, with the average salary of $79,359

-- customers demographics breakdown by marital_status
SELECT 
	marital_status, 
	COUNT(*) AS total_customers,
	ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM customer_loyalty_history_staging), 2) AS pct_of_total
FROM customer_loyalty_history_staging
GROUP BY marital_status
ORDER BY total_customers DESC;
-- 58.16% of customers are married. 26.79% are single and 15.04% are divorced

-- customers demographics breakdown by loyalty card
SELECT 
	loyalty_card, 
	COUNT(*) AS total_customers,
	ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM customer_loyalty_history_staging), 2) AS pct_of_total, 
    ROUND(AVG(clv),2) AS avg_clv
FROM customer_loyalty_history_staging
GROUP BY loyalty_card
ORDER BY total_customers DESC;
-- 45.63% of customers hold the Star loyalty card, 33.88% hold the Nova card and 20.49% hold the Aurora. 
-- Aurora loyalty card customers have the highest average clv of $10,673, approx. 58% higher compared to Star customers ($6,742)
-- whilst there is no tier explanation supplied, Aurora must be the top tier, given the spending, followed by Nova, and Star is lowest

-- clv - Customer lifetime value - total invoice value for all flights ever booked by member
SELECT 
	MIN(clv) AS min_clv,
    MAX(clv) AS max_clv,
    ROUND(AVG(clv), 2) AS avg_clv,
    ROUND(SUM(clv), 2) AS total_clv 
FROM customer_loyalty_history_staging;
-- across all years of enrollment:
-- min Customer lifetime value is $1,898
-- max Customer lifetime value is $83,325 - who are the big spenders? assuming they are the top tier frequent travellers?
-- average Customer lifetime value is $7,989
-- total Customer lifetime value is $133,710,161.32

-- clv by province
SELECT 
	province,
	ROUND(SUM(clv), 2) AS total_clv
FROM customer_loyalty_history_staging
GROUP BY province
ORDER BY total_clv DESC;
-- Ontario, British Columbia and Quebec are the highest total Customer lifetime value provinces
-- this is consistent with the customers demographics breakdown by province

-- cumulative total CLV by enrollment year
WITH rolling_total AS 
(
SELECT enrollment_year, ROUND(SUM(clv), 2) AS total_clv
FROM customer_loyalty_history_staging
GROUP BY enrollment_year
ORDER BY enrollment_year ASC
)
SELECT 
	enrollment_year, 
    total_clv, 
    ROUND(SUM(total_clv) OVER(ORDER BY enrollment_year), 2) AS cumulative_clv
FROM rolling_total;
-- customers who enrolled in 2012 have the lowest Customer lifetime value
-- customers who enrolled in 2013-2017 have pretty much the same Customer lifetime value, varying from $18,6m to $19,7m
-- customers who enrolled in 2018 have the highest Customer lifetime value - $24,1m
-- reflects both cohort size and value; see average CLV below for per-customer comparison.

-- enrollment type, how many enrolled 
SELECT 
	enrollment_type, 
	COUNT(*) AS total_customers,
	ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM customer_loyalty_history_staging), 2) AS pct_of_total
FROM customer_loyalty_history_staging
GROUP BY enrollment_type
ORDER BY total_customers DESC;
-- 94.2% of customers enrolled via the Standard enrollment method and 5.80% (971) enrolled via the 2018 Promotion

-- history of enrollment, with growth rate
SELECT 
    enrollment_year,
    COUNT(*) AS total_new_customers,
    LAG(COUNT(*)) OVER (ORDER BY enrollment_year) AS previous_year_customers, -- grabs previous year's value
    ROUND(
        (COUNT(*) - LAG(COUNT(*)) OVER (ORDER BY enrollment_year)) * 100.0 
        / LAG(COUNT(*)) OVER (ORDER BY enrollment_year)
    , 2) AS growth_rate_pct
FROM customer_loyalty_history_staging
GROUP BY enrollment_year
ORDER BY enrollment_year;
-- the growth rate was the largest for 2013 (42.17%), then it was negative, then went up a bit and was 21.03% in 2018
-- is the 2018 growth related to the 2018 promotion? could be, that would explain the extra 21%

-- 1.2. Flights EDA - customer_flight_activity_staging2
-- what period does the table cover
SELECT MIN(`year`), MAX(`year`)
FROM customer_flight_activity_staging2;
-- the flight activity table contains 2017 and 2018 data only

-- top 10 months in terms of Sum of Flights Booked (all tickets purchased in the period)
-- these are 'booked', not necessarily 'taken/travelled' 
SELECT 
	`year`,
	`month`, 
    SUM(total_flights) AS total_flights_booked
FROM customer_flight_activity_staging2
GROUP BY `year`, `month`
ORDER BY SUM(total_flights) DESC
LIMIT 10;
-- summer months and December are in the list indicating increased summer and Christmas holidays activity which is expected

-- flight activity breakdown for 2017, by month
SELECT 
	`month`,
    SUM(total_flights)
FROM customer_flight_activity_staging2
WHERE `year` = 2017
GROUP BY `month`
ORDER BY `month`;
-- lowest number of total_flights is for January, highest is for July, 100% increase from January

-- flight activity breakdown for 2018, by month
SELECT 
	`month`,
    SUM(total_flights)
FROM customer_flight_activity_staging2
WHERE `year` = 2018
GROUP BY `month`
ORDER BY `month`;
-- lowest number of total_flights is for January, consistent with previous years
-- highest is for July, same pattern as for 2017, but now a 185% increase from January
-- can add a growth rate here, would be good

-- check distribution of total distance per year
WITH counts AS (
	SELECT
	(SELECT SUM(distance) FROM customer_flight_activity_staging2 WHERE year = 2017) AS total_distance_2017,
	(SELECT SUM(distance) FROM customer_flight_activity_staging2 WHERE year = 2018) AS total_distance_2018
)
SELECT 
	total_distance_2017, 
    total_distance_2018,
    ROUND( (total_distance_2018 - total_distance_2017) *100.0  / total_distance_2017, 2) AS year_over_year_growth_rate
FROM counts;
-- there has been a 28% increase in total distance travelled in 2018 compared to 2017

-- total_lifetime_distance travelled by year
SELECT 
    loyalty_number,
    SUM(CASE WHEN `year` = 2017 THEN distance ELSE 0 END) AS distance_2017,
    SUM(CASE WHEN `year` = 2018 THEN distance ELSE 0 END) AS distance_2018,
	SUM(distance) AS total_lifetime_distance
FROM customer_flight_activity_staging2
GROUP BY loyalty_number
ORDER BY total_lifetime_distance DESC
LIMIT 10;
-- interestingly enough, 9 out of the 10 didn't travel at all in 2017
-- would it be because they enrolled in 2018?

-- check when the top 10 by longest distance enroll
WITH top_10_distance AS 
(
	SELECT 
		loyalty_number,
		SUM(CASE WHEN `year` = 2017 THEN distance ELSE 0 END) AS distance_2017,
		SUM(CASE WHEN `year` = 2018 THEN distance ELSE 0 END) AS distance_2018,
		SUM(distance) AS total_lifetime_distance
	FROM customer_flight_activity_staging2
	GROUP BY loyalty_number
	ORDER BY total_lifetime_distance DESC
	LIMIT 10
) 
SELECT
	distance.loyalty_number, 
    distance.distance_2017, 
    distance.distance_2018, 
    distance.total_lifetime_distance,
    loyalty.enrollment_year, 
    loyalty.enrollment_type
FROM top_10_distance AS distance
LEFT JOIN customer_loyalty_history_staging AS loyalty
ON distance.loyalty_number = loyalty.loyalty_number
ORDER BY total_lifetime_distance DESC;
-- out of the top 10 customers by distance travelled, all of those who didn't travel in 2017, didn't travel because they enrolled in 2018
-- all the enrolled in 2018 enrolled via the 2018 Promotion
-- this small sample suggests the 2018 Promotion attracted some of the program's highest-distance travellers

-- points_redeemed vs dollar_cost_points_redeemed
SELECT * 
FROM customer_flight_activity_staging2
WHERE points_redeemed !=0 AND dollar_cost_points_redeemed = 0;
-- points_redeemed and dollar_cost_points_redeemed go together, there are no instances when one is 0 and another one has value

-- 1.3. Frequent flyer EDA
-- top 10 most travelled loyalty numbers by total_flights
SELECT loyalty_number,
	SUM(total_flights) AS total_lifetime_flights, 
	SUM(distance) AS total_lifetime_distance
FROM customer_flight_activity_staging2
GROUP BY loyalty_number
ORDER BY total_lifetime_flights DESC
LIMIT 10;

-- top 10 most travelled loyalty numbers by distance
SELECT loyalty_number, 
	SUM(total_flights) AS total_lifetime_flights,
	SUM(distance) AS total_lifetime_distance
FROM customer_flight_activity_staging2
GROUP BY loyalty_number
ORDER BY total_lifetime_distance DESC
LIMIT 10;
-- the highest total_lifetime_distance travelled does not mean the highest total_lifetime_flights, the two lists are slightly different
-- frequent short-haul flying and high-distance flying are largely different customer behaviors

-- top 10 most travelled loyalty numbers by total_lifetime_flights with demographic details
WITH top_10_flyers AS(
	SELECT loyalty_number, 
		SUM(total_flights) AS total_lifetime_flights,
		SUM(distance) AS total_lifetime_distance
	FROM customer_flight_activity_staging2
	GROUP BY loyalty_number
	ORDER BY total_lifetime_flights DESC
	LIMIT 10
)
SELECT
	t10f.loyalty_number, 
    t10f.total_lifetime_flights, 
    t10f.total_lifetime_distance, 
    loyalty.province, 
    loyalty.gender, 
    loyalty.education, 
    loyalty.loyalty_card, 
    loyalty.clv, 
    loyalty.enrollment_type
FROM top_10_flyers AS t10f
JOIN customer_loyalty_history_staging AS loyalty
	ON t10f.loyalty_number = loyalty.loyalty_number
ORDER BY t10f.total_lifetime_flights DESC;
-- 7 out of 10 top customers by total flights booked have actually enrolled via the 2018 Promotion, which again confirms its success
-- 9 are from the three top provinces we've seen before as well performing and 1 from Alberta
-- there is only one customer on this list with the Aurora status, 60% are the Nova loyalty card type
-- 60% are female, we have seen this before 
-- clv ranges quite significantly, from $2,746 to $13,990 

-- top 10 points accumulated list of loyalty numbers. 
SELECT loyalty_number, 
	SUM(points_accumulated) AS total_lifetime_points_accumulated,
    SUM(distance) AS total_lifetime_distance
FROM customer_flight_activity_staging2
GROUP BY loyalty_number
ORDER BY total_lifetime_points_accumulated DESC
LIMIT 10;
-- loyalty_number 689839 has 268,287 total_lifetime_points_accumulated, and they have travelled 178,858 total_lifetime_distance

-- JOIN in the demographics data to see if they have anything in common => what's the top points traveller profile like, is there one 
WITH top_10_points AS 
(
	SELECT loyalty_number, 
		SUM(points_accumulated) AS total_lifetime_points_accumulated,
		SUM(distance) AS total_lifetime_distance
	FROM customer_flight_activity_staging2
	GROUP BY loyalty_number
	ORDER BY total_lifetime_points_accumulated DESC
	LIMIT 10
)
SELECT * 
FROM top_10_points AS points
LEFT JOIN customer_loyalty_history_staging AS loyalty
ON points.loyalty_number = loyalty.loyalty_number
ORDER BY points.total_lifetime_points_accumulated DESC;
-- all of the top 10 customers by points_accumulated are 2018 Promotion customers, all enrolled in 2018
-- they are from a mix of cities, not all from major capital cities
-- 50% are male and 50% female
-- the dominant education level is Bachelor (5 out of 10), and 7 out of 10 are Married 
-- only 2 hold the Aurora loyalty card and their clvs are the highest at $12516.92 and $17793.61, whilst everyone else ranges from $3,099 to $8,460
-- one of the customers has already cancelled their loyalty program participation

-- top 10 clv
SELECT
	loyalty_number, 
    province,
    city,
    gender,
    loyalty_card,
    enrollment_type,
	clv
FROM customer_loyalty_history_staging
ORDER BY clv DESC
LIMIT 10;
-- different breakdown of province to what we have seen in the top 10 before. Manitoba, New Brunswick, Nova Scotia and Saskatchewan have not appeared on the list before
-- 50/50 female to male ratio
-- 4 Aurora loyalty cards as opposed to 1 for the 'top 10 by total flights' breakdown. 
-- 2 customers have joined through the 2018 Promotion

-- 1.4. 2018 Promotion Stats
-- when did the 2018 Promotion run?
SELECT
	enrollment_month, 
    COUNT(*) AS total_enrolled
FROM customer_loyalty_history_staging
WHERE enrollment_type = '2018 Promotion'
GROUP BY enrollment_month
ORDER BY enrollment_month;
-- The 2018 Promotion ran from February to April 2018, with signups growing month to month: 295 in February, 330 in March, and 346 in April.

-- same with the growth rate
SELECT 
	enrollment_month, 
    COUNT(*) AS total_enrolled,	
    LAG(COUNT(*)) OVER (ORDER BY enrollment_month) AS previous_month_enrolled, -- grabs previous month's value
    ROUND(
        (COUNT(*) - LAG(COUNT(*)) OVER (ORDER BY enrollment_month)) * 100.0 
        / LAG(COUNT(*)) OVER (ORDER BY enrollment_month)
    , 2) AS growth_rate_pct
FROM customer_loyalty_history_staging
WHERE enrollment_type = '2018 Promotion'
GROUP BY enrollment_month
ORDER BY enrollment_month;
-- The 2018 Promotion ran from February to April 2018, with signups growing month to month: 295 in February, 330 in March, and 346 in April.

-- for 2018 promotion, what's the ratio of those who didn't travel at all 
WITH promotion_2018 AS
(
	SELECT *
	FROM customer_loyalty_history_staging
	WHERE enrollment_type = '2018 Promotion'
), travelled AS 
(
	SELECT 
		flights.loyalty_number,
		SUM(flights.total_flights) AS total_lifetime_flights
	FROM promotion_2018 as promotion
	LEFT JOIN customer_flight_activity_staging2 AS flights
	ON promotion.loyalty_number = flights.loyalty_number
	GROUP BY promotion.loyalty_number
)
SELECT 
	COUNT(*) AS total_promo_customers,
	SUM(CASE WHEN total_lifetime_flights IS NULL OR total_lifetime_flights = 0 THEN 1 ELSE 0 END) AS didnt_travel,
	ROUND(SUM(CASE WHEN total_lifetime_flights IS NULL OR total_lifetime_flights = 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS pct_didnt_travel
FROM travelled;
-- out of the 971 who signed up with the 2018 Promotion only 47, or 4.84%, did not travel at all, which is a smaller percentage and again shows the promotion was successful

-- the 2018 Promotion customers, and what's their travel status like for distance travelled and total flights
WITH customer_totals AS (
    SELECT 
        loyalty.loyalty_number,
        loyalty.enrollment_type,
        loyalty.clv,
        COALESCE(SUM(flights.total_flights), 0) AS total_flights_per_customer,
        COALESCE(SUM(flights.distance), 0) AS total_distance_per_customer,
		COALESCE(SUM(flights.points_accumulated), 0) AS total_points_per_customer
    FROM customer_loyalty_history_staging AS loyalty
    LEFT JOIN customer_flight_activity_staging2 AS flights
        ON loyalty.loyalty_number = flights.loyalty_number
    GROUP BY loyalty.loyalty_number, loyalty.enrollment_type, loyalty.clv
)
SELECT
    CASE WHEN enrollment_type = '2018 Promotion' THEN '2018 Promotion' ELSE 'Standard' END AS enrollment_type,
    SUM(total_flights_per_customer) AS total_flights_booked,
    ROUND(AVG(total_flights_per_customer), 2) AS avg_flights_per_customer,
    ROUND(AVG(total_distance_per_customer), 2) AS avg_distance_per_customer,
	ROUND(AVG(total_points_per_customer), 2) AS avg_points_per_customer,
    ROUND(AVG(clv), 2) AS avg_clv
FROM customer_totals
GROUP BY enrollment_type;
-- those enrolled through the 2018 Promotion have booked 44877 flights, which is 90% less than the Standard group customers booked to date
-- the 90% less flights correlates to the size of the group and and time they have been enrolled for
-- the 2018 Promotion group have booked on average 57% more flights
-- the 2018 Promotion group have travelled on average 57% farther 
-- the 2018 Promotion group have accumulated on average 136% more points than the Standard group
-- clv for both groups is pretty much the same but we know the 2018 Promotion customers have joined in 2018 so had less time to travel and accumulate clv
-- based on this, the promotion can be considered successful in terms of travel activity but too early to tell in terms of dollar value

-- can we predict clv for 2018 Promotion customers => calculate average CLV per year of membership
SELECT
    CASE WHEN enrollment_type = '2018 Promotion' THEN '2018 Promotion' ELSE 'Standard' END AS enrollment_type,
    ROUND(AVG(clv / (2018 - enrollment_year + 1)), 2) AS avg_clv_per_year_of_membership
FROM customer_loyalty_history_staging
GROUP BY enrollment_type;
-- the 2018 Promotion cohort shows a notably stronger first-year value signal alongside higher travel activity, 
-- but this is one year of data for a single cohort - whether this pace of value generation continues, 
-- accelerates, or fades as the cohort ages cannot be determined from this dataset alone
-- 2018 Promotion customers generate 2.74x more CLV per year of membership ($8,047) than Standard customers ($2,932)

-- 1.5. Cancelled Customers Analysis
-- cancelled stats
SELECT
    SUM(CASE WHEN cancellation_year IS NOT NULL AND enrollment_type != '2018 Promotion' THEN 1 ELSE 0 END) AS total_standard_cancelled,
    ROUND(SUM(CASE WHEN cancellation_year IS NOT NULL AND enrollment_type != '2018 Promotion' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS pct_total_standard_cancelled,
    SUM(CASE WHEN cancellation_year IS NOT NULL AND enrollment_type = '2018 Promotion' THEN 1 ELSE 0 END) AS total_promo_cancelled,
    ROUND(SUM(CASE WHEN cancellation_year IS NOT NULL AND enrollment_type = '2018 Promotion' THEN 1 ELSE 0 END) * 100.0 / 
          (SELECT COUNT(*) FROM customer_loyalty_history_staging WHERE enrollment_type = '2018 Promotion'), 2) AS pct_promo_cancelled
FROM customer_loyalty_history_staging;
-- promo cancellation rate is 11.84 which is just a slightly higher than for standard enrollment type

-- average of how long customers are signed up for the loyalty program
SELECT 
    ROUND(AVG(
        ((COALESCE(cancellation_year, 2018) - enrollment_year) * 12 +
        (COALESCE(cancellation_month, 12) - enrollment_month))
    ) / 12, 2) AS avg_membership_years_all,
    ROUND(AVG(
        CASE WHEN cancellation_year IS NOT NULL THEN
            ((cancellation_year - enrollment_year) * 12 +
            (cancellation_month - enrollment_month))
        END
    ) / 12, 2) AS avg_membership_years_cancelled,
    ROUND(AVG(
        CASE WHEN cancellation_year IS NULL THEN
            ((2018 - enrollment_year) * 12 +
            (12 - enrollment_month))
        END
    ) / 12, 2) AS avg_membership_years_active
FROM customer_loyalty_history_staging;
-- Average membership duration across all customers: 2.95 years
-- Average membership duration for cancelled customers: 1.32 years
-- Average membership duration for active customers: 3.18 years

-- average flight activity in the final 3 months before cancellation, for cancelled customers
WITH cancelled_last_months AS (
    SELECT 
        loyalty.loyalty_number,
        loyalty.cancellation_year,
        loyalty.cancellation_month,
        flights.`year`,
        flights.`month`,
        flights.total_flights,
        flights.distance
    FROM customer_loyalty_history_staging AS loyalty
    JOIN customer_flight_activity_staging2 AS flights
        ON loyalty.loyalty_number = flights.loyalty_number
    WHERE loyalty.cancellation_year IS NOT NULL
    AND (
        (flights.`year` = loyalty.cancellation_year AND flights.`month` <= loyalty.cancellation_month)
        OR (flights.`year` = loyalty.cancellation_year - 1 AND flights.`month` > loyalty.cancellation_month)
    )
)
SELECT 
    ROUND(AVG(total_flights), 2) AS avg_flights_before_cancellation,
    ROUND(AVG(distance), 2) AS avg_distance_before_cancellation
FROM cancelled_last_months;
-- the cancelled customers did overall travel in the months leading up to the cancellation, there wasn't any inactivity

-- cancelled vs active (aggregated to customer level first for fair comparison)
WITH customer_activity AS (
    SELECT 
        loyalty.loyalty_number,
        loyalty.cancellation_year,
        COALESCE(SUM(flights.total_flights), 0) AS total_lifetime_flights,
        COALESCE(SUM(flights.distance), 0) AS total_lifetime_distance
    FROM customer_loyalty_history_staging AS loyalty
    LEFT JOIN customer_flight_activity_staging2 AS flights
        ON loyalty.loyalty_number = flights.loyalty_number
    GROUP BY loyalty.loyalty_number, loyalty.cancellation_year
)
SELECT
    CASE WHEN cancellation_year IS NOT NULL THEN 'Cancelled' ELSE 'Active' END AS customer_status,
    ROUND(AVG(total_lifetime_flights), 2) AS avg_lifetime_flights,
    ROUND(AVG(total_lifetime_distance), 2) AS avg_lifetime_distance
FROM customer_activity
GROUP BY customer_status;
-- cancelled customers averaged only 10 lifetime flights vs 33 for active customers, 
-- suggesting members who don't reach meaningful engagement thresholds within their first year are at significantly higher cancellation risk 
-- early intervention for low-activity members could be an effective retention strategy

-- cancelled customers loyalty card type
SELECT 
    CASE WHEN cancellation_year IS NOT NULL THEN 'Cancelled' ELSE 'Active' END AS customer_status,
    loyalty_card,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY CASE WHEN cancellation_year IS NOT NULL THEN 'Cancelled' ELSE 'Active' END), 2) AS pct_within_status
FROM customer_loyalty_history_staging
GROUP BY customer_status, loyalty_card
ORDER BY customer_status, customer_count DESC;
-- percentage of cancelled vs active customers for loyalty tiers is also relatively the same, again showing no clear pattern of cancellation

-- cancellation rate by province (not raw count, to control for differing customer base sizes)
SELECT 
    province,
    COUNT(*) AS total_customers,
    SUM(CASE WHEN cancellation_year IS NOT NULL THEN 1 ELSE 0 END) AS cancelled_customers,
    ROUND(SUM(CASE WHEN cancellation_year IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS cancellation_rate_pct
FROM customer_loyalty_history_staging
GROUP BY province
ORDER BY cancellation_rate_pct DESC;
-- cancellation rate is broadly consistent across provinces (~11-13%) for all but the smallest customer bases, 
-- where limited sample size likely explains the wider apparent spread.
-- Among the provinces with enough customers to trust the rate, there's essentially no real variation

-- cancellation rate by enrollment year 
SELECT 
    enrollment_year,
    COUNT(*) AS total_customers,
    SUM(CASE WHEN cancellation_year IS NOT NULL THEN 1 ELSE 0 END) AS cancelled_customers,
    ROUND(SUM(CASE WHEN cancellation_year IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS cancellation_rate_pct
FROM customer_loyalty_history_staging
GROUP BY enrollment_year
ORDER BY enrollment_year;
-- 2012 shows cancellations is 0 because there is no data prior to 2013 - due to no cancellations or just data quality,
-- we should not make an assumption that this is 0% due to 0% cancellations rate
-- 2013-2017 cancellation rates remain broadly stable at 15-17%, suggesting retention has not meaningfully worsened over time
-- 2018 cancellation rate at 5% - too early to assess, lower exposure window, they have not been members for long enough

-- cancellation rate vs salary 
SELECT 
    MIN(salary) AS min_salary,
    MAX(salary) AS max_salary,
    ROUND(AVG(CASE WHEN cancellation_year IS NOT NULL THEN salary END), 2) AS avg_salary_cancelled,
    ROUND(AVG(CASE WHEN cancellation_year IS NULL THEN salary END), 2) AS avg_salary_active
FROM customer_loyalty_history_staging;
-- same average salary for cancelled and active members
-- there appears so far no real pattern for predicting a cancellation, besides some decrease in activity

-- 1.6. Future Improvements - Next Steps: 
-- Explore points redemption patterns - are there any
-- Explore total_flights more for yearly breakdowns with growth rate