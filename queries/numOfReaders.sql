SELECT j.path AS journal_tag,
       COUNT(DISTINCT u.email) AS total_lectores
FROM journals j
JOIN user_groups ug ON ug.context_id = j.journal_id
JOIN user_user_groups uug ON uug.user_group_id = ug.user_group_id
JOIN users u ON u.user_id = uug.user_id
JOIN user_group_settings ugs ON ug.user_group_id = ugs.user_group_id
WHERE j.journal_id = 1
  AND ugs.setting_name = 'name'
  AND (
        LOWER(ugs.setting_value) LIKE '%reader%'
     OR LOWER(ugs.setting_value) LIKE '%lector%'
     OR LOWER(ugs.setting_value) LIKE '%lecteur%'
  )
GROUP BY j.path;
