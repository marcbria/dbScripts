SELECT 
  author_id,
  setting_value AS original_value,
  REPLACE(setting_value, 'http://', 'https://') AS updated_value
FROM author_settings
WHERE setting_name = 'orcid'
  AND setting_value LIKE 'http://%';
