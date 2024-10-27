SELECT 
    *,
    FIRST_VALUE(row_num) OVER (PARTITION BY Origin_Station_Complex_Name) AS link_friendly_id
FROM (
    SELECT 
        *,
        ROW_NUMBER() OVER (PARTITION BY Origin_Station_Complex_Name ORDER BY Origin_Station_Complex_Name) AS row_num
    FROM or_des_rd
) AS subquery

