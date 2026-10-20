-- Problem 02: Top 2 earners per department
--
-- Question: For each department, list the two highest-paid employees. Include ties.
--
-- Approach: Top-N per group: rank inside each department with DENSE_RANK, then filter. ROW_NUMBER would silently drop tied employees.
--
-- Run:  psql -d practice -f setup/schema.sql   (once)
--       psql -d practice -f problems/02_top_earners_per_department.sql

SET search_path TO practice;

WITH ranked AS (
    SELECT d.dept_name, e.full_name, e.salary,
           DENSE_RANK() OVER (PARTITION BY e.dept_id ORDER BY e.salary DESC) AS rnk
    FROM employees e
    JOIN departments d USING (dept_id)
)
SELECT dept_name, full_name, salary, rnk
FROM ranked
WHERE rnk <= 2
ORDER BY dept_name, rnk, full_name;
