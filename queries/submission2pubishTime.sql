SELECT
    s.submission_id,
    DATE(s.date_submitted) AS date_submited,
    ed.decision,
    DATE(ed.date_decided) AS date_decided,
    DATE(p.date_published) AS date_published,
    DATEDIFF(ed.date_decided, s.date_submitted) AS days_to_accepted,
    DATEDIFF(p.date_published, s.date_submitted) AS days_to_publish
FROM submissions s
JOIN edit_decisions ed
    ON ed.submission_id = s.submission_id
JOIN publications p
    ON p.submission_id = s.submission_id
JOIN sections sec
    ON sec.section_id = p.section_id
WHERE s.date_submitted >= '2020-01-01 00:00:00'
  AND s.status = 3
  AND sec.meta_reviewed = 1
