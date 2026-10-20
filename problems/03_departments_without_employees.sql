-- Problem 03: Departments with no employees
--
-- Question: List departments that have nobody assigned.
--
-- Approach: Anti-join: NOT EXISTS is NULL-safe, unlike NOT IN, which returns nothing if the subquery contains a NULL.
--
-- Run:  psql -d practice -f setup/schema.sql   (once)
--       psql -d practice -f problems/03_departments_without_employees.sql

SET search_path TO practice;

SELECT d.dept_id, d.dept_name
FROM departments d
WHERE NOT EXISTS (SELECT 1 FROM employees e WHERE e.dept_id = d.dept_id)
ORDER BY d.dept_id;
