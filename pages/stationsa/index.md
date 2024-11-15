---
title: Explore All NYC Stations

---



```sql stations

Select * from mta_d.station_stats

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
WHERE (Station_Name = '${inputs.station_map.Station_Name}'
or '${inputs.station_map.Station_Name}' = 'true')
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

```sql crimes_by_borough

SELECT
    c.BORO_NM AS Borough,  -- Borough name
    DATE_TRUNC('week', c.CMPLNT_FR_DT) AS Week,  -- Week of complaint date
    COUNT(*) AS Total_Crimes  -- Total crimes in each borough per week
FROM 
    mta.nypd_subway_crimes_report c
WHERE 
    YEAR(c.CMPLNT_FR_DT) = 2024 and c.BORO_NM != '(null)' -- Date range for crimes
GROUP BY 
    c.BORO_NM, DATE_TRUNC('week', c.CMPLNT_FR_DT)  -- Group by borough and truncated week
ORDER BY 
    c.BORO_NM, Week  -- Order by borough and week


```



<DataTable data={stations_table} link=link_friendly_id search = true>  	
    <Column id=Station_Name title="Station" /> 	
    <Column id="Total_Crime_Weight" title="Weighted Total Crime Score" contentType=colorscale scaleColor=red align=centre/> 	
    <Column id="Total_Ridership" title="Total Riders" contentType=colorscale scaleColor= gold align=centre/> 	
    <Column id="Crime_Per_Capita" title="Incidents per Rider" contentType=colorscale colorMin=0 colorMax=0.0003 scaleColor={['green','white','maroon']} align=centre/>
    <Column id="Grade" title="Grade"  align=centre/> 	
</DataTable>

{#each unfilt_stations as row}
<a href= "/stationsa/{row.link_friendly_id}"/>
{/each}

### Total Subway Station Crimes by Borough
<AreaChart
    data={crimes_by_borough}
    x=Week
    y=Total_Crimes
    series = Borough
/>





