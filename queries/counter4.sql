SELECT
    YEAR(STR_TO_DATE(CAST(m.month AS CHAR), '%Y%m')) AS anio,
    SUM(CASE WHEN m.assoc_type = 1048585 THEN m.metric ELSE 0 END) AS vistas_abstract,
    SUM(CASE WHEN m.assoc_type = 515     THEN m.metric ELSE 0 END) AS descargas,
    SUM(m.metric)                                                    AS total_accesos
FROM metrics m
WHERE m.metric_type = 'ojs::counter'
  AND m.assoc_type  IN (515, 1048585)
GROUP BY anio
ORDER BY anio DESC;
