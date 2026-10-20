-- Problem 04: Employees who earn more than their manager
--
-- Question: Find employees whose salary is higher than their direct manager's.
--
-- Approach: Self-join the employees table to itself on manager_id.
--
-- Run:  psql -d practice -f setup/schema.sql   (once)
--       psql -d practice -f problems/04_employees_earning_more_than_manager.sql

SET search_path TO practice;

SELECT e.full_name AS employee, e.salary, m.full_name AS manager, m.salary AS manager_salary
FROM employees e
JOIN employees m ON m.emp_id = e.manager_id
WHERE e.salary > m.salary
ORDER BY e.full_name;
