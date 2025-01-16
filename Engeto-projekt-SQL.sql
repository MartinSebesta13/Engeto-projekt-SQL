-- Martin Šebesta

-- Tvorba tabulek

CREATE OR REPLACE TABLE t_martin_šebesta_projekt_SQL_primary_final AS
SELECT
	cpc.name AS food_category,
	cp.value AS price,
	cpc.price_value AS price_value,
	cpc.price_unit AS price_unit,
	cp.date_from AS price_masured_from,
	cp.date_to AS price_masured_to,
	cpib.name AS industry_branch,
	cpy.value AS average_wage,
	cpy.payroll_year AS year,
	cpy.payroll_quarter AS quarter
FROM czechia_payroll cpy
LEFT JOIN czechia_price cp
	ON cpy.payroll_year = YEAR(cp.date_from)
	AND ((month(cp.date_from) BETWEEN 1 AND 3 AND cpy.payroll_quarter = 1)
	OR (month(cp.date_from) BETWEEN 4 AND 6 AND cpy.payroll_quarter = 2)
	OR (month(cp.date_from) BETWEEN 7 AND 9 AND cpy.payroll_quarter = 3)
	OR (month(cp.date_from) BETWEEN 9 AND 12 AND cpy.payroll_quarter = 4))
LEFT JOIN czechia_price_category cpc
	ON cp.category_code = cpc.code
LEFT JOIN czechia_payroll_industry_branch cpib
	ON cpy.industry_branch_code = cpib.code
JOIN czechia_payroll_calculation cpcal
	ON cpy.calculation_code = cpcal.code
	AND cpy.calculation_code = 100 -- fyzicka
JOIN czechia_payroll_value_type cpvt
	ON cpy.value_type_code = cpvt.code
	AND cpy.value_type_code = 5958 -- mzda 
JOIN czechia_payroll_unit cpu
	ON cpy.unit_code = cpu.code
	AND cpy.unit_code = 200 -- kc
WHERE cp.region_code IS NULL;-- prumer všech regionu

CREATE TABLE t_martin_šebesta_projekt_SQL_secondary_final AS 
SELECT
	e.country,
	e.`year`,
	e.GDP,
	e.gini,
	e.population
FROM economies e
JOIN countries c
	ON e.country = c.country
WHERE c.continent = 'Europe'
	AND e.YEAR >= 2000;

-- 1 Rostou v průběhu let mzdy ve všech odvětvích, nebo v některých klesají?

CREATE VIEW v_average_wage_per_year AS 
SELECT
	industry_branch,
	year,
	avg(average_wage) AS average_wage_yearly
FROM t_martin_šebesta_projekt_sql_primary_final tmšpspf
GROUP BY industry_branch, year
ORDER BY year;

CREATE VIEW v_average_wage_yearly_difference AS
SELECT
	industry_branch,
	year,
	average_wage_yearly,
	lag(average_wage_yearly,1) OVER (PARTITION BY industry_branch ORDER BY average_wage_yearly) AS average_wage_last_year,
	CASE 
		WHEN lag(average_wage_yearly,1) OVER (PARTITION BY industry_branch ORDER BY average_wage_yearly) IS NOT NULL
		THEN round((average_wage_yearly - lag(average_wage_yearly,1) OVER (PARTITION BY industry_branch ORDER BY average_wage_yearly)) / lag(average_wage_yearly,1) OVER (PARTITION BY industry_branch ORDER BY average_wage_yearly) * 100, 2)
		ELSE NULL 
	END AS percentage_change
FROM v_average_wage_per_year vawpy
ORDER BY industry_branch, year;

SELECT *
FROM v_average_wage_yearly_difference vawyd
WHERE percentage_change IS NOT NULL
ORDER BY percentage_change ASC;

-- 2 Kolik je možné si koupit litrů mléka a kilogramů chleba za první a poslední srovnatelné období v dostupných datech cen a mezd?

SELECT
	food_category,
	min(price_masured_from),
	max(price_masured_from)
FROM t_martin_šebesta_projekt_sql_primary_final tmšpspf
WHERE food_category IN  ('Chléb konzumní kmínový', 'Mléko polotučné pasterované')
GROUP BY food_category;

SELECT
	food_category,
	price,
	price_value,
	price_unit,
	price_masured_from,
	quarter,
	average_wage,
	round(average_wage / price, 2) AS units_purchasable
FROM t_martin_šebesta_projekt_sql_primary_final tmšpspf
WHERE food_category IN  ('Chléb konzumní kmínový', 'Mléko polotučné pasterované')
	AND industry_branch IS NULL
	AND (price_masured_from = '2006-01-02'
	OR price_masured_from = '2018-12-10')
ORDER BY food_category;

-- 3 Která kategorie potravin zdražuje nejpomaleji (je u ní nejnižší percentuální meziroční nárůst)?

CREATE VIEW v_average_price_yearly AS 
SELECT
	food_category,
	round(avg(price), 2) AS price,
	price_value,
	price_unit,
	year
FROM t_martin_šebesta_projekt_sql_primary_final tmšpspf
WHERE food_category IS NOT NULL
GROUP BY food_category, year
ORDER BY food_category, year;

CREATE VIEW v_average_price_yearly_difference AS 
SELECT
	*,
	lag(price,1) OVER (PARTITION BY food_category ORDER BY year) AS price_last_year,
	CASE 
		WHEN lag(price,1) OVER (PARTITION BY food_category ORDER BY year) IS NOT NULL
		THEN round((price - lag(price,1) OVER (PARTITION BY food_category ORDER BY year)) / lag(price,1) OVER (PARTITION BY food_category ORDER BY year) * 100, 2)
		ELSE NULL 
	END percentage_change
FROM v_average_price_yearly vapy;

SELECT
	food_category,
	price_value,
	price_unit,
	round(avg(percentage_change), 2) AS average_price_yearly_percentage_change
FROM v_average_price_yearly_difference vapyd
WHERE percentage_change IS NOT NULL
GROUP BY food_category
ORDER BY average_price_yearly_percentage_change
LIMIT 1;

SELECT
	food_category,
	price_value,
	price_unit,
	round(avg(percentage_change), 2) AS average_price_yearly_percentage_change
FROM v_average_price_yearly_difference vapyd
WHERE percentage_change IS NOT NULL
GROUP BY food_category
HAVING average_price_yearly_percentage_change > 0
ORDER BY average_price_yearly_percentage_change
LIMIT 1;

-- 4. Existuje rok, ve kterém byl meziroční nárůst cen potravin výrazně vyšší než růst mezd (větší než 10 %)?

CREATE VIEW v_average_wage_combined_branches AS 
SELECT *
FROM v_average_wage_yearly_difference vawyd
WHERE industry_branch IS NULL;

CREATE VIEW v_average_price_combined_categories AS 
SELECT
	year,
	round(avg(price), 2) AS price,
	round(avg(price_last_year), 2) AS price_last_year,
	round(avg(percentage_change), 2) AS percentage_change
FROM v_average_price_yearly_difference vapyd
GROUP BY year;

SELECT
	vapcc.`year`,
	vapcc.percentage_change AS price,
	vawcb.percentage_change AS wage,
	vapcc.percentage_change - vawcb.percentage_change AS price_pct_minus_wage_pct
FROM v_average_price_combined_categories vapcc
JOIN v_average_wage_combined_branches vawcb
	ON vapcc.`year` = vawcb.`year`
ORDER BY price_pct_minus_wage_pct DESC;

SELECT
	vawcb.`year`,
	vapyd.food_category,
	vapyd.percentage_change,
	vawcb.percentage_change,
	vapyd.percentage_change - vawcb.percentage_change AS price_pct_minus_wage_pct
FROM v_average_price_yearly_difference vapyd
JOIN v_average_wage_combined_branches vawcb
	ON vapyd.`year` = vawcb.`year`
WHERE vapyd.percentage_change - vawcb.percentage_change > 10
ORDER BY price_pct_minus_wage_pct DESC;

-- 5. Má výška HDP vliv na změny ve mzdách a cenách potravin? Neboli, 
-- pokud HDP vzroste výrazněji v jednom roce, projeví se to na cenách potravin či mzdách ve stejném nebo násdujícím roce výraznějším růstem?

CREATE VIEW v_Czechia_gdp_percentage_change AS
SELECT
	country,
	year,
	gdp,
	lag (gdp,1) OVER (ORDER BY year) AS GDP_last_year,
	CASE 
		WHEN lag (gdp,1) OVER (ORDER BY year) IS NOT NULL
		THEN round ((gdp - lag (gdp,1) OVER (ORDER BY year)) / lag (gdp,1) OVER (ORDER BY year) * 100, 2)
		ELSE NULL
	END percentage_change
FROM t_martin_šebesta_projekt_sql_secondary_final tmšpssf
WHERE country LIKE 'Czech%'
	AND gdp IS NOT NULL;
	
CREATE VIEW v_yearly_percentage_change_gdp_price_wage AS
SELECT
	vcgpc.`year`,
	vcgpc.percentage_change AS gdp,
	vapcc.percentage_change AS price,
	vawcb.percentage_change AS wage
FROM v_czechia_gdp_percentage_change vcgpc
JOIN v_average_price_combined_categories vapcc
	ON vcgpc.`year` = vapcc.`year`
JOIN v_average_wage_combined_branches vawcb
	ON vcgpc.`year` = vawcb.`year`;

SELECT *
FROM v_yearly_percentage_change_gdp_price_wage vypcgpw;
	
SELECT
	round((
		(count(*) * sum(gdp * wage)) - (sum(gdp) * sum(wage))
	) / 
	(
		sqrt(
			(count(*) * sum(gdp * gdp) - (sum(gdp) * sum(gdp))) * 
			(count(*) * sum(wage * wage) - (sum(wage) * sum(wage))))
	), 3) AS correlation_gdp_wage,
	round((
		(count(*) * sum(gdp * price)) - (sum(gdp) * sum(price))
	) / 
	(
		sqrt(
			(count(*) * sum(gdp * gdp) - (sum(gdp) * sum(gdp))) * 
			(count(*) * sum(price * price) - (sum(price) * sum(price))))
	), 3) AS correlation_gdp_price
FROM v_yearly_percentage_change_gdp_price_wage;