-- Data Cleaning - Airline Loyalty Program Analysis

SELECT * 
FROM airline_loyalty_data_dictionary;

SELECT *
FROM calendar;

SELECT *
FROM customer_flight_activity;

-- Data Clean Plan:
-- 1. Remove Duplicates if Any 
-- 2. Standardise the Data
-- 3. Null Values or Blank Values
-- 4. Remove Any Columns or Rows

SELECT *
FROM customer_loyalty_history;
-- all three tables appear to have column names with spaces, need to amend these to _ before proceeding further to make this easier
-- need to create the staging versions of the original table to have something to revert to in case of an issue
-- create new table

-- create staging first table
CREATE TABLE calendar_staging
LIKE calendar;

-- copy the original table into the new one
INSERT calendar_staging
SELECT *
FROM calendar;

-- create staging second table
CREATE TABLE customer_flight_activity_staging
LIKE customer_flight_activity;

-- make sure the column structure looks good
SELECT *
FROM customer_flight_activity_staging;

-- copy the original table into the new one
INSERT customer_flight_activity_staging
SELECT *
FROM customer_flight_activity;

-- create staging third table
CREATE TABLE customer_loyalty_history_staging
LIKE customer_loyalty_history;

-- make sure the column structure looks good
SELECT * 
FROM customer_loyalty_history_staging; 

-- copy the original table into the new one
INSERT customer_loyalty_history_staging
SELECT * 
FROM customer_loyalty_history; 
  

-- update column names in all three tables using stored procedures, cursors, loops, and dynamic SQL
DELIMITER $$

CREATE PROCEDURE RenameAllColumnsWithSpaces()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE alter_cmd VARCHAR(500);
    
    -- Cursor to gather columns with spaces from all 3 of your specific tables
    DECLARE col_cursor CURSOR FOR -- step through a multi-row result one row at a time
        SELECT CONCAT(
            'ALTER TABLE `', TABLE_SCHEMA, '`.`', TABLE_NAME, 
            '` RENAME COLUMN `', COLUMN_NAME, 
            '` TO `', LOWER(REPLACE(COLUMN_NAME, ' ', '_')), '`;'
        )
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_NAME IN ('calendar_staging', 'customer_flight_activity_staging', 'customer_loyalty_history_staging') 
          AND (COLUMN_NAME LIKE '% %' OR COLUMN_NAME REGEXP '[A-Z]');
          
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE; -- stop when you run out of rows

    OPEN col_cursor; -- The loop itself, start the cursor

    read_loop: LOOP
        FETCH col_cursor INTO alter_cmd;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        -- Dynamically executes the ALTER statement behind the scenes - dynamic SQL 
        SET @sql = alter_cmd;
        PREPARE stmt FROM @sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
        -- your cursor produced text that looks like SQL, but the database doesn't automatically 
        -- treat text as commands — you have to explicitly tell it "treat this string as a real statement and run it.
    END LOOP;

    CLOSE col_cursor;
END$$

DELIMITER ;

-- 1. Execute this line to trigger the automatic update across all tables -- call the function
CALL RenameAllColumnsWithSpaces();

-- 2. Execute this line to clean up and remove the procedure from your database
DROP PROCEDURE RenameAllColumnsWithSpaces;

-- check result
SELECT * 
FROM calendar_staging;

SELECT * 
FROM customer_flight_activity_staging;

SELECT * 
FROM customer_loyalty_history_staging;

-- explore and define table contents
SELECT COUNT(start_of_year)
FROM calendar_staging;
-- calendar_staging has four columns (date, start_of_year, start_of_quarter, start_of_month) and 2557 rows

SELECT COUNT(loyalty_number)
FROM customer_flight_activity_staging;
-- customer_flight_activity_staging has eight columns (loyalty_number, year, month, total_flights, distance, points_accumulated, 
-- points_redeemed, dollar_cost_points_redeemed) and 392,936 rows before cleaning

SELECT *
FROM customer_loyalty_history_staging;
-- lots of columns, need to automate count

-- find out column count in customer_loyalty_history_staging
SELECT COUNT(*) AS column_count
FROM INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'customer_loyalty_history_staging';

SELECT COUNT(loyalty_number)
FROM customer_loyalty_history_staging;
-- customer_loyalty_history_staging has 16 columns (loyalty_number, country, province, city, postal_code, gender, education, salary, 
-- marital_status, loyalty_card, clv, enrollment_type, enrollment_year, enrollment_month, cancellation_year, 
-- cancellation_month) and 16,737 before cleaning

-- 1. Remove Duplicates if any 
-- 1.1. duplicates for calendar_staging
SELECT * 
FROM calendar_staging;
-- no row number in the document, so it's not easy to find duplicates

SELECT *,
ROW_NUMBER() OVER(PARTITION BY `date`, start_of_year, start_of_quarter, start_of_month) AS row_num
FROM calendar_staging;

-- identify duplication
WITH duplicate_cte AS
(
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY `date`, start_of_year, start_of_quarter, start_of_month) AS row_num
FROM calendar_staging
)
SELECT * 
FROM duplicate_cte
WHERE row_num > 1;
-- no duplicates in the calendar_staging table

-- 1.2. duplicates for customer_flight_activity_staging
SELECT * 
FROM customer_flight_activity_staging;
-- no row number in the document, so it's not easy to find duplicates
-- the table does contain loyalty_number column but values are not unique, this cannot be used

SELECT *,
ROW_NUMBER() OVER(PARTITION BY loyalty_number, `year`, `month`, total_flights, distance, 
points_accumulated, points_redeemed, dollar_cost_points_redeemed) AS row_num
FROM customer_flight_activity_staging;

-- identify duplication
WITH duplicate_cte AS
(
SELECT *,
ROW_NUMBER() OVER(PARTITION BY loyalty_number, `year`, `month`, total_flights, distance, 
points_accumulated, points_redeemed, dollar_cost_points_redeemed) AS row_num
FROM customer_flight_activity_staging
)
SELECT * 
FROM duplicate_cte
WHERE row_num > 1;
-- quite a few results are identified

-- spot check the duplicates if they were flagged as duplicates correctly
SELECT *
FROM customer_flight_activity_staging
WHERE loyalty_number = 546259;
-- this looks like clean duplication

SELECT * 
FROM customer_flight_activity_staging
WHERE loyalty_number = 460272;
-- this looks like a mix of clean duplicates and rows where year and month are the same but total_flights, 
-- distance, points_accumulated, points_redeemed, and dollar_cost_points_redeemed are different. these should be 
-- aggregated but they are not 

-- identify the count
WITH duplicates_count_cte AS
(
SELECT loyalty_number, `year`, `month`, COUNT(*) AS row_count
FROM customer_flight_activity_staging
GROUP BY loyalty_number, `year`, `month`
HAVING COUNT(*) > 1
)
SELECT SUM(row_count) AS total_rows_in_groups,
       COUNT(*) AS number_of_groups,
       MAX(row_count) AS max_rows_in_one_group
FROM duplicates_count_cte;
-- total_rows_in_groups: 7718
-- number_of_groups: 3847 
-- max_rows_in_one_group: 3

-- create aggregation and spot check
SELECT loyalty_number, `year`, `month`,
       SUM(total_flights) AS total_flights,
       SUM(distance) AS distance,
       SUM(points_accumulated) AS points_accumulated,
       SUM(points_redeemed) AS points_redeemed,
       SUM(dollar_cost_points_redeemed) AS dollar_cost_points_redeemed
FROM customer_flight_activity_staging
GROUP BY loyalty_number, `year`, `month`;

-- check if the count makes sense
WITH dups_count_cte AS
(
SELECT loyalty_number, `year`, `month`,
       SUM(total_flights) AS total_flights,
       SUM(distance) AS distance,
       SUM(points_accumulated) AS points_accumulated,
       SUM(points_redeemed) AS points_redeemed,
       SUM(dollar_cost_points_redeemed) AS dollar_cost_points_redeemed
FROM customer_flight_activity_staging
GROUP BY loyalty_number, `year`, `month`
)
SELECT COUNT(*)
FROM dups_count_cte;
-- returns 389065 rows. 7718 rows were identified by the previous query, with 3847 groups.
-- total was 392,936 rows before cleaning. this looks correct 

-- need to identify the duplicate row numbers and delete them, do not delete everything 
-- create an empty table
CREATE TABLE `customer_flight_activity_staging2` (
  `loyalty_number` int DEFAULT NULL,
  `year` int DEFAULT NULL,
  `month` int DEFAULT NULL,
  `total_flights` int DEFAULT NULL,
  `distance` int DEFAULT NULL,
  `points_accumulated` int DEFAULT NULL,
  `points_redeemed` int DEFAULT NULL,
  `dollar_cost_points_redeemed` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

SELECT *
FROM customer_flight_activity_staging2;

-- insert aggregated data 
INSERT INTO customer_flight_activity_staging2
SELECT loyalty_number, `year`, `month`, 
		SUM(total_flights), 
        SUM(distance), 
        SUM(points_accumulated), 
        SUM(points_redeemed), 
        SUM(dollar_cost_points_redeemed)
FROM customer_flight_activity_staging
GROUP BY loyalty_number, `year`, `month`;

-- check count
SELECT COUNT(loyalty_number)
FROM customer_flight_activity_staging2;
-- 389,065 as expected. 

-- check for duplicates just in case
WITH duplicate_cte AS
(
SELECT *,
ROW_NUMBER() OVER(PARTITION BY loyalty_number, `year`, `month`, total_flights, distance, 
points_accumulated, points_redeemed, dollar_cost_points_redeemed) AS row_num
FROM customer_flight_activity_staging2
)
SELECT * 
FROM duplicate_cte
WHERE row_num > 1;
-- table is empty so no more duplicates

-- 1.3. identify duplication in table customer_loyalty_history_staging
SELECT * 
FROM customer_loyalty_history_staging;

WITH duplicate_cte AS
(
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY loyalty_number, country, province, city, postal_code, gender, education, salary, 
marital_status, loyalty_card, clv, enrollment_type, enrollment_year, enrollment_month, 
cancellation_year, cancellation_month) AS row_num
FROM customer_loyalty_history_staging
)
SELECT * 
FROM duplicate_cte
WHERE row_num > 1;
-- no duplicates in the customer_loyalty_history_staging

-- checking loyalty_number
SELECT COUNT(loyalty_number)
FROM customer_loyalty_history_staging;
-- 16737 results

SELECT COUNT( DISTINCT loyalty_number)
FROM customer_loyalty_history_staging;
-- there are 16737 unique loyalty numbers which matches the total rows so no line duplication we saw with the previous table

-- 2. Standardise the Data
-- 2.1. Standardise the Data in table 1, calendar_staging

SELECT * 
FROM calendar_staging;
-- all four columns are date values, 
    
DESCRIBE calendar_staging;
-- all dates are of 'text' type, need to convert to 'date' type

-- update data types
ALTER TABLE calendar_staging
MODIFY COLUMN `date` DATE,
MODIFY COLUMN start_of_year DATE,
MODIFY COLUMN start_of_quarter DATE,
MODIFY COLUMN start_of_month DATE;
-- 2557 row(s) affected Records: 2557  Duplicates: 0  Warnings: 0

DESCRIBE calendar_staging;
-- type is now date

-- 2.2. Standardise the Data in table 2, customer_flight_activity_staging2
SELECT * 
FROM customer_flight_activity_staging2;

-- check column types
DESCRIBE customer_flight_activity_staging2;
-- all columns are INTs, no data to standardise

-- check month values for sanity check
SELECT DISTINCT `month` 
FROM customer_flight_activity_staging2;
-- listed values are 1 to 12, no issues

-- check values for sanity check
SELECT MIN(loyalty_number), MAX(loyalty_number),
		MIN(`year`), MAX(`year`),
		MIN(total_flights), MAX(total_flights),
        MIN(distance), MAX(distance), 
        MIN(points_accumulated), MAX(points_accumulated), 
        MIN(points_redeemed), MAX(points_redeemed), 
        MIN(dollar_cost_points_redeemed), MAX(dollar_cost_points_redeemed) 
FROM customer_flight_activity_staging2; 
-- loyalty_number ranges from '100018' to '999986' which looks fine, years '2017' to '2018'
-- total_flights range from '0' to '32' which is possible, distance from '0' to '67284' which is worth checking
-- points_accumulated ranges from '0' to  '100926' which is also worth looking at
-- points redeemed '0' to '996' and dollar_cost_points_redeemed from '0' to '179' also looks fine

-- check referential integrity: are there flight records for loyalty numbers not in the history table?
SELECT COUNT(DISTINCT flights.loyalty_number)
FROM customer_flight_activity_staging2 AS flights
LEFT JOIN customer_loyalty_history_staging loyalty 
ON flights.loyalty_number = loyalty.loyalty_number
WHERE loyalty.loyalty_number IS NULL;
-- this returns 0, so every loyalty_number in the flight activity table exists in the loyalty history table 

-- checking distance and points_accumulated
SELECT *
FROM customer_flight_activity_staging2
WHERE distance > 50000 OR points_accumulated > 80000;
-- there are 48 records where distance is over 50,000 or points_accumulated is over 80000
-- for all both distance and points_accumulated seem to have a direct correlation, and total flights range from 24 to 28, 
-- which looks consistent and does not look like a typo

-- check the total_flights since it was 32 but that was not on the previous query results list 
SELECT *
FROM customer_flight_activity_staging2
WHERE total_flights > 28;
-- 2 results, over 40,000 distance and over 65,000 points_accumulated for both so looks legitimate as well 
-- also, airline_loyalty_data_dictionary describes total_flights as 'Sum of Flights Booked (all tickets purchased in the period)'
-- it doesn't state it's flights_flown, so it could be that they booked a lot of flights for the future, 
-- hence the distance travelled is lower for 32 flights than the distance travelled for the customer who had 28 total_flights

-- 2.3. Standardise the Data in table 2, customer_loyalty_history_staging
SELECT * 
FROM customer_loyalty_history_staging
LIMIT 10;

SELECT * 
FROM airline_loyalty_data_dictionary;

-- check column types
DESCRIBE customer_loyalty_history_staging;
-- types look fine except for salary which is text, not a INT. 
-- clv ('Customer lifetime value - total invoice value for all flights ever booked by member') is a double which 
-- makes sense for dollar value
-- enrollment_year and enrollment_month are INTs which is good but cancellation_year and cancellation_month are text 
-- need to convert cancellation_year and cancellation_month to INT 

-- check salary column and cancellation_year and cancellation_month
SELECT loyalty_number, salary, cancellation_year, cancellation_month 
FROM customer_loyalty_history_staging;
-- lots of blanks in salary, cancellation_year and cancellation_month, will need to convert to nulls? this cannot be filled in 

UPDATE customer_loyalty_history_staging
SET salary = NULL
WHERE salary = '';

UPDATE customer_loyalty_history_staging
SET cancellation_year = NULL
WHERE cancellation_year = '';

UPDATE customer_loyalty_history_staging
SET cancellation_month = NULL
WHERE cancellation_month = '';

-- update data types
ALTER TABLE customer_loyalty_history_staging
MODIFY COLUMN salary INT,
MODIFY COLUMN cancellation_year INT,
MODIFY COLUMN cancellation_month INT;
-- 16737 row(s) affected Records: 16737  Duplicates: 0  Warnings: 0

-- check column types
DESCRIBE customer_loyalty_history_staging;
-- salary, cancellation_year and cancellation_month are now INTs

-- check enrollment_month values for sanity check
SELECT DISTINCT enrollment_month
FROM customer_loyalty_history_staging;
-- listed values are 1 to 12, no issues

-- check cancellation_month values for sanity check
SELECT DISTINCT cancellation_month
FROM customer_loyalty_history_staging;
-- listed values are 1 to 12 and NULL, no issues. Not all are cancelled so NULLs are inevitable

-- check for data logic errors - did anyone cancel before they enrolled?
SELECT *
FROM customer_loyalty_history_staging
WHERE cancellation_year < enrollment_year
   OR (cancellation_year = enrollment_year AND cancellation_month < enrollment_month);
-- no results so all good

-- check extreme values for INTs
SELECT MIN(loyalty_number), MAX(loyalty_number),
		MIN(salary), MAX(salary),
        MIN(clv), MAX(clv),
        MIN(enrollment_year), MAX(enrollment_year),
        MIN(cancellation_year), MAX(cancellation_year)
FROM customer_loyalty_history_staging;
-- loyalty_number ranges from '100018' to '999986' which is consistent with the customer_flight_activity_staging2 table;
-- salary ranges from '-58486' to '407228', need to check the MIN value since it's negative
-- clv ranges from '1898.01' to '83325.38' which looks fine
-- min and max years for enrollment (2012 and 2018 respectively) and cancellation (2013 and 2018 respectively) also look fine

SELECT *
FROM customer_loyalty_history_staging
WHERE salary <50;
-- there are 20 rows in results, range is '-9081' to '-58486'
-- all look genuinely different but all are '2018 Promotion' enrollment_type. 

-- check the rest of salaries for '2018 Promotion' enrollment_type
SELECT 
  COUNT(*) AS total_2018_promotion,
  SUM(CASE WHEN salary < 0 THEN 1 ELSE 0 END) AS negative_salary_2018_promotion
FROM customer_loyalty_history_staging
WHERE enrollment_type = '2018 Promotion';
-- there are 971 rows with '2018 Promotion' enrollment_type and only 20 are negative
-- looks like a genuine processing error, need to update to corresponding positive value

-- update the negative salary values
UPDATE customer_loyalty_history_staging
SET salary = ABS(salary)
WHERE salary < 0;
-- 20 row(s) affected Rows matched: 20  Changed: 20  Warnings: 0

-- check what happened
SELECT MIN(salary), MAX(salary)
FROM customer_loyalty_history_staging;
-- MIN salary is '9081', MAX salary is '407228'

-- check the text columns for inconsistencies
SELECT * 
FROM customer_loyalty_history_staging
LIMIT 10;

-- check country values
SELECT DISTINCT country 
FROM customer_loyalty_history_staging;
-- all records are Canada
-- confirmed: no NULL or blank values present (would have appeared in DISTINCT results)

-- check province values
SELECT DISTINCT province 
FROM customer_loyalty_history_staging
ORDER BY 1;
-- all records look good, no trimming or trailing issues
-- confirmed: no NULL or blank values present (would have appeared in DISTINCT results)

-- check city values
SELECT DISTINCT city 
FROM customer_loyalty_history_staging
ORDER BY 1;
-- all records look good, no trimming or trailing issues
-- confirmed: no NULL or blank values present (would have appeared in DISTINCT results)


-- check postal codes values
SELECT DISTINCT postal_code 
FROM customer_loyalty_history_staging
ORDER BY 1;
-- all records look good, no trimming or trailing issues
-- postal codes follow Canadian format but weren't validated against real Canada Post data, 
-- consistent with this being a synthetic dataset
-- confirmed: no NULL or blank values present (would have appeared in DISTINCT results)

-- check gender values
SELECT DISTINCT gender 
FROM customer_loyalty_history_staging
ORDER BY 1;
-- Male and Female, look good, no trimming or trailing issues
-- confirmed: no NULL or blank values present (would have appeared in DISTINCT results)

-- check education values
SELECT DISTINCT education 
FROM customer_loyalty_history_staging
ORDER BY 1;
-- Results look good, no trimming or trailing issues
-- confirmed: no NULL or blank values present (would have appeared in DISTINCT results)

-- check marital_status values
SELECT DISTINCT marital_status 
FROM customer_loyalty_history_staging
ORDER BY 1;
-- Results look good, no trimming or trailing issues
-- confirmed: no NULL or blank values present (would have appeared in DISTINCT results)

-- check loyalty_card values
SELECT DISTINCT loyalty_card 
FROM customer_loyalty_history_staging
ORDER BY 1;
-- Results look good, no trimming or trailing issues 
-- confirmed: no NULL or blank values present (would have appeared in DISTINCT results)
-- values are Aurora, Nova, Star



-- check enrollment_type values
SELECT DISTINCT enrollment_type 
FROM customer_loyalty_history_staging
ORDER BY 1;
-- Results look good, no trimming or trailing issues
-- confirmed: no NULL or blank values present (would have appeared in DISTINCT results)
-- values are 2018 Promotion, Standard

-- 3. Null Values or Blank Values
-- 3.1. calendar_staging Null Values or Blank Values
SELECT 
  SUM(CASE WHEN `date` IS NULL THEN 1 ELSE 0 END) AS date_nulls,
  SUM(CASE WHEN start_of_year IS NULL THEN 1 ELSE 0 END) AS start_of_year_nulls,
  SUM(CASE WHEN start_of_quarter IS NULL THEN 1 ELSE 0 END) AS start_of_quarter_nulls,
  SUM(CASE WHEN start_of_month IS NULL THEN 1 ELSE 0 END) AS start_of_month_nulls
FROM calendar_staging;
-- this comes up as 0 for all, no further action is required since these are dates, these cannot be blank

-- 3.2. customer_flight_activity_staging2 Null Values or Blank Values
SELECT * 
FROM customer_flight_activity_staging2
LIMIT 10;

SELECT
	SUM(CASE WHEN loyalty_number IS NULL THEN 1 ELSE 0 END) AS loyalty_number_nulls,
    SUM(CASE WHEN `year` IS NULL THEN 1 ELSE 0 END) AS year_nulls,
    SUM(CASE WHEN `month` IS NULL THEN 1 ELSE 0 END) AS month_nulls,
    SUM(CASE WHEN total_flights IS NULL THEN 1 ELSE 0 END) AS total_flights_nulls,
    SUM(CASE WHEN distance IS NULL THEN 1 ELSE 0 END) AS distance_nulls,
    SUM(CASE WHEN points_accumulated IS NULL THEN 1 ELSE 0 END) AS points_accumulated_nulls,
    SUM(CASE WHEN points_redeemed IS NULL THEN 1 ELSE 0 END) AS points_redeemed_nulls,
    SUM(CASE WHEN dollar_cost_points_redeemed IS NULL THEN 1 ELSE 0 END) AS dollar_cost_points_redeemed_nulls
FROM customer_flight_activity_staging2;
-- this comes up as 0 for all, no further action is required since these are INTs, these cannot be blank

-- 3.3. customer_loyalty_history_staging Null Values or Blank Values
SELECT * 
FROM customer_loyalty_history_staging
LIMIT 10;
-- text values, when checked in the previous step, did not have blanks or nulls
-- should check the INT columns

SELECT 
SUM(CASE WHEN loyalty_number IS NULL THEN 1 ELSE 0 END) AS loyalty_number_nulls,
SUM(CASE WHEN salary IS NULL THEN 1 ELSE 0 END) AS salary_nulls,
SUM(CASE WHEN clv IS NULL THEN 1 ELSE 0 END) AS clv_nulls,
SUM(CASE WHEN enrollment_year IS NULL THEN 1 ELSE 0 END) AS enrollment_year_nulls,
SUM(CASE WHEN enrollment_month IS NULL THEN 1 ELSE 0 END) AS enrollment_month_nulls,
SUM(CASE WHEN cancellation_year IS NULL THEN 1 ELSE 0 END) AS cancellation_year_nulls,
SUM(CASE WHEN cancellation_month IS NULL THEN 1 ELSE 0 END) AS cancellation_month_nulls
FROM customer_loyalty_history_staging;
-- nulls in salary which we cannot fill. 4238 rows have nulls, that's roughly 25% of the table
-- nulls in cancellation_year and cancellation_month, which is expected

-- check exact % of salary null values
WITH counts AS (
	SELECT
	(SELECT COUNT(*) FROM customer_loyalty_history_staging) AS total_count,
	(SELECT COUNT(*) FROM customer_loyalty_history_staging WHERE salary IS NULL) AS salary_null
)
SELECT 
	total_count, 
    salary_null, 
    ROUND(salary_null * 100 / total_count, 2) AS salary_null_pct
FROM counts;
-- Confirmed 25% of the table have nulls in salary. 
-- 25% of the table is a lot to drop, will leave in since data in the other columns apart from salary is meaningful

-- check if any cancelled loyalty numbers only have a year or only a month
SELECT COUNT(*)
FROM customer_loyalty_history_staging
WHERE (cancellation_year IS NULL AND cancellation_month IS NOT NULL)
   OR (cancellation_year IS NOT NULL AND cancellation_month IS NULL);
-- zero is displayed, so all cancelled loyalty numbers have both year and month

-- 4. Remove Any Columns or Rows
-- there are no columns or rows to remove. 
-- the salary column with 25% null values can still be explored, just with a note that EDA is done on 75% of dataset

