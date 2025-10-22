SELECT j.path AS revista_tag,
       COUNT(s.submission_id) AS num_articulos_2025
FROM journals j
LEFT JOIN submissions s ON s.context_id = j.journal_id
LEFT JOIN publications p ON p.submission_id = s.submission_id
WHERE YEAR(p.date_published) = 2024
GROUP BY j.path;
