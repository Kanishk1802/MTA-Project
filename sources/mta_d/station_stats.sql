WITH cleaned_stations AS (
    -- Extract station name, coordinates, and ridership for all stations
    SELECT DISTINCT
        link_friendly_id,
        Origin_Point,
        Origin_Station_Complex_Name AS Station_Full_Name,
        CAST(TRIM(SPLIT_PART(SUBSTR(Origin_Point, INSTR(Origin_Point, '(') + 1), ' ', 1)) AS DOUBLE) AS Longitude,
        CAST(TRIM(REPLACE(SPLIT_PART(SUBSTR(Origin_Point, INSTR(Origin_Point, '(') + 1), ' ', 2), ')', '')) AS DOUBLE) AS Latitude,
        SUM(Estimated_Average_Ridership) AS Total_Ridership
    FROM (
        SELECT 
            *,
            FIRST_VALUE(row_num) OVER (PARTITION BY Origin_Station_Complex_Name) AS link_friendly_id
        FROM (
            SELECT 
                *,
                ROW_NUMBER() OVER (PARTITION BY Origin_Station_Complex_Name ORDER BY Origin_Station_Complex_Name) AS row_num
            FROM or_des_rd
        )
    )
    GROUP BY 
        Origin_Point, Station_Full_Name, link_friendly_id
),

crime_data AS (
    -- Aggregate crimes by severity for all stations
    SELECT 
        c.LAW_CAT_CD,
        CASE 
            WHEN c.LAW_CAT_CD = 'FELONY' THEN 3
            WHEN c.LAW_CAT_CD = 'MISDEMEANOR' THEN 2
            WHEN c.LAW_CAT_CD = 'VIOLATION' THEN 1
            ELSE 0
        END AS crime_weight,
        c.Latitude AS Cr_Lat, 
        c.Longitude AS Cr_Long,
        c.CMPLNT_FR_DT AS complaint_date
    FROM 
        nypd_crimes c
    WHERE 
        c.CMPLNT_FR_DT BETWEEN '2024-01-01' AND '2024-08-31'
),

crime_per_capita AS (
    -- Calculate crime per capita for each station
    SELECT 
        s.Station_Full_Name,
        s.link_friendly_id,
        s.Latitude,
        s.Longitude,
        SUM(cd.crime_weight) AS Total_Crime_Weight,
        s.Total_Ridership,
        SUM(cd.crime_weight) / s.Total_Ridership AS Crime_Per_Capita
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
        ) <= 0.2
    GROUP BY 
        s.Station_Full_Name, s.link_friendly_id, s.Latitude, s.Longitude, s.Total_Ridership
)

-- Final result with safety grades
SELECT
    Station_Full_Name AS Station_Name,
    link_friendly_id,
    Latitude,
    Longitude,
    Total_Crime_Weight,
    Total_Ridership,
    Crime_Per_Capita,
    100 - NTILE(100) OVER (ORDER BY Crime_Per_Capita ASC) AS Safety_Grade,
    CASE 
        WHEN (100 - NTILE(100) OVER (ORDER BY Crime_Per_Capita ASC)) >= 90 THEN 'A'
        WHEN (100 - NTILE(100) OVER (ORDER BY Crime_Per_Capita ASC)) >= 75 THEN 'B'
        WHEN (100 - NTILE(100) OVER (ORDER BY Crime_Per_Capita ASC)) >= 50 THEN 'C'
        WHEN (100 - NTILE(100) OVER (ORDER BY Crime_Per_Capita ASC)) >= 25 THEN 'D'
        ELSE 'F'
    END AS Grade
FROM 
    crime_per_capita
ORDER BY 
    Safety_Grade
