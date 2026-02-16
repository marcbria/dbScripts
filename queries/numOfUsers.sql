SELECT 
    j.path AS journal_tag,
    COUNT(DISTINCT u.email) AS total_usuarios
FROM users u
JOIN user_user_groups uug ON u.user_id = uug.user_id
JOIN user_groups ug ON uug.user_group_id = ug.user_group_id
JOIN journals j ON j.journal_id = ug.context_id
GROUP BY j.path;
