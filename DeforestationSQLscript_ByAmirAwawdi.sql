/****************** Preparing the data for analysis ********************/

/* Create a View called “forestation” by joining all three tables - forest_area, land_area and regions. */
DROP VIEW IF EXISTS forestation;
CREATE OR REPLACE VIEW forestation AS

/* In the ‘forestation’ View, include the following: 
1. All of the columns of the origin tables 
2. A new column that provides the percent of the land area that is designated as forest. */

/* The column forest_area_sqkm in the forest_area table and the land_area_sqmi in
the land_area table are in different units (square kilometers and square miles, respectively),
so an adjustment is done using this conversion ratio  (1 sq mi = 2.59 sq km). */

SELECT fa.*,
la.total_area_sq_mi*2.59 AS total_area_sqkm,
r.region,
r.income_group,
ROUND(((fa.forest_area_sqkm/(la.total_area_sq_mi*2.59))*100)::numeric,2)
AS forest_area_percent

/* The forest_area and land_area tables join on both country_code AND year. */

FROM forest_area fa
JOIN land_area la
ON fa.country_code = la.country_code AND fa.year = la.year

/* The regions table joins these based on only country_code. */

JOIN regions r
ON fa.country_code = r.country_code
AND  fa.forest_area_sqkm IS NOT NULL
AND la.total_area_sq_mi IS NOT NULL;

/* To observe the View created above */

SELECT *
FROM forestation;


/****************** Part 1 - Global Situation ********************/

/* The following query answers these questions: 
1. What was the total forest area (in sq km) of the world in 1990?
2. What was the total forest area (in sq km) of the world in 2016? */ 

SELECT year, forest_area_sqkm
FROM forestation
WHERE year IN (1990,2016) AND region = 'World';


/* The following query answers these questions: 
1. What was the change (in sq km) in the forest area of the world from 1990 to 2016?
2. What was the percent change in forest area of the world between 1990 and 2016? */

/* Creating a subquery using the WITH command will enable using it later to answer related questions */

WITH year2016 AS (
  SELECT forest_area_sqkm
  FROM forestation
  WHERE year = 2016 AND region = 'World'),
year1990 AS (
  SELECT forest_area_sqkm
  FROM forestation
  WHERE year = 1990 AND region = 'World')


SELECT
(SELECT forest_area_sqkm FROM year1990) - (SELECT forest_area_sqkm FROM year2016) AS change_sqkm,
ROUND((((SELECT forest_area_sqkm FROM year1990) - (SELECT forest_area_sqkm FROM year2016))*100/(SELECT forest_area_sqkm FROM year1990))::numeric,2)
AS change_prcnt


/* The following query, used the WITH statement answers this question:
If you compare the amount of forest area lost between 1990 and 2016, to which country's total area in 2016 is it closest to? */

SELECT country_name, ROUND(total_area_sqkm::numeric,2)
FROM forestation
ORDER BY ABS(total_area_sqkm - ((SELECT forest_area_sqkm FROM year1990) - (SELECT forest_area_sqkm FROM year2016)))
LIMIT 1;


/****************** Part 2 - Regioanl Outlook ********************/


/* Creating a table that shows the Regions and their percent forest area (sum of forest area divided by sum of land area)
in 1990 and 2016. */

/* Creating subqueries using the WITH command will enable using it later to answer multiple related questions */


With forest_precentage_1990 AS (
  SELECT region,SUM(forest_area_sqkm) AS tot_frst_1990,
  ROUND((SUM(forest_area_sqkm)*100/SUM(total_area_sqkm))::numeric,2) AS frst_prcnt_1990
  FROM forestation
  WHERE year = 1990
  GROUP BY region
  ORDER BY tot_frst_1990),
forest_precentage_2016 AS (
  SELECT region, SUM(forest_area_sqkm) AS tot_frst_2016,
  ROUND((SUM(forest_area_sqkm)*100/SUM(total_area_sqkm))::numeric,2) AS frst_prcnt_2016
  FROM forestation
  WHERE year = 2016
  GROUP BY region
  ORDER BY tot_frst_2016),
joined_1990_2016 AS (
  SELECT forest1990.region region_name, frst_prcnt_1990, frst_prcnt_2016,
  ROUND((frst_prcnt_2016-frst_prcnt_1990)::numeric,2) AS prcnt_delta,
  ROUND((((tot_frst_2016)-(tot_frst_1990))*100/(tot_frst_1990))::numeric,2) AS prcnt_change
  FROM forest_precentage_1990 forest1990
  JOIN forest_precentage_2016 forest2016
  ON forest1990.region=forest2016.region
  GROUP BY region_name, frst_prcnt_1990,
  frst_prcnt_2016, prcnt_delta, prcnt_change)
SELECT *
FROM joined_1990_2016


/* To answers these questions:
1. What was the percent forest of the entire world in 2016? Which region had the HIGHEST percent forest in 2016,
and which had the LOWEST, to 2 decimal places?
2. What was the percent forest of the entire world in 1990? Which region had the HIGHEST percent forest in 1990,
and which had the LOWEST, to 2 decimal places? */

/* Use this ORDER BY command after the last FROM statement */
ORDER BY frst_prcnt_2016, frst_prcnt_1990;


/* To answer the following question:
3. Based on the table you created, which regions of the world DECREASED in forest area from 1990 to 2016? */

/* Use instead this ORDER BY command */
ORDER BY prcnt_delta, prcnt_change;


/****************** Part 3 - Country-Level Detail ********************/


/* Creating a table that shows the Regions and their percent forest area (sum of forest area divided by sum of land area)
in 1990 and 2016. */

/* Creating subqueries using the WITH command will enable using it later to answer multiple related questions */

With forest_amount_1990 AS (
  SELECT country_name, region, forest_area_sqkm AS forest_amt_1990
  FROM forestation
  WHERE year = 1990 AND country_name NOT LIKE 'World'
  GROUP BY country_name, forest_amt_1990, region),
forest_amount_2016 AS (
  SELECT country_name, region, forest_area_sqkm AS forest_amt_2016,
  ROUND((forest_area_sqkm*100/total_area_sqkm)::numeric,2) AS frst_prcnt
  FROM forestation
  WHERE year = 2016 AND country_name NOT LIKE 'World'
  GROUP BY country_name, forest_amt_2016, region, frst_prcnt),
joined_1990_2016 AS (
  Select forest1990.country_name, forest1990.region,
  forest_amt_1990,forest_amt_2016
  FROM forest_amount_1990 forest1990
  JOIN forest_amount_2016 forest2016
  ON forest1990.country_name=forest2016.country_name
  AND forest1990.region=forest2016.region),
quartiles_table_2016 AS (
  SELECT country_name, frst_prcnt, region,
  CASE WHEN frst_prcnt > 75 THEN 4
  WHEN frst_prcnt > 50 THEN 3
  WHEN frst_prcnt > 25 THEN 2
  ELSE 1 END AS quartile
  FROM forest_amount_2016
  GROUP BY country_name, region, frst_prcnt, quartile)


/* The following query, used the WITH statement to answers these questions:
1. Which 5 countries saw the largest amount decrease in forest area from 1990 to 2016?
What was the difference in forest area for each?
2. Which 5 countries saw the largest percent decrease in forest area from 1990 to 2016?
What was the percent change to 2 decimal places for each? */

SELECT country_name, region,
((forest_amt_2016)-(forest_amt_1990)) AS amt_change,
ROUND((((forest_amt_2016)-(forest_amt_1990))*100/(forest_amt_1990))::numeric,2) AS prcnt_change
FROM joined_1990_2016
ORDER BY amt_change, prcnt_change
LIMIT 5;


/* The following query, used the WITH statement to answer the following question:
3. If countries were grouped by percent forestation in quartiles,
which group had the most countries in it in 2016? */

SELECT quartile, COUNT(country_name) AS country_count
FROM quartiles_table_2016
GROUP BY quartile
ORDER BY country_count DESC;

/* The following query, used the WITH statement to answer the following question:
4. List all of the countries that were in the 4th quartile (percent forest > 75%) in 2016. */

SELECT country_name, region, frst_prcnt
FROM quartiles_table_2016
WHERE quartile = 4
GROUP BY region, country_name, frst_prcnt
ORDER BY frst_prcnt DESC

/*The following query, used the WITH statement to answer the following question:
5. How many countries had a percent forestation higher than the United States in 2016? */

SELECT COUNT(country_name) AS country_count
FROM quartiles_table_2016
WHERE frst_prcnt > (
  SELECT frst_prcnt
  FROM quartiles_table_2016
  WHERE country_name = 'United States')
