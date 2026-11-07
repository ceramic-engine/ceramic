-- Users with orders
SELECT u.id, u.name, COUNT(o.id) AS orders
FROM users u
LEFT JOIN orders o ON o.user_id = u.id
WHERE u.created_at > '2024-01-01' AND u.active = TRUE
GROUP BY u.id, u.name
HAVING COUNT(o.id) >= 3
ORDER BY orders DESC
LIMIT 10;
