SELECT
    YEAR(STR_TO_DATE(CAST(m.month AS CHAR), '%Y%m')) AS anio,
    SUM(m.metric)                                     AS vistas_pagina_principal
FROM metrics m
WHERE m.metric_type = 'ojs::counter'
  AND m.assoc_type  = 256   -- ASSOC_TYPE_JOURNAL (página principal de la revista)
GROUP BY anio
ORDER BY anio DESC;
