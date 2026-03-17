SELECT * FROM covid

SELECT COUNT(*) FROM covid

-- Measuring Surveillance Sensitivity

-- Q1. Which country have high case counts but missing vaccination 
-- data, suggesting a lag between the infectious virus and shielding against it?

SELECT location, 
       MAX(total_cases) as peak_cases,
       COUNT(new_vaccinations_smoothed) as vaccinated
FROM covid
GROUP BY location
HAVING MAX(total_cases) > 100000 AND COUNT(new_vaccinations_smoothed) = 0
ORDER BY peak_cases DESC;

-- Insight: countries with strong detection but zero intervention are Puerto Rico,
-- Reunion, Martinique and Guadelou

-- Q2. What is the relationship between policy strictness (stringency_index) and 
-- the rate of new cases?

SELECT location, 
       AVG(stringency_index) as strictness_level, 
       MAX(total_cases_per_million) as case_burden
FROM covid
WHERE stringency_index IS NOT NULL
AND total_cases_per_million IS NOT NULL
GROUP BY location
ORDER BY case_burden DESC;

-- Insight: Countries like Cyprus, San Marino and Faeroe Island showed high case 
-- burden with moderate to low strictness. High case counts in these regions 
-- often reflect Surveillance Strength, not necessarily a "failure" to control 
-- the virus. this indicate that the countries prioritized economic continuity 
-- and high-volume testing over prolonged lockdowns during the observation period.

-- Q3. Did the ratio of deaths to cases (Case Fatality Rate) drop as 
-- people_fully_vaccinated increased?

SELECT location,
	MAX(case_fatality_rate) AS fatal_cases,
	MAX(people_fully_vaccinated) AS vaccinated
FROM covid
WHERE post_vaccine_period != '0'
AND people_fully_vaccinated IS NOT NULL 
AND case_fatality_rate IS NOT NULL
GROUP BY location
ORDER BY fatal_cases DESC;

-- Insight: In some countries, the ratio was low while for some, the ratio was 
-- high, this signifies early mortality rate

-- Q4. Which countries report the highest cumulative incidence per
-- 100,000 population?

WITH latest_data AS (
SELECT DISTINCT ON (location)
	location,
	cases_per_100k,
    date
FROM covid
WHERE cases_per_100k IS NOT NULL
ORDER BY location, date DESC
)

SELECT location,
	cases_per_100k
FROM latest_data
ORDER BY cases_per_100k DESC
LIMIT 10;


-- Q5. Which countries have the highest mortality burden per 100,000?
WITH latest_data AS (
SELECT DISTINCT ON (location)
	location,
	deaths_per_100k,
    date
FROM covid
WHERE deaths_per_100k IS NOT NULL
ORDER BY location, date DESC
)

SELECT location,
	deaths_per_100k
FROM latest_data
ORDER BY deaths_per_100k DESC
LIMIT 10;

-- Q6. Which countries exceeded the global average of case fatality rate (CFR) ?
WITH latest_data AS (
SELECT DISTINCT ON (location)
	location,
	case_fatality_rate,
    date
FROM covid
WHERE case_fatality_rate IS NOT NULL
AND case_fatality_rate > (SELECT AVG(case_fatality_rate)
FROM covid)
ORDER BY location, date DESC
)

SELECT location,
	case_fatality_rate
FROM latest_data
ORDER BY case_fatality_rate DESC
LIMIT 10;

-- Q7. Does higher vaccination coverage correspond to lower case fatality rate?
WITH latest_data AS (
SELECT DISTINCT ON (location)
	location,
	vaccination_rate,
	case_fatality_rate
FROM covid
WHERE vaccination_rate IS NOT NULL
AND case_fatality_rate IS NOT NULL
ORDER BY location, date DESC
)

SELECT location,
	vaccination_rate,
	case_fatality_rate
FROM latest_data
ORDER BY vaccination_rate DESC;

-- Insight: Vaccination have a great impact on case_fatality_rate in a positive way


-- Q8. Which countries experienced the largest surge during the Omicron wave?
SELECT location,
	DATE_TRUNC('month', date) AS month,
    SUM(new_cases_smoothed) AS monthly_cases
FROM covid
WHERE date BETWEEN '2022-01-01' AND '2022-12-31'
AND continent IS NOT NULL 
AND new_cases_smoothed IS NOT NULL
GROUP BY location, month
ORDER BY monthly_cases DESC
LIMIT 10;

-- Q9. Which countries improved surveillance reporting over time?
WITH early_period AS (
SELECT location,
	AVG(cases_per_100k) AS early_avg
FROM covid
WHERE date BETWEEN '2020-01-01' AND '2020-12-31'
AND cases_per_100k IS NOT NULL
GROUP BY location
),

late_period AS (
SELECT location,
	AVG(cases_per_100k) AS late_avg
FROM covid
WHERE date BETWEEN '2022-01-01' AND '2022-12-31'
AND cases_per_100k IS NOT NULL
GROUP BY location
)

SELECT e.location,
	e.early_avg,
    l.late_avg,
	(l.late_avg - e.early_avg) AS difference
FROM early_period AS e
JOIN late_period AS l
	ON e.location = l.location
ORDER BY difference DESC;

-- Q10. Did Mortality Decline After Countries Reached 50% Vaccination Coverage?
WITH vaccination_threshold AS (
SELECT location,
	MIN(date) AS date_reached_50
FROM covid
WHERE vaccination_rate >= 50
AND vaccination_rate IS NOT NULL
AND date IS NOT NULL
GROUP BY location
),

mortality_comparison AS (
SELECT c.location,
	AVG(CASE 
		WHEN c.date < v.date_reached_50 
		THEN deaths_per_100k 
		END) AS avg_deaths_before_50,

	AVG(CASE 
		WHEN c.date >= v.date_reached_50 
		THEN deaths_per_100k 
		END) AS avg_deaths_after_50
FROM covid AS c
JOIN vaccination_threshold AS v
ON c.location = v.location
WHERE c.deaths_per_100k IS NOT NULL
GROUP BY c.location
)

SELECT location,
avg_deaths_before_50,
avg_deaths_after_50,
(avg_deaths_after_50 - avg_deaths_before_50) AS mortality_difference
FROM mortality_comparison
WHERE avg_deaths_before_50 IS NOT NULL
AND avg_deaths_after_50 IS NOT NULL
ORDER BY mortality_difference DESC;

-- Many countries hit 50% vaccination during high-transmission waves
-- Mortality burden was still high during those waves
-- Vaccination may have mitigated worse outcomes, but not eliminated deaths



