SELECT
    j.path AS journal_slug,
    i.issue_id AS issue_number,
    YEAR(i.date_published) AS issue_year,
    p.publication_id AS publication_id,
    g.locale AS language,  -- ahora extrae el idioma de la galerada
    g.label AS format_type,
    CONCAT(
        'https://revistes.uab.cat/',
        j.path,
        '/article/view/',
        COALESCE(p.url_path, p.publication_id),
        '/',
        COALESCE(g.url_path, g.galley_id)
    ) AS resource_url
FROM
    journals j
JOIN
    issues i ON i.journal_id = j.journal_id
JOIN
    publication_settings ps_issue
      ON ps_issue.setting_name = 'issueId'
     AND ps_issue.setting_value = CAST(i.issue_id AS CHAR)
JOIN
    publications p ON p.publication_id = ps_issue.publication_id
JOIN
    submissions s ON p.submission_id = s.submission_id
JOIN
    publication_galleys g ON g.publication_id = p.publication_id
WHERE
    i.date_published IS NOT NULL
    AND YEAR(i.date_published) BETWEEN 2021 AND 2023
ORDER BY
    i.issue_id,
    p.publication_id;
