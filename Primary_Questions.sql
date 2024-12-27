-- An online SQL formatter was used to improve query readability which is a great practice, as it makes the code easier to understand, maintain, and debug --
-- Top Performing Cities by Total Trips --
SELECT 
    c.city_name,
    COUNT(t.trip_id) AS total_trips
FROM 
    fact_trips t
JOIN 
    dim_city c ON t.city_id = c.city_id
GROUP BY 
    c.city_name
ORDER BY 
    total_trips DESC
LIMIT 3;

-- Bottom 3 Cities by Total trips--
SELECT 
    c.city_name,
    COUNT(t.trip_id) AS total_trips
FROM 
    fact_trips t
JOIN 
    dim_city c ON t.city_id = c.city_id
GROUP BY 
    c.city_name
ORDER BY 
    total_trips ASC
LIMIT 3;

-- Highest Average Fare Per Trip by City --
SELECT 
    c.city_name,
    AVG(t.fare_amount) AS avg_fare_per_city
FROM 
    fact_trips t
JOIN 
    dim_city c ON t.city_id = c.city_id
GROUP BY 
    c.city_name
ORDER BY 
    avg_fare_per_city DESC
LIMIT 3;

-- Lowest Average Fare Per Trip by City --
SELECT 
    c.city_name,
    AVG(t.fare_amount) AS avg_fare_per_city
FROM 
    fact_trips t
JOIN 
    dim_city c ON t.city_id = c.city_id
GROUP BY 
    c.city_name
ORDER BY 
    avg_fare_per_city ASC
LIMIT 3;

-- Average Fare per Trip by City & Average distance travelled  --

SELECT 
    c.city_name,
    AVG(t.fare_amount) AS avg_fare_per_trip,
    AVG(t.distance_travelled_km) AS avg_distance
FROM 
    fact_trips t
JOIN 
    dim_city c ON t.city_id = c.city_id
GROUP BY 
    c.city_name
ORDER BY 
    avg_fare_per_trip DESC;
    
-- Average Ratings by City & Passenger type  --
SELECT 
    c.city_name,
    t.passenger_type,
    AVG(t.passenger_rating) AS avg_passenger_rating,
    AVG(t.driver_rating) AS avg_driver_rating
FROM 
    fact_trips t
JOIN 
    dim_city c ON t.city_id = c.city_id
GROUP BY 
    c.city_name, t.passenger_type
ORDER BY 
    avg_passenger_rating DESC;

-- Peak and Low Demand Months by City--
WITH CityMonthTrips AS (
    SELECT 
        c.city_name,
        d.month_name,
        COUNT(t.trip_id) AS total_trips
    FROM 
        fact_trips t
    JOIN 
        dim_city c ON t.city_id = c.city_id
    JOIN 
        dim_date d ON t.date = d.date
    GROUP BY 
        c.city_name, d.month_name
),
RankedTrips AS (
    SELECT 
        city_name,
        month_name,
        total_trips,
        RANK() OVER (PARTITION BY city_name ORDER BY total_trips DESC) AS ranking
    FROM 
        CityMonthTrips
)
SELECT 
    city_name,
    month_name,
    total_trips
FROM 
    RankedTrips
WHERE 
    ranking = 1;

-- Weekday vs Weekend Trip Demand by City --

SELECT 
c.city_name,
SUM(CASE WHEN day_type = "weekday" THEN 1 ELSE 0 END) as weekday_total,
SUM(CASE WHEN day_type = "weekend" THEN 1 ELSE 0 END) as weekend_total
FROM fact_trips f
JOIN dim_date dd ON
f.date=dd.date
JOIN dim_city c ON
f.city_id=c.city_id
GROUP BY city_name
ORDER BY weekday_total desc

-- Repeat passenger Frequency and City Contribution Analysis --

SELECT
    c.city_name,
    r.trip_count,
    SUM(r.repeat_passenger_count) AS total_repeat_passengers,
    ROUND(100.0 * SUM(r.repeat_passenger_count) / 
          SUM(SUM(r.repeat_passenger_count)) OVER (PARTITION BY c.city_name), 2) AS percent_contribution
FROM 
    dim_repeat_trip_distribution r
JOIN 
    dim_city c ON r.city_id = c.city_id
GROUP BY 
    c.city_name, r.trip_count
ORDER BY 
    c.city_name, r.trip_count;
    
    -- Monthly Target Achievement Analysis for Key Matrics--
SELECT 
    c.city_name,
    d.month_name,
    COUNT(f.trip_id) AS total_trips,
    tt.total_target_trips,
    AVG(f.passenger_rating) AS average_rating,
    pr.target_avg_passenger_rating,
    SUM(CASE WHEN f.passenger_type = 'new' THEN 1 ELSE 0 END) AS new_passengers,
    np.target_new_passengers
FROM 
    fact_trips f
JOIN 
    dim_city c ON f.city_id = c.city_id
JOIN 
    dim_date d ON f.date = d.date
JOIN 
    targets_db.city_target_passenger_rating pr ON c.city_id = pr.city_id
JOIN 
    targets_db.monthly_target_trips tt 
        ON c.city_id = tt.city_id AND d.start_of_month = tt.month
JOIN 
    targets_db.monthly_target_new_passengers np 
        ON c.city_id = np.city_id AND d.start_of_month = np.month
JOIN 
    trips_db.fact_passenger_summary ps
        ON c.city_id = ps.city_id AND d.start_of_month = ps.month
GROUP BY 
    c.city_name, 
    d.month_name,
    pr.target_avg_passenger_rating, 
    tt.total_target_trips,
    np.target_new_passengers
ORDER BY 
    c.city_name, d.month_name;
    
    -- Highest and Lowest RPR % for each city-- 
    
    WITH CityRPR AS (
    SELECT 
        c.city_name,
        ROUND((SUM(fps.repeat_passengers) / SUM(fps.total_passengers)) * 100.0, 2) AS RPRPercentage
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
        RPRPercentage,
        RANK() OVER (ORDER BY RPRPercentage DESC) AS rank_highest,
        RANK() OVER (ORDER BY RPRPercentage ASC) AS rank_lowest
    FROM
        CityRPR
)
SELECT 
    city_name, 
    RPRPercentage,
    CASE 
        WHEN rank_highest <= 2 THEN 'Top 2'
        WHEN rank_lowest <= 2 THEN 'Bottom 2'
        ELSE NULL
    END AS city_category
FROM 
    RankedCities
WHERE 
    rank_highest <= 2 OR rank_lowest <= 2
ORDER BY 
    city_category, RPRPercentage DESC;

   -- Calculate the Repeat Passenger Rate (RPR%) for each city for each month--
    SELECT
        c.city_name,
        EXTRACT(MONTH FROM d.date) AS month,
        EXTRACT(YEAR FROM d.date) AS year,
        SUM(fps.total_passengers) AS total_passengers,
        SUM(fps.repeat_passengers) AS repeat_passengers,
        -- Calculate Repeat Passenger Rate (RPR%) as (Repeat Passengers / Total Passengers) * 100
        (SUM(fps.repeat_passengers) / SUM(fps.total_passengers)) * 100 AS rpr_percentage
    FROM
        fact_passenger_summary fps
    JOIN
        dim_city c ON fps.city_id = c.city_id
    JOIN
        dim_date d ON EXTRACT(MONTH FROM d.date) = EXTRACT(MONTH FROM fps.month) 
        AND EXTRACT(YEAR FROM d.date) = EXTRACT(YEAR FROM fps.month)
    GROUP BY
        c.city_name, EXTRACT(MONTH FROM d.date), EXTRACT(YEAR FROM d.date)

