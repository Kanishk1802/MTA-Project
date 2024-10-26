Select *, 
REGEXP_EXTRACT(Origin_Station_Complex_Name, '\\(([^\\)]+)\\)') AS Origin_Station_Lines,
REGEXP_EXTRACT(Destination_Station_Complex_Name, '\\(([^\\)]+)\\)') AS Dest_Station_Lines,
from 'origin_dest_ridership_daily.csv'
order by year desc, month desc, Day_of_Week desc
limit 10000
