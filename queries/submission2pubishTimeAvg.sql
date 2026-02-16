SELECT
    ROUND(AVG(DATEDIFF(ed.date_decided, s.date_submitted)), 0) AS avg_days_to_accepted,
    ROUND(AVG(DATEDIFF(p.date_published, s.date_submitted)), 0) AS avg_days_to_publish
FROM submissions s
JOIN edit_decisions ed
    ON ed.submission_id = s.submission_id
JOIN publications p
    ON p.submission_id = s.submission_id
JOIN sections sec
    ON sec.section_id = p.section_id
WHERE s.date_submitted >= '2024-01-01 00:00:00'
  AND s.status = 3
  AND sec.meta_reviewed = 1
