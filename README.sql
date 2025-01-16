# Engeto-projekt-SQL

Průvodní listina

Tento dokument obsahuje průvodní informace k datovým výsledkům, které adresují dostupnost základních potravin široké veřejnosti. Cílem tohoto souboru je zodpovědět 5 výzkumných otázek. 

Data v tomto souboru se skládají z následujících kategorií:
- mzdy v odvětvích mezi lety 2000 - 2021
- ceny vybraných produktů mezi lety 2006 - 2018
- základních údajů České Republiky a dalších Evropských států
Protože máme neúplná data ve některých kategoriích tak se budeme pohybovat nejčastěji v letech 2006 - 2018.


Odpovědi na otázky:
1 Rostou v průběhu let mzdy ve všech odvětvích, nebo v některých klesají?

SELECT *
FROM v_average_wage_yearly_difference vawyd
WHERE percentage_change IS NOT NULL
ORDER BY percentage_change ASC;

Díky tomuto dotazu vidíme, že v žádném roce nedošlo ke snížení mzdy v jakémkoliv odvětví. Nejnižší navýšení mzdy jsme zaznamenali v odvětví "Veřejná správa a obrana; povinné sociální zabezpečení" kdy v roce 2012 jim mzda v průměru rostlo o 0,03%.

2 Kolik je možné si koupit litrů mléka a kilogramů chleba za první a poslední srovnatelné období v dostupných datech cen a mezd?

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

Na začátku roku 2006 bylo možné zakoupit za průměrnou mzdu 1185.71 kg chleba a 1238.89 litrů mléka, přičemž v posledním měsíci roku 2018 došlo k navýšení na 1330.8 kg chleba a 1684.09 litrů mléka. To nám říká že průměrná mzda rostla rychleji než cena vybraných produktů.


3 Která kategorie potravin zdražuje nejpomaleji (je u ní nejnižší percentuální meziroční nárůst)?

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


Kategorie potravin která zdražuje nejpomaleji je "Cukr krystalový", který ve skutečnosti zlevňuje ročně o 2.02 %. Pokud chceme vědět který produkt skutečně zdražuje nejpomaleji tak to jsou "Banány žluté", které zdražují ročně o 0.7%.

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

4. Existuje rok, ve kterém byl meziroční nárůst cen potravin výrazně vyšší než růst mezd (větší než 10 %)?

SELECT
	vapcc.`year`,
	vapcc.percentage_change AS price,
	vawcb.percentage_change AS wage,
	vapcc.percentage_change - vawcb.percentage_change AS price_pct_minus_wage_pct
FROM v_average_price_combined_categories vapcc
JOIN v_average_wage_combined_branches vawcb
	ON vapcc.`year` = vawcb.`year`
ORDER BY price_pct_minus_wage_pct DESC;

Můžeme vidět že v žádném roce cena nenarostla o více než 10% oproti mzdě. Nejblíže k tomu bylo v roce 2012 kdy cena produktů narostla o 7.56% a mzda pouze o 0.29% což nám dává rozdíl 7.27%. Pokud chceme vědět jestli jednotlivé kategorie potravin rostly o více než 10% oproti mzdám tak použijeme tento dotaz.

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

5. Má výška HDP vliv na změny ve mzdách a cenách potravin? Neboli, pokud HDP vzroste výrazněji v jednom roce, projeví se to na cenách potravin či mzdách ve stejném nebo následujícím roce výraznějším růstem?

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

nebo

SELECT *
FROM v_yearly_percentage_change_gdp_price_wage vypcgpw;

HDP má pozitivní vliv jak na ceny tak na mzdy. Tím myslíme pokud HDP roste tak rostou cany i mzdy a pokud HDP klesá tak mzdy a ceny rostlou pomaleji nebo klesají. Nedostaneme se k tomu pokud by HDP klesalo tak by ceny a mzdy začali rychleji růst.

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

Pokud použijeme Pearsonův korelační koeficient zjistíme pozitivní vztah jak u HDP-ceny tak i u HDP-mzdy. Dále zjistíme že HDP má vyšší pozitivní vliv na mzdy 0.542 než na ceny 0.304.