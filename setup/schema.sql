-- =============================================================
-- Practice database (PostgreSQL). Small, hand-made data so every
-- answer can be checked by eye. Run this once, then any problem file.
--   psql -d practice -f setup/schema.sql
-- =============================================================
DROP SCHEMA IF EXISTS practice CASCADE;
CREATE SCHEMA practice;
SET search_path TO practice;

CREATE TABLE departments (
    dept_id    INT PRIMARY KEY,
    dept_name  TEXT NOT NULL
);

CREATE TABLE employees (
    emp_id     INT PRIMARY KEY,
    full_name  TEXT NOT NULL,
    dept_id    INT REFERENCES departments,
    manager_id INT REFERENCES employees(emp_id),
    salary     NUMERIC(10,2) NOT NULL,
    hire_date  DATE NOT NULL
);

CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    name        TEXT NOT NULL,
    email       TEXT,
    city        TEXT,
    signup_date DATE NOT NULL
);

CREATE TABLE orders (
    order_id    INT PRIMARY KEY,
    customer_id INT REFERENCES customers,
    order_date  DATE NOT NULL,
    amount      NUMERIC(10,2) NOT NULL,
    status      TEXT NOT NULL CHECK (status IN ('Completed', 'Cancelled', 'Returned'))
);

CREATE TABLE user_logins (
    user_id    INT NOT NULL,
    login_date DATE NOT NULL
);

INSERT INTO departments VALUES
 (1, 'Analytics'), (2, 'Engineering'), (3, 'Sales'), (4, 'Finance'), (5, 'Legal');

INSERT INTO employees VALUES
 (1,  'Avery Rivera',  NULL, NULL, 185000, '2016-02-01'),
 (2,  'Jordan Patel',  1,    1,    142000, '2018-05-14'),
 (3,  'Taylor Nguyen', 1,    2,     98000, '2021-03-08'),
 (4,  'Morgan Kim',    1,    2,     98000, '2022-07-19'),
 (5,  'Casey Garcia',  1,    2,     76000, '2024-01-10'),
 (6,  'Riley Okafor',  2,    1,    160000, '2017-09-25'),
 (7,  'Quinn Chen',    2,    6,    131000, '2019-11-04'),
 (8,  'Jamie Silva',   2,    7,    134000, '2020-06-15'),
 (9,  'Drew Khan',     2,    6,    104000, '2023-02-27'),
 (10, 'Sam Lopez',     3,    1,    120000, '2018-01-22'),
 (11, 'Robin Brown',   3,    10,    82000, '2021-08-30'),
 (12, 'Kai Ali',       3,    10,    82000, '2022-04-11'),
 (13, 'Reese Rossi',   3,    10,    69000, '2025-03-03'),
 (14, 'Parker Murphy', 4,    1,    115000, '2019-04-01'),
 (15, 'Rowan Singh',   4,    14,    91000, '2023-09-18');

INSERT INTO customers VALUES
 (101, 'Northwind LLC',   'ops@northwind.example',  'Dallas',      '2025-01-05'),
 (102, 'Blue Harbor Co',  'hello@blueharbor.example','Houston',     '2025-01-20'),
 (103, 'Cedar & Pine',    NULL,                      'Austin',      '2025-02-11'),
 (104, 'Lakeside Supply', 'ap@lakeside.example',     'Dallas',      '2025-02-28'),
 (105, 'Summit Retail',   'buy@summit.example',      'San Antonio', '2025-03-15'),
 (106, 'Ironwood Labs',   'ops@northwind.example',   'Austin',      '2025-04-02'),
 (107, 'Maple Street',    'team@maple.example',      'Houston',     '2025-05-09'),
 (108, 'Harbor Point',    'orders@harborpoint.example','Dallas',    '2025-05-20');

INSERT INTO orders VALUES
 (1001, 101, '2025-01-07',  420.00, 'Completed'),
 (1002, 101, '2025-02-03',  310.00, 'Completed'),
 (1003, 102, '2025-02-14',  990.00, 'Completed'),
 (1004, 101, '2025-03-01',  150.00, 'Cancelled'),
 (1005, 103, '2025-03-05',  275.50, 'Completed'),
 (1006, 102, '2025-03-18',  640.00, 'Returned'),
 (1007, 104, '2025-03-30', 1200.00, 'Completed'),
 (1008, 101, '2025-04-12',  515.00, 'Completed'),
 (1009, 105, '2025-04-20',  180.00, 'Completed'),
 (1010, 102, '2025-05-02',  720.00, 'Completed'),
 (1011, 104, '2025-05-15',  860.00, 'Completed'),
 (1012, 103, '2025-05-28',  140.00, 'Completed'),
 (1013, 101, '2025-06-03',  610.00, 'Completed'),
 (1014, 105, '2025-06-21',  330.00, 'Completed'),
 (1015, 104, '2025-06-29',  910.00, 'Completed'),
 (1016, 101, '2025-06-29',  610.00, 'Completed'),
 (1017, 108, '2025-06-10',  455.00, 'Completed');

INSERT INTO user_logins VALUES
 (1, '2025-06-01'), (1, '2025-06-02'), (1, '2025-06-03'), (1, '2025-06-05'), (1, '2025-06-06'),
 (2, '2025-06-01'), (2, '2025-06-03'), (2, '2025-06-04'), (2, '2025-06-05'), (2, '2025-06-06'), (2, '2025-06-07'),
 (3, '2025-06-02'), (3, '2025-06-02'), (3, '2025-06-09');
