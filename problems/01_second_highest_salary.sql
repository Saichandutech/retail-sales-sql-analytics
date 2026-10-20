-- Problem 01: Second highest salary
--
-- Question: Return the second-highest distinct salary in the company. If there is none, return NULL.
--
-- Approach: DENSE_RANK handles ties (two people can share the top salary); wrapping in a scalar subquery returns NULL instead of no rows.
--
-- Run:  psql -d practice -f setup/schema.sql   (once)
--       psql -d practice -f problems/01_second_highest_salary.sql

SET search_path TO practice;

SELECT (
    SELECT salary
    FROM (SELECT DISTINCT salary, DENSE_RANK() OVER (ORDER BY salary DESC) AS rnk
          FROM employees) ranked
    WHERE rnk = 2
) AS second_highest_salary;
