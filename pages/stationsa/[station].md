<LetterGrade    
  name= {station_info[0].Station_Name}    
  grade={station_info[0].Grade}
/>




```sql station_all

WITH cleaned_stations AS (
    -- Extract station name, coordinates, and ridership for all stations
    SELECT DISTINCT
        link_friendly_id,  -- Extract station name before '('
        Origin_Point,
        Origin_Station_Complex_Name as Station_Full_Name,
        CAST(TRIM(SPLIT_PART(SUBSTR(Origin_Point, INSTR(Origin_Point, '(') + 1), ' ', 1)) AS DOUBLE) AS Longitude,
        CAST(TRIM(REPLACE(SPLIT_PART(SUBSTR(Origin_Point, INSTR(Origin_Point, '(') + 1), ' ', 2), ')', '')) AS DOUBLE) AS Latitude,
        SUM(Estimated_Average_Ridership) AS Total_Ridership  -- Aggregate ridership for each station
    FROM 
        mta_d.origin_dest_ridership_daily
    --where Origin_Station_Complex_Name NOT LIKE '%/%'
    GROUP BY 
     Origin_Point, Station_Full_Name, link_friendly_id
),

crime_data AS (
    -- Aggregate crimes by severity for all stations
    SELECT 
        c.LAW_CAT_CD,
        CASE 
            WHEN c.LAW_CAT_CD = 'FELONY' THEN 3  -- Assign weight 3 for felonies
            WHEN c.LAW_CAT_CD = 'MISDEMEANOR' THEN 2  -- Assign weight 2 for misdemeanors
            WHEN c.LAW_CAT_CD = 'VIOLATION' THEN 1  -- Assign weight 1 for violations
            ELSE 0
        END AS crime_weight,
        c.Latitude AS Cr_Lat, 
        c.Longitude AS Cr_Long,
        c.CMPLNT_FR_DT as complaint_date
    FROM 
        mta.nypd_subway_crimes_report c
    WHERE 
        c.CMPLNT_FR_DT BETWEEN '2024-01-01' AND '2024-08-31'  -- Date range for crimes
),

crime_per_capita AS (
    -- Calculate crime per capita for each station
    SELECT 
        
        s.Station_Full_Name,
        s.link_friendly_id,
        s.Latitude,
        s.Longitude,
        SUM(cd.crime_weight) AS Total_Crime_Weight,  -- Total crime severity score for each station
        s.Total_Ridership,  -- Total ridership for each station
        SUM(cd.crime_weight) / s.Total_Ridership AS Crime_Per_Capita  -- Crime score per rider
    FROM 
        crime_data cd
    JOIN 
        cleaned_stations s 
    ON 
        (
            6371 * ACOS(
                COS(RADIANS(s.Latitude)) * COS(RADIANS(cd.Cr_Lat)) * 
                COS(RADIANS(cd.Cr_Long) - RADIANS(s.Longitude)) + 
                SIN(RADIANS(s.Latitude)) * SIN(RADIANS(cd.Cr_Lat))
            )
        ) <= 0.2  -- 
    GROUP BY 
        s.Station_Full_Name, s.link_friendly_id, s.Latitude, s.Longitude, s.Total_Ridership
)

-- Assign letter grade based on the calculated safety grade
SELECT
    Station_Full_Name as Station_Name,
    link_friendly_id,
    Latitude,
    Longitude,
    Total_Crime_Weight,
    Total_Ridership,
    Crime_Per_Capita,
    -- Rank crime per capita and scale to a 100-point grade
    100 - NTILE(100) OVER (ORDER BY Crime_Per_Capita ASC) AS Safety_Grade,
    -- Assign letter grades based on safety grade thresholds
    CASE 
        WHEN (100 - NTILE(100) OVER (ORDER BY Crime_Per_Capita ASC)) >= 90 THEN 'A'
        WHEN (100 - NTILE(100) OVER (ORDER BY Crime_Per_Capita ASC)) >= 75 THEN 'B'
        WHEN (100 - NTILE(100) OVER (ORDER BY Crime_Per_Capita ASC)) >= 50 THEN 'C'
        WHEN (100 - NTILE(100) OVER (ORDER BY Crime_Per_Capita ASC)) >= 25 THEN 'D'
        ELSE 'F'
    END AS  Grade  -- Assign letter grade based on the percentile
FROM 
    crime_per_capita
ORDER BY 
    Safety_Grade




```


```sql station_info
Select * from 
${station_all}
where link_friendly_id = '${params.station}'
```










```sql crimes_by_hour
WITH cleaned_station AS (
    -- Extract station name and coordinates for the specific station
    SELECT DISTINCT
        Origin_Station_Complex_Name AS Station_Name,  -- Extract station name before '('
        CAST(TRIM(SPLIT_PART(SUBSTR(Origin_Point, INSTR(Origin_Point, '(') + 1), ' ', 1)) AS DOUBLE) AS Longitude,
        CAST(TRIM(REPLACE(SPLIT_PART(SUBSTR(Origin_Point, INSTR(Origin_Point, '(') + 1), ' ', 2), ')', '')) AS DOUBLE) AS Latitude
    FROM 
        mta_d.origin_dest_ridership_daily
    WHERE 
        link_friendly_id = '${params.station}'  -- Filter for the specific station
),

crime_data AS (
    -- Select crimes that occurred within 500 meters of the specific station
    SELECT 
        c.CMPLNT_FR_TM AS complaint_time,  -- Crime complaint time
        c.Latitude AS Cr_Lat, 
        c.Longitude AS Cr_Long
    FROM 
        mta.nypd_subway_crimes_report c, 
        cleaned_station s
    WHERE 
        (
            6371 * ACOS(
                COS(RADIANS(s.Latitude)) * COS(RADIANS(c.Latitude)) * 
                COS(RADIANS(c.Longitude) - RADIANS(s.Longitude)) + 
                SIN(RADIANS(s.Latitude)) * SIN(RADIANS(c.Latitude))
            )
        ) <= 0.2  -- Filter crimes within 500 meters (0.5 kilometers)
)

-- Aggregate crimes by hour of day
SELECT 
    EXTRACT(HOUR FROM CAST(complaint_time AS TIME)) AS hour_of_day,
    COUNT(*) AS total_crimes
FROM 
    crime_data
GROUP BY 
    hour_of_day
ORDER BY 
    hour_of_day

```

```sql crimes_over_time
WITH cleaned_station AS (
    -- Extract station name and coordinates
    SELECT DISTINCT
        TRIM(SPLIT_PART(Origin_Station_Complex_Name, '(', 1)) AS Station_Name,  -- Extract station name before '('
        CAST(TRIM(SPLIT_PART(SUBSTR(Origin_Point, INSTR(Origin_Point, '(') + 1), ' ', 1)) AS DOUBLE) AS Longitude,
        CAST(TRIM(REPLACE(SPLIT_PART(SUBSTR(Origin_Point, INSTR(Origin_Point, '(') + 1), ' ', 2), ')', '')) AS DOUBLE) AS Latitude
    FROM 
        mta_d.origin_dest_ridership_daily
    WHERE link_friendly_id = '${params.station}'
)

SELECT 
    s.Station_Name,  -- Station name
    date_trunc('WEEK', c.CMPLNT_FR_DT) AS complaint_week,  -- Complaint date
    COUNT(*) AS total_crimes  -- Total number of crimes
FROM 
    mta.nypd_subway_crimes_report c
JOIN 
    cleaned_station s
ON 
    (
        6371 * ACOS(
            COS(RADIANS(s.Latitude)) * COS(RADIANS(c.Latitude)) * 
            COS(RADIANS(c.Longitude) - RADIANS(s.Longitude)) + 
            SIN(RADIANS(s.Latitude)) * SIN(RADIANS(c.Latitude))
        )
    ) <= 0.2  --
WHERE 
    c.CMPLNT_FR_DT IS NOT NULL and YEAR(c.CMPLNT_FR_DT) = 2024  -- Ensure complaint date exists
GROUP BY 
    s.Station_Name, complaint_week  -- Group by station and complaint date
ORDER BY 
    complaint_week, s.Station_Name  -- Order by date and station

```


```sql crimes_by_dow
WITH cleaned_station AS (
    -- Extract station name and coordinates
    SELECT DISTINCT
        TRIM(SPLIT_PART(Origin_Station_Complex_Name, '(', 1)) AS Station_Name,  -- Extract station name before '('
        CAST(TRIM(SPLIT_PART(SUBSTR(Origin_Point, INSTR(Origin_Point, '(') + 1), ' ', 1)) AS DOUBLE) AS Longitude,
        CAST(TRIM(REPLACE(SPLIT_PART(SUBSTR(Origin_Point, INSTR(Origin_Point, '(') + 1), ' ', 2), ')', '')) AS DOUBLE) AS Latitude
    FROM 
        mta_d.origin_dest_ridership_daily
    WHERE link_friendly_id = '${params.station}'
)

SELECT 
    s.Station_Name,  -- Station name
    CASE EXTRACT(DAYOFWEEK FROM c.CMPLNT_FR_DT)
        WHEN 0 THEN 'Sunday'
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END AS day_of_week,  -- Day of the week as a name
    COUNT(*) AS total_crimes,  -- Total number of crimes
    EXTRACT(DAYOFWEEK FROM c.CMPLNT_FR_DT) AS day_of_week_order  -- Day of the week for sorting
FROM 
    mta.nypd_subway_crimes_report c
JOIN 
    cleaned_station s
ON 
    (
        6371 * ACOS(
            COS(RADIANS(s.Latitude)) * COS(RADIANS(c.Latitude)) * 
            COS(RADIANS(c.Longitude) - RADIANS(s.Longitude)) + 
            SIN(RADIANS(s.Latitude)) * SIN(RADIANS(c.Latitude))
        )
    ) <= 0.2  -- 
WHERE 
    c.CMPLNT_FR_DT IS NOT NULL AND YEAR(c.CMPLNT_FR_DT) = 2024  -- Ensure complaint date exists and limit to 2024
GROUP BY 
    s.Station_Name, day_of_week, day_of_week_order  -- Group by station and day of the week
ORDER BY 
    day_of_week_order, s.Station_Name  -- Order by day of the week order and station


```


```sql top_crime_categ

WITH cleaned_station AS (
    -- Extract station name and coordinates
    SELECT DISTINCT
        TRIM(SPLIT_PART(Origin_Station_Complex_Name, '(', 1)) AS Station_Name,  -- Extract station name before '('
        CAST(TRIM(SPLIT_PART(SUBSTR(Origin_Point, INSTR(Origin_Point, '(') + 1), ' ', 1)) AS DOUBLE) AS Longitude,
        CAST(TRIM(REPLACE(SPLIT_PART(SUBSTR(Origin_Point, INSTR(Origin_Point, '(') + 1), ' ', 2), ')', '')) AS DOUBLE) AS Latitude
    FROM 
        mta_d.origin_dest_ridership_daily
    WHERE link_friendly_id = '${params.station}'
)

SELECT 
    s.Station_Name,  -- Station name
    c.OFNS_DESC as Offense,
    COUNT(*) AS total_crimes  -- Total number of crimes
FROM 
    mta.nypd_subway_crimes_report c
JOIN 
    cleaned_station s
ON 
    (
        6371 * ACOS(
            COS(RADIANS(s.Latitude)) * COS(RADIANS(c.Latitude)) * 
            COS(RADIANS(c.Longitude) - RADIANS(s.Longitude)) + 
            SIN(RADIANS(s.Latitude)) * SIN(RADIANS(c.Latitude))
        )
    ) <= 0.2  --
WHERE 
    c.CMPLNT_FR_DT IS NOT NULL and YEAR(c.CMPLNT_FR_DT) = 2024  -- Ensure complaint date exists
GROUP BY 
    all  -- Group by station and complaint date
ORDER BY 
    total_crimes desc, s.Station_Name  -- Order by date and station
limit 10
```














<Grid cols=2>
<Group>
<PointMap
    name = selected_station
    data={station_info}
    lat=Latitude
    long=Longitude
    value=Station_Name
    color = blue
    startingZoom = 13
    tooltipType=click
    tooltip={[
            {id: 'Station_Name', showColumnName: false, valueClass: 'font-bold text-lg'},
            {id: 'Grade'}
            ]}
/>
</Group>

<Group>
<LineChart
    data={crimes_over_time}
    x=complaint_week
    y=total_crimes
    title = 'Total Crimes Over Time'
    
/>
</Group>
</Grid>

<Group>
<BarChart
  data={top_crime_categ}
  x=Offense
  y=total_crimes
  swapXY = true
  showAllAxisLabels = true
  title = 'Top 10 Crime Categories'
/>
</Group>



<Grid cols=2>

<LineChart
    data={crimes_by_hour}
    x=hour_of_day
    y=total_crimes
    title = "Total Crimes by Hour of Day (24H)"
/>

<LineChart
    data={crimes_by_dow}
    x=day_of_week
    y=total_crimes
    title = "Total Crimes by Day of Week"
    sort = false
/>

</Grid>












