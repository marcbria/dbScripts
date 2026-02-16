SELECT 
  j.path AS journalTag,
  (
SELECT COUNT(*)
FROM `author_settings`
WHERE `setting_name` = 'orcid' 
  AND `setting_value` LIKE '%http://%'
  ) AS orcid_http_count
FROM journals j;

