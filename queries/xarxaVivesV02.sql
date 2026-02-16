SELECT 
  j.path AS journal_slug,								-- JorunalTag
  i.issue_id AS issue_number,							-- Issue Number
  YEAR(i.date_published) AS issue_year, 				-- Year os publishing
  DATE_FORMAT(i.date_published, '%Y%m%d') AS full_date,	-- Publishing Date
  s.submission_id AS article_id,        				-- Article ID
  p.publication_id AS publication_id,					-- Publishing ID
  g.locale AS language,                 				-- Galley number
  g.label AS format_type,								-- Format Type
  CONCAT(
    'https://revistes.uab.cat/',
    j.path,
    '/article/view/',
    COALESCE(p.url_path, p.publication_id),
    '/',
    COALESCE(g.url_path, g.galley_id)
  ) AS resource_url
FROM journals j
JOIN issues i ON i.journal_id = j.journal_id
JOIN publication_settings ps_issue 
  ON ps_issue.setting_name = 'issueId' 
  AND ps_issue.setting_value = CAST(i.issue_id AS CHAR)
JOIN publications p ON p.publication_id = ps_issue.publication_id
JOIN submissions s ON p.submission_id = s.submission_id
JOIN publication_galleys g ON g.publication_id = p.publication_id
WHERE i.date_published IS NOT NULL
  AND YEAR(i.date_published) BETWEEN 2021 AND 2023
ORDER BY i.issue_id, language, format_type;
