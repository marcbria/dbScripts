-- =============================================================================
-- Query: vives2026-curs.sql
-- Description:
--   Llengua dels articles de revista científica publicats durant el curs
--   (Indicador 2c - Xarxa Vives).
--
--   - Només publicacions amb ISSN i data de publicació dins el curs pertinent.
--   - Curs acadèmic: 1 de setembre a 31 d'agost de l'any natural següent.
--   - Es comptabilitzen els articles traduïts a diferents llengües: un article
--     en català i anglès compta dues vegades.
--   - Si un mateix article té format imprès i digital, compta dues vegades
--     (una per cada format/galley).
--
--   Camps de sortida:
--     revista          -> j.path (ex: brumal)
--     curs             -> període acadèmic (ex: 2023-2024)
--     llengua          -> g.locale (ex: es_ES)
--     nombre_articles  -> nombre de galleys (comptabilització per llengua/format)
-- =============================================================================

SELECT
    j.path AS revista,
    CONCAT(
        YEAR(DATE_SUB(i.date_published, INTERVAL IF(MONTH(i.date_published) < 9, 1, 0) YEAR)),
        '-',
        YEAR(DATE_SUB(i.date_published, INTERVAL IF(MONTH(i.date_published) < 9, 1, 0) YEAR)) + 1
    ) AS curs,
    g.locale AS llengua,
    COUNT(*) AS nombre_articles
FROM journals j
JOIN issues i
    ON i.journal_id = j.journal_id
JOIN publication_settings ps_issue
    ON ps_issue.setting_name  = 'issueId'
    AND ps_issue.setting_value = CAST(i.issue_id AS CHAR)
JOIN publications p
    ON p.publication_id = ps_issue.publication_id
JOIN submissions s
    ON s.submission_id = p.submission_id
    AND s.status = 3
JOIN publication_galleys g
    ON g.publication_id = p.publication_id
JOIN journal_settings js_issn
    ON js_issn.journal_id = j.journal_id
    AND js_issn.setting_name = 'issn'
    AND js_issn.setting_value IS NOT NULL
    AND js_issn.setting_value <> ''
WHERE i.date_published IS NOT NULL
  AND g.locale IS NOT NULL
GROUP BY
    j.path,
    curs,
    g.locale
ORDER BY
    curs DESC,
    revista,
    llengua;
