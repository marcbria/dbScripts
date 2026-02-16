UPDATE author_settings
SET setting_value = REPLACE(setting_value, 'http://', 'https://')
WHERE setting_name = 'orcid'
  AND setting_value LIKE 'http://%';
