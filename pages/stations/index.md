---
title: Explore Your Commute

---


<Details title='How to use this page'>

  Select an origin and destination subway station to get specific stats about travelling between two stations.


</Details>

```sql origin_station

Select distinct Origin_Station_Complex_Name as origin
from mta_d.origin_dest_ridership_daily
where Origin_Station_Complex_Name NOT LIKE '%/%'

```

```sql destination_station

Select distinct Destination_Station_Complex_Name as dest
from mta_d.origin_dest_ridership_daily
where Origin_Station_Complex_Name = '${inputs.origin.value}' AND Destination_Station_Complex_Name NOT LIKE '%/%'

```


<Dropdown data={origin_station} name=origin value=origin title = "Origin Station" defaultValue="1 Av (L)"/>

<Dropdown data={destination_station} name=dest value=dest title = "Dest Station" defaultValue="103 St (6)"/>




<PointMap
  data={station_locations}
  lat=Latitude
  long=Longitude
  point_name = Station_Name
  value = Station_Name
  color = blue
  tooltipType=click
  tooltip={[
            {id: 'Station_Name', showColumnName: false, valueClass: 'font-bold text-lg'},
            {id: 'Station_Name', showColumnName: false, contentType: 'link', valueClass: 'font-bold mt-1'}]}
/>

```sql ridership_dow

SELECT 
    SUM(Estimated_Average_Ridership) AS riders, 
    Day_of_Week
FROM 
    mta_d.origin_dest_ridership_daily
WHERE 
    Origin_Station_Complex_Name = '${inputs.origin.value}' 
    AND Destination_Station_Complex_Name = '${inputs.dest.value}'
GROUP BY 
    Day_of_Week
ORDER BY 
    CASE 
        WHEN Day_of_Week = 'Monday' THEN 1
        WHEN Day_of_Week = 'Tuesday' THEN 2
        WHEN Day_of_Week = 'Wednesday' THEN 3
        WHEN Day_of_Week = 'Thursday' THEN 4
        WHEN Day_of_Week = 'Friday' THEN 5
        WHEN Day_of_Week = 'Saturday' THEN 6
        WHEN Day_of_Week = 'Sunday' THEN 7
    END


```

<Grid cols=2>

<LineChart
  title = 'Ridership by Day of Week Between Stations'
  data={ridership_dow}
  x=Day_of_Week
  y=riders
  sort = false
/>


<LineChart
    data={ridership_mnth}
    x=Mnth
    y=riders
    title = 'Ridership by Month Between Stations'
    sort = false
/>
</Grid>










```sql ridership_mnth

SELECT 
    SUM(Estimated_Average_Ridership) AS riders,
    CASE 
        WHEN Month = 1 THEN 'January'
        WHEN Month = 2 THEN 'February'
        WHEN Month = 3 THEN 'March'
        WHEN Month = 4 THEN 'April'
        WHEN Month = 5 THEN 'May'
        WHEN Month = 6 THEN 'June'
        WHEN Month = 7 THEN 'July'
        WHEN Month = 8 THEN 'August'
        WHEN Month = 9 THEN 'September'
        WHEN Month = 10 THEN 'October'
        WHEN Month = 11 THEN 'November'
        WHEN Month = 12 THEN 'December'
    END AS Mnth
FROM 
    mta_d.origin_dest_ridership_daily
WHERE 
    Origin_Station_Complex_Name = '${inputs.origin.value}' 
    AND Destination_Station_Complex_Name = '${inputs.dest.value}'
GROUP BY 
    Month
ORDER BY 
    Month  -- Order by month number to ensure chronological order



```






```sql top_dest_from_origin

Select SUM(Estimated_Average_Ridership) as riders, Destination_Station_Complex_Name as Destination
from mta_d.origin_dest_ridership_daily
where Origin_Station_Complex_Name = '${inputs.origin.value}' and Destination_Station_Complex_Name NOT LIKE '%/%'
group by all
order by riders desc
limit 10

```

```sql top_inflow_to_orig

Select SUM(Estimated_Average_Ridership) as riders, Origin_Station_Complex_Name as Origin
from mta_d.origin_dest_ridership_daily
where Destination_Station_Complex_Name = '${inputs.dest.value}' and Origin_Station_Complex_Name NOT LIKE '%/%'
group by all
order by riders desc
limit 10

```


```sql station_locations

SELECT distinct
    Origin_Station_Complex_Name as Station_Name,  Origin_Point,
   CAST(TRIM(SPLIT_PART(SUBSTR(Origin_Point, INSTR(Origin_Point, '(') + 1), ' ', 1)) AS DOUBLE) AS Longitude,
    CAST(TRIM(REPLACE(SPLIT_PART(SUBSTR(Origin_Point, INSTR(Origin_Point, '(') + 1), ' ', 2), ')', '')) AS DOUBLE) AS Latitude

FROM 
    mta_d.origin_dest_ridership_daily
where Origin_Station_Complex_Name in ('${inputs.origin.value}', '${inputs.dest.value}') 

```








```sql stations_orig

WITH cleaned_stations AS (
    -- Extract station name, coordinates, and ridership for the selected station
    SELECT DISTINCT
        Origin_Station_Complex_Name AS Station_Name,
        Origin_Point,
        CAST(TRIM(SPLIT_PART(SUBSTR(Origin_Point, INSTR(Origin_Point, '(') + 1), ' ', 1)) AS DOUBLE) AS Longitude,
        CAST(TRIM(REPLACE(SPLIT_PART(SUBSTR(Origin_Point, INSTR(Origin_Point, '(') + 1), ' ', 2), ')', '')) AS DOUBLE) AS Latitude,
        SUM(Estimated_Average_Ridership) AS Total_Ridership
    FROM 
        mta_d.origin_dest_ridership_daily
    WHERE 
        Origin_Station_Complex_Name = '${inputs.origin.value}'  -- Filter for the specific station
    GROUP BY 
        Station_Name, Origin_Point
),

nearby_stations AS (
    -- Find stations within 500 meters of the selected station
    SELECT 
        Origin_Station_Complex_Name AS Station_Name,
        CAST(TRIM(SPLIT_PART(SUBSTR(Origin_Point, INSTR(Origin_Point, '(') + 1), ' ', 1)) AS DOUBLE) AS Longitude,
        CAST(TRIM(REPLACE(SPLIT_PART(SUBSTR(Origin_Point, INSTR(Origin_Point, '(') + 1), ' ', 2), ')', '')) AS DOUBLE) AS Latitude,
        SUM(Estimated_Average_Ridership) AS Total_Ridership
    FROM 
        mta_d.origin_dest_ridership_daily
    GROUP BY 
        Station_Name, Origin_Point
    HAVING 
        (
            6371 * ACOS(
                COS(RADIANS((SELECT Latitude FROM cleaned_stations))) * COS(RADIANS(Latitude)) * 
                COS(RADIANS(Longitude) - RADIANS((SELECT Longitude FROM cleaned_stations))) + 
                SIN(RADIANS((SELECT Latitude FROM cleaned_stations))) * SIN(RADIANS(Latitude))
            )
        ) <= 0.5  -- Filter for stations within 500 meters of the selected station
),

crime_data AS (
    -- Aggregate crimes by severity for the nearby stations
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
        mta.nypd_subway_crimes_report c
    WHERE 
        YEAR(c.CMPLNT_FR_DT) = 2024
)

-- Calculate crime per capita and assign safety grades
SELECT 
    s.Station_Name,
    SUM(cd.crime_weight) AS Total_Crime_Weight,
    s.Total_Ridership,
    SUM(cd.crime_weight) / s.Total_Ridership AS Crime_Per_Capita,
    
    -- Safety grade based on percentiles
    100 - NTILE(100) OVER (ORDER BY SUM(cd.crime_weight) / s.Total_Ridership ASC) AS Safety_Grade,
    
    -- Assign letter grades based on safety grade thresholds
    CASE 
        WHEN (100 - NTILE(100) OVER (ORDER BY SUM(cd.crime_weight) / s.Total_Ridership ASC)) >= 90 THEN 'A'
        WHEN (100 - NTILE(100) OVER (ORDER BY SUM(cd.crime_weight) / s.Total_Ridership ASC)) >= 75 THEN 'B'
        WHEN (100 - NTILE(100) OVER (ORDER BY SUM(cd.crime_weight) / s.Total_Ridership ASC)) >= 50 THEN 'C'
        WHEN (100 - NTILE(100) OVER (ORDER BY SUM(cd.crime_weight) / s.Total_Ridership ASC)) >= 25 THEN 'D'
        ELSE 'F'
    END AS Grade  -- Assign letter grade based on percentile

FROM 
    crime_data cd
JOIN 
    nearby_stations s ON (
        6371 * ACOS(
            COS(RADIANS(s.Latitude)) * COS(RADIANS(cd.Cr_Lat)) * 
            COS(RADIANS(cd.Cr_Long) - RADIANS(s.Longitude)) + 
            SIN(RADIANS(s.Latitude)) * SIN(RADIANS(cd.Cr_Lat))
        )
    ) <= 0.2  -- Filter crimes within 200 meters of each nearby station
GROUP BY 
    s.Station_Name, s.Total_Ridership
ORDER BY 
    Safety_Grade DESC

```


```sql stations_dest


WITH cleaned_stations AS (
    -- Extract station name, coordinates, and ridership for the selected station
    SELECT DISTINCT
        Origin_Station_Complex_Name AS Station_Name,
        Origin_Point,
        CAST(TRIM(SPLIT_PART(SUBSTR(Origin_Point, INSTR(Origin_Point, '(') + 1), ' ', 1)) AS DOUBLE) AS Longitude,
        CAST(TRIM(REPLACE(SPLIT_PART(SUBSTR(Origin_Point, INSTR(Origin_Point, '(') + 1), ' ', 2), ')', '')) AS DOUBLE) AS Latitude,
        SUM(Estimated_Average_Ridership) AS Total_Ridership
    FROM 
        mta_d.origin_dest_ridership_daily
    WHERE 
        Origin_Station_Complex_Name = '${inputs.dest.value}'  -- Filter for the specific station
    GROUP BY 
        Station_Name, Origin_Point
),

nearby_stations AS (
    -- Find stations within 500 meters of the selected station
    SELECT 
        Origin_Station_Complex_Name AS Station_Name,
        CAST(TRIM(SPLIT_PART(SUBSTR(Origin_Point, INSTR(Origin_Point, '(') + 1), ' ', 1)) AS DOUBLE) AS Longitude,
        CAST(TRIM(REPLACE(SPLIT_PART(SUBSTR(Origin_Point, INSTR(Origin_Point, '(') + 1), ' ', 2), ')', '')) AS DOUBLE) AS Latitude,
        SUM(Estimated_Average_Ridership) AS Total_Ridership
    FROM 
        mta_d.origin_dest_ridership_daily
    GROUP BY 
        Station_Name, Origin_Point
    HAVING 
        (
            6371 * ACOS(
                COS(RADIANS((SELECT Latitude FROM cleaned_stations))) * COS(RADIANS(Latitude)) * 
                COS(RADIANS(Longitude) - RADIANS((SELECT Longitude FROM cleaned_stations))) + 
                SIN(RADIANS((SELECT Latitude FROM cleaned_stations))) * SIN(RADIANS(Latitude))
            )
        ) <= 0.5  -- Filter for stations within 500 meters of the selected station
),

crime_data AS (
    -- Aggregate crimes by severity for the nearby stations
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
        mta.nypd_subway_crimes_report c
    WHERE 
        YEAR(c.CMPLNT_FR_DT) = 2024
)

-- Calculate crime per capita and assign safety grades
SELECT 
    s.Station_Name,
    SUM(cd.crime_weight) AS Total_Crime_Weight,
    s.Total_Ridership,
    SUM(cd.crime_weight) / s.Total_Ridership AS Crime_Per_Capita,
    
    -- Safety grade based on percentiles
    100 - NTILE(100) OVER (ORDER BY SUM(cd.crime_weight) / s.Total_Ridership ASC) AS Safety_Grade,
    
    -- Assign letter grades based on safety grade thresholds
    CASE 
        WHEN (100 - NTILE(100) OVER (ORDER BY SUM(cd.crime_weight) / s.Total_Ridership ASC)) >= 90 THEN 'A'
        WHEN (100 - NTILE(100) OVER (ORDER BY SUM(cd.crime_weight) / s.Total_Ridership ASC)) >= 75 THEN 'B'
        WHEN (100 - NTILE(100) OVER (ORDER BY SUM(cd.crime_weight) / s.Total_Ridership ASC)) >= 50 THEN 'C'
        WHEN (100 - NTILE(100) OVER (ORDER BY SUM(cd.crime_weight) / s.Total_Ridership ASC)) >= 25 THEN 'D'
        ELSE 'F'
    END AS Grade  -- Assign letter grade based on percentile

FROM 
    crime_data cd
JOIN 
    nearby_stations s ON (
        6371 * ACOS(
            COS(RADIANS(s.Latitude)) * COS(RADIANS(cd.Cr_Lat)) * 
            COS(RADIANS(cd.Cr_Long) - RADIANS(s.Longitude)) + 
            SIN(RADIANS(s.Latitude)) * SIN(RADIANS(cd.Cr_Lat))
        )
    ) <= 0.2  -- Filter crimes within 200 meters of each nearby station
GROUP BY 
    s.Station_Name, s.Total_Ridership
ORDER BY 
    Safety_Grade DESC

```












<Tabs>
    <Tab label='Outbound Traffic from Origin'>

    <BarChart
    data={top_dest_from_origin}
     x=Destination
     y=riders
    swapXY = true
    showAllAxisLabels = true
    />

    </Tab>

    <Tab label='Inbound Traffic to Destination'>
    <BarChart
    data={top_inflow_to_orig}
    x=Origin
    y=riders
    swapXY = true
    showAllAxisLabels = true
    />
    </Tab>
</Tabs>








<Alert>
The below tables showcase nearby stations (within 500m to origin/dest) and their relative crime stats
</Alert>

<Tabs>
  <Tab label='Stations Near Origin'>

    <DataTable data={stations_orig} link=Station_Name>  	
    <Column id=Station_Name title="Station" /> 	
    <Column id="Total_Crime_Weight" title="Weighted Total Crime Score" contentType=colorscale scaleColor=red align=centre/> 	
    <Column id="Total_Ridership" title="Total Riders" contentType=colorscale scaleColor= gold align=centre/> 	
    <Column id="Crime_Per_Capita" title="Incidents per Rider" contentType=colorscale colorMin=0 colorMax=0.0003 scaleColor={['green','white','maroon']} align=centre/>
</DataTable>

  </Tab>
  <Tab label='Stations Near Destination'>
    
    <DataTable data={stations_dest} link=Station_Name>  	
    <Column id=Station_Name title="Station" /> 	
    <Column id="Total_Crime_Weight" title="Weighted Total Crime Score" contentType=colorscale scaleColor=red align=centre/> 	
    <Column id="Total_Ridership" title="Total Riders" contentType=colorscale scaleColor= gold align=centre/> 	
    <Column id="Crime_Per_Capita" title="Incidents per Rider" contentType=colorscale colorMin=0 colorMax=0.0003 scaleColor={['green','white','maroon']} align=centre/>
</DataTable>

  </Tab>
</Tabs>