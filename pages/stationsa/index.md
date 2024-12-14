---
title: Explore All NYC Stations

---



```sql stations

WITH cleaned_stations AS (
    -- Extract station name, coordinates, and ridership for all stations
    SELECT DISTINCT
        link_friendly_id, -- Extract station name before '('
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













```sql stations_table


-- Assign letter grade based on the calculated safety grade
SELECT
    Station_Name,
    link_friendly_id,
    Latitude,
    Longitude,
    Total_Crime_Weight,
    Total_Ridership,
    Crime_Per_Capita,
    Grade, -- Assign letter grade based on the percentile
FROM 
    ${stations}
ORDER BY 
    Grade




```

```sql unfilt_stations
SELECT
    Station_Name,
    link_friendly_id,
    Latitude,
    Longitude,
    Total_Crime_Weight,
    Total_Ridership,
    Crime_Per_Capita,
    Grade, -- Assign letter grade based on the percentile
FROM 
    ${stations}
```



<Details title='Scoring System'>



### Scoring System
- **Weighted Total Crime Score**: This score considers the severity of crimes multiplied by the number of occurrences, ranked from most serious (Felony) to least serious (Violation).
- **Total Riders**: The total observed incoming and outgoing riders at each station.
- **Incidents per Rider**: Calculated as Weighted Total Crime Score divided by Total Riders.
- **Grade**: Assigned based on the percentile distribution of Incidents per Rider (A to F).


  

</Details>




{#if inputs.station_map.Station_Name === true}

    ## All Stations

{:else}

    ## {inputs.station_map.Station_Name}

    [See Station deep dive &rarr;](./{inputs.station_map.link_friendly_id})

{/if}

<PointMap
    name = station_map
    data={stations}
    lat=Latitude
    long=Longitude
    value=Grade
    legendType=categorical
    height = 500
    startingZoom = 11
    legendPosition=bottomLeft
    colorPalette={['#C65D47', '#D35B85', '#F7C244', '#4A8EBA', '#5BAF7A']}
    tooltipType=click
    tooltip={[
            {id: 'Station_Name', showColumnName: false, valueClass: 'font-bold text-lg'},
            {id: 'Grade'},
            {id: 'link_friendly_id', title: 'Station_Link', linkLabel: 'Station Deep Dive', showColumnName: false, contentType: 'link', valueClass: 'font-bold mt-1'}]}
/>



## Station Ranking

<DataTable data={stations_table} link=link_friendly_id search = true rows= 25 >  	
    <Column id=Station_Name title="Station" /> 	
    <Column id="Total_Crime_Weight" title="Weighted Total Crime Score" contentType=colorscale scaleColor=red align=centre/> 	
    <Column id="Total_Ridership" title="Total Riders" contentType=colorscale scaleColor= gold align=centre/> 	
    <Column id="Crime_Per_Capita" title="Incidents per Rider" contentType=colorscale colorMin=0 colorMax=0.0003 scaleColor={['green','white','maroon']} align=centre/>
    <Column id="Grade" title="Grade"  align=centre/> 	
</DataTable>

{#each unfilt_stations as row}
<a href= "/stationsa/{row.link_friendly_id}"/>
{/each}






