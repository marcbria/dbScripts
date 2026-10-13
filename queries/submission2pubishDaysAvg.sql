SELECT
    ROUND(AVG(DATEDIFF(first_pub.date_published, s.date_submitted)), 1) AS avg_days_to_publish
FROM submissions s
INNER JOIN (
    SELECT submission_id, MIN(date_published) AS date_published
    FROM publications
    WHERE status = 3
    GROUP BY submission_id
) AS first_pub ON first_pub.submission_id = s.submission_id
WHERE s.status = 3
  AND YEAR(first_pub.date_published) >= 2022;
