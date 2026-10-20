# SQL Practice

![SQL checks](https://github.com/Saichandutech/sql-practice/actions/workflows/sql-checks.yml/badge.svg)

Interview-style SQL problems I solve to keep my skills sharp, written for **PostgreSQL**.
Each file states the question, explains the approach, and contains a working solution that runs against a
small practice database (`setup/schema.sql`), so every answer can be checked by eye.

## Problems

| # | Problem | Technique |
|---|---|---|
| 01 | [Second highest salary](problems/01_second_highest_salary.sql) | DENSE_RANK, scalar subquery |
| 02 | [Top 2 earners per department](problems/02_top_earners_per_department.sql) | Top-N per group, window functions |
| 03 | [Departments with no employees](problems/03_departments_without_employees.sql) | Anti-join, NOT EXISTS |
| 04 | [Employees who earn more than their manager](problems/04_employees_earning_more_than_manager.sql) | Self-join |

## How to run

```bash
createdb practice
psql -d practice -f setup/schema.sql          # tables + sample data
psql -d practice -f problems/09_longest_login_streak.sql
```

Every push runs all problems against a fresh PostgreSQL 16 database in GitHub Actions, so a broken query fails the check.

## Data model

| Table | What it holds |
|---|---|
| `departments` | 5 departments (one has no employees) |
| `employees` | 15 employees with salary, department and manager (self-referencing) |
| `customers` | 8 customers, including a duplicate email and customers with no orders |
| `orders` | 17 orders with Completed / Cancelled / Returned status |
| `user_logins` | Daily logins, including a repeat login on the same day |

All data is made up for practice.
