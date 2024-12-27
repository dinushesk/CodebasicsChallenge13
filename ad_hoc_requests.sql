-- Business Request 1- City Level Fare and Trip Summary Report--

SELECT 
    c.city_name, 
    COUNT(t.trip_id) AS total_trips,
    AVG(t.fare_amount / t.distance_travelled_km) AS avg_fare_per_km,
    SUM(t.fare_amount) / COUNT(t.trip_id) AS avg_fare_per_trip,
    (COUNT(t.trip_id) * 100.0) / SUM(COUNT(t.trip_id)) OVER () AS pct_contribution_to_total
FROM 
    fact_trips t
JOIN 
    dim_city c
ON 
    t.city_id = c.city_id
WHERE 
    t.distance_travelled_km > 0
GROUP BY 
    c.city_name
ORDER BY 
    c.city_name ASC;
    
-- Business Request 2- Monthly City-Level Trips Target Performance Report--   
 
SELECT 
    c.city_name,
    d.month_name,
    COUNT(ft.trip_id) AS actual_trips,
    mt.total_target_trips AS target_trips,
    CASE 
        WHEN COUNT(ft.trip_id) > mt.total_target_trips THEN 'Above Target'
        ELSE 'Below Target'
    END AS performance_status,
    ROUND(((COUNT(ft.trip_id) - mt.total_target_trips) * 100.0) / mt.total_target_trips, 2) AS pct_difference
FROM 
    fact_trips ft
JOIN 
    dim_city c ON ft.city_id = c.city_id
JOIN 
    dim_date d ON ft.date = d.date
JOIN 
    targets_db.monthly_target_trips mt ON ft.city_id = mt.city_id AND d.start_of_month = mt.month
GROUP BY 
    c.city_name, d.month_name, mt.total_target_trips
ORDER BY 
    c.city_name, d.month_name;
    
    -- Business Request 3- City-Level Repeat Passenger Trip Frequency Report--  
SELECT 
    c.city_name,
    ROUND(SUM(CASE WHEN rtd.trip_count = '2-Trips' THEN rtd.repeat_passenger_count ELSE 0 END) * 100.0 / SUM(rtd.repeat_passenger_count), 2) AS "2-Trips",
    ROUND(SUM(CASE WHEN rtd.trip_count = '3-Trips' THEN rtd.repeat_passenger_count ELSE 0 END) * 100.0 / SUM(rtd.repeat_passenger_count), 2) AS "3-Trips",
    ROUND(SUM(CASE WHEN rtd.trip_count = '4-Trips' THEN rtd.repeat_passenger_count ELSE 0 END) * 100.0 / SUM(rtd.repeat_passenger_count), 2) AS "4-Trips",
    ROUND(SUM(CASE WHEN rtd.trip_count = '5-Trips' THEN rtd.repeat_passenger_count ELSE 0 END) * 100.0 / SUM(rtd.repeat_passenger_count), 2) AS "5-Trips",
    ROUND(SUM(CASE WHEN rtd.trip_count = '6-Trips' THEN rtd.repeat_passenger_count ELSE 0 END) * 100.0 / SUM(rtd.repeat_passenger_count), 2) AS "6-Trips",
    ROUND(SUM(CASE WHEN rtd.trip_count = '7-Trips' THEN rtd.repeat_passenger_count ELSE 0 END) * 100.0 / SUM(rtd.repeat_passenger_count), 2) AS "7-Trips",
    ROUND(SUM(CASE WHEN rtd.trip_count = '8-Trips' THEN rtd.repeat_passenger_count ELSE 0 END) * 100.0 / SUM(rtd.repeat_passenger_count), 2) AS "8-Trips",
    ROUND(SUM(CASE WHEN rtd.trip_count = '9-Trips' THEN rtd.repeat_passenger_count ELSE 0 END) * 100.0 / SUM(rtd.repeat_passenger_count), 2) AS "9-Trips",
    ROUND(SUM(CASE WHEN rtd.trip_count = '10-Trips' THEN rtd.repeat_passenger_count ELSE 0 END) * 100.0 / SUM(rtd.repeat_passenger_count), 2) AS "10-Trips"
FROM 
    dim_repeat_trip_distribution rtd
JOIN 
    dim_city c ON rtd.city_id = c.city_id
GROUP BY 
    c.city_name
ORDER BY 
    c.city_name;
    
    -- Business Request 4- Identify cities with highest and lowest total new passengers--  
    
WITH CityNewPassengers AS (
    SELECT 
        c.city_name,
        SUM(fps.new_passengers) AS total_new_passengers
    FROM 
        fact_passenger_summary fps
    JOIN 
        dim_city c ON fps.city_id = c.city_id
    GROUP BY 
        c.city_name
),
RankedCities AS (
    SELECT 
        city_name,
        total_new_passengers,
        RANK() OVER (ORDER BY total_new_passengers DESC) AS rank_highest,
        RANK() OVER (ORDER BY total_new_passengers ASC) AS rank_lowest
    FROM 
        CityNewPassengers
)
SELECT 
    city_name,
    total_new_passengers,
    CASE 
        WHEN rank_highest <= 3 THEN 'Top 3'
        WHEN rank_lowest <= 3 THEN 'Bottom 3'
        ELSE NULL
    END AS city_category
FROM 
    RankedCities
WHERE 
    rank_highest <= 3 OR rank_lowest <= 3
ORDER BY 
    city_category, total_new_passengers DESC;
    
  -- Business Request 5- Identify month with highest revenue for each city--  
  
WITH CityRevenue AS (
    SELECT
        c.city_name,
        EXTRACT(YEAR FROM t.date) AS year,
        EXTRACT(MONTH FROM t.date) AS month,
        SUM(t.fare_amount) AS total_revenue
    FROM
        fact_trips t
    JOIN
        dim_city c ON t.city_id = c.city_id
    GROUP BY
        c.city_name, EXTRACT(YEAR FROM t.date), EXTRACT(MONTH FROM t.date)
),
AnnualCityRevenue AS (
    SELECT
        city_name,
        year,
        SUM(total_revenue) AS annual_revenue
    FROM
        CityRevenue
    GROUP BY
        city_name, year
),
HighestRevenueMonth AS (
    SELECT
        cr.city_name,
        cr.year,
        cr.month,
        cr.total_revenue,
        acr.annual_revenue,
        RANK() OVER (PARTITION BY cr.city_name ORDER BY cr.total_revenue DESC) AS rank_highest
    FROM
        CityRevenue cr
    JOIN
        AnnualCityRevenue acr ON cr.city_name = acr.city_name AND cr.year = acr.year
)
SELECT
    hr.city_name,
    hr.year,
    hr.month AS highest_revenue_month,
    hr.total_revenue AS revenue,
    ROUND((hr.total_revenue / hr.annual_revenue) * 100, 2) AS percentage_contribution
FROM
    HighestRevenueMonth hr
WHERE
    hr.rank_highest = 1
ORDER BY
    hr.city_name, hr.year;

  -- Business Request 6- Repeat passenger rate analysis --

WITH monthly_repeat_rate AS (
    -- Calculate monthly repeat passenger rate for each city and month
    SELECT
        c.city_name,
        EXTRACT(MONTH FROM d.date) AS month,
        EXTRACT(YEAR FROM d.date) AS year,
        SUM(fps.total_passengers) AS total_passengers,
        SUM(fps.repeat_passengers) AS repeat_passengers,
        -- Monthly repeat passenger rate
        (SUM(fps.repeat_passengers) / SUM(fps.total_passengers)) * 100 AS monthly_repeat_customer_rate
    FROM
        fact_passenger_summary fps
    JOIN
        dim_city c ON fps.city_id = c.city_id
    JOIN
        dim_date d ON EXTRACT(MONTH FROM d.date) = EXTRACT(MONTH FROM fps.month) 
        AND EXTRACT(YEAR FROM d.date) = EXTRACT(YEAR FROM fps.month)
    GROUP BY
        c.city_name, EXTRACT(MONTH FROM d.date), EXTRACT(YEAR FROM d.date)
),

city_repeat_rate AS (
    -- Calculate overall repeat passenger rate for each city across all months
    SELECT
        c.city_name,
        SUM(fps.total_passengers) AS total_passengers,
        SUM(fps.repeat_passengers) AS repeat_passengers,
        -- City repeat passenger rate (across all months)
        (SUM(fps.repeat_passengers) / SUM(fps.total_passengers)) * 100 AS city_repeat_customer_rate
    FROM
        fact_passenger_summary fps
    JOIN
        dim_city c ON fps.city_id = c.city_id
    GROUP BY
        c.city_name
)

-- Combine monthly repeat rate with city repeat rate
SELECT
    mm.city_name,
    mm.month,
    mm.monthly_repeat_customer_rate,
    cr.city_repeat_customer_rate
FROM
    monthly_repeat_rate mm
JOIN
    city_repeat_rate cr ON mm.city_name = cr.city_name
ORDER BY
    mm.city_name, mm.year, mm.month;
