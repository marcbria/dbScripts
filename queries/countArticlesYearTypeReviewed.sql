SELECT
    YEAR(i.date_published)          AS year,
    COUNT(DISTINCT s.submission_id) AS num_articles,
    g.locale                        AS language,
    g.label                         AS format_type,
    CASE
        WHEN sec_base.meta_reviewed = 1 THEN 'true'
        ELSE 'false'
    END                             AS peer_reviewed

FROM journals j

JOIN issues i
    ON  i.journal_id = j.journal_id

JOIN publication_settings ps_issue
    ON  ps_issue.setting_name  = 'issueId'
    AND ps_issue.setting_value = CAST(i.issue_id AS CHAR)

JOIN publications p
    ON  p.publication_id = ps_issue.publication_id

JOIN submissions s
    ON  s.submission_id = p.submission_id
    AND s.status = 3

JOIN publication_galleys g
    ON  g.publication_id = p.publication_id

LEFT JOIN sections sec_base
    ON  sec_base.section_id = p.section_id

WHERE i.date_published IS NOT NULL

GROUP BY
    year,
    language,
    format_type,
    peer_reviewed

ORDER BY
    year         DESC,
    num_articles DESC,
    language,
    format_type;
