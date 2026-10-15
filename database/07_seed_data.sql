-- ============================================================================
-- ADVANCED DATABASE MANAGEMENT SYSTEMS (ADBMS) PROJECT
-- System: Employee Payroll Management System (EPMS)
-- Script 07: Realistic Seed Dataset (28 Employees, 6 Months Attendance & Payroll)
-- Engine: PostgreSQL 15+
-- ============================================================================

-- Clean up existing data if re-running
TRUNCATE TABLE payslips, payroll_runs, salary_change_audit, salary_structures, 
    leave_applications, leave_balances, attendance, holidays, employees, users, 
    designations, departments, leave_types, tax_slabs, payroll_config RESTART IDENTITY CASCADE;

-- Reset payslip sequence
ALTER SEQUENCE payslip_id_seq RESTART WITH 1;

-- ============================================================================
-- 1. DEPARTMENTS
-- ============================================================================
INSERT INTO departments (dept_code, dept_name, location, annual_budget) VALUES
('EXEC', 'Executive Leadership', 'Headquarters, Floor 10', 12000000.00),
('ENG',  'Software Engineering', 'Tower A, Floor 4-5',    36000000.00),
('HR',   'Human Resources',     'Tower B, Floor 2',      8000000.00),
('FIN',  'Finance & Accounting', 'Tower B, Floor 3',      9500000.00),
('MKT',  'Marketing & Growth',  'Tower A, Floor 2',      11000000.00),
('OPS',  'IT & Cloud Operations','Tower A, Floor 3',      14000000.00);

-- ============================================================================
-- 2. DESIGNATIONS (Grades 1 to 10 with Salary Ranges)
-- ============================================================================
INSERT INTO designations (designation_code, designation_title, min_salary, max_salary, pay_grade) VALUES
('CEO',  'Chief Executive Officer',      300000.00, 600000.00, 10),
('VP_ENG','Vice President of Engineering', 200000.00, 400000.00, 9),
('EM',   'Engineering Manager',          140000.00, 250000.00, 8),
('ARCH', 'Principal Architect',          160000.00, 280000.00, 8),
('SSE',  'Senior Software Engineer',      90000.00, 160000.00, 6),
('SE',   'Software Engineer',             50000.00, 95000.00, 4),
('QA',   'Quality Assurance Engineer',    45000.00, 85000.00, 4),
('HR_DIR','Head of People & Culture',    150000.00, 260000.00, 8),
('HR_SPEC','HR Specialist',               45000.00, 80000.00, 4),
('FIN_DIR','Chief Financial Officer',    200000.00, 400000.00, 9),
('ACC_SR','Senior Payroll Accountant',    70000.00, 130000.00, 6),
('ACC_JR','Junior Accountant',            40000.00, 70000.00, 3),
('MKT_DIR','Director of Marketing',      140000.00, 250000.00, 8),
('MKT_SPEC','Growth Marketing Lead',      60000.00, 110000.00, 5),
('DEVOPS','Cloud Infrastructure Lead',    95000.00, 170000.00, 6);

-- ============================================================================
-- 3. USERS (Roles: ADMIN, HR, ACCOUNTANT, EMPLOYEE)
-- Password hash corresponds to 'Password@123' (SHA-256 for academic portability)
-- ============================================================================
INSERT INTO users (username, password_hash, role, is_active) VALUES
('admin',     'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'ADMIN',      TRUE),
('hr_lead',   'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'HR',         TRUE),
('accountant','ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'ACCOUNTANT', TRUE),
-- 28 Employee Portal Users (emp01 to emp28)
('emp01', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'EMPLOYEE', TRUE),
('emp02', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'EMPLOYEE', TRUE),
('emp03', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'EMPLOYEE', TRUE),
('emp04', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'EMPLOYEE', TRUE),
('emp05', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'EMPLOYEE', TRUE),
('emp06', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'EMPLOYEE', TRUE),
('emp07', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'EMPLOYEE', TRUE),
('emp08', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'EMPLOYEE', TRUE),
('emp09', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'EMPLOYEE', TRUE),
('emp10', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'EMPLOYEE', TRUE),
('emp11', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'EMPLOYEE', TRUE),
('emp12', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'EMPLOYEE', TRUE),
('emp13', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'EMPLOYEE', TRUE),
('emp14', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'EMPLOYEE', TRUE),
('emp15', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'EMPLOYEE', TRUE),
('emp16', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'EMPLOYEE', TRUE),
('emp17', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'EMPLOYEE', TRUE),
('emp18', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'EMPLOYEE', TRUE),
('emp19', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'EMPLOYEE', TRUE),
('emp20', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'EMPLOYEE', TRUE),
('emp21', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'EMPLOYEE', TRUE),
('emp22', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'EMPLOYEE', TRUE),
('emp23', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'EMPLOYEE', TRUE),
('emp24', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'EMPLOYEE', TRUE),
('emp25', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'EMPLOYEE', TRUE),
('emp26', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'EMPLOYEE', TRUE),
('emp27', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'EMPLOYEE', TRUE),
('emp28', 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f', 'EMPLOYEE', TRUE);

-- ============================================================================
-- 4. EMPLOYEES (28 Real Employees with Managerial Hierarchy)
-- ============================================================================
-- Level 1: CEO (Root, manager_id is NULL)
INSERT INTO employees (employee_id, user_id, emp_code, first_name, last_name, email, phone, date_of_birth, gender, department_id, designation_id, manager_id, joining_date, status, bank_account_no, bank_name, ifsc_code, pan_number)
OVERRIDING SYSTEM VALUE VALUES
(1, 4, 'EMP001', 'Vikram', 'Aditya', 'vikram.aditya@enterprise.com', '+919876500001', '1978-04-12', 'M', 1, 1, NULL, '2020-01-15', 'ACTIVE', '910010023456789', 'HDFC Bank', 'HDFC0001234', 'ABCDE1234F');

-- Level 2: Executives reporting to CEO (1)
INSERT INTO employees (employee_id, user_id, emp_code, first_name, last_name, email, phone, date_of_birth, gender, department_id, designation_id, manager_id, joining_date, status, bank_account_no, bank_name, ifsc_code, pan_number)
OVERRIDING SYSTEM VALUE VALUES
(2, 5, 'EMP002', 'Aarav', 'Sharma',    'aarav.sharma@enterprise.com',   '+919876500002', '1982-08-23', 'M', 2, 2,  1, '2020-03-01', 'ACTIVE', '910010023456790', 'ICICI Bank', 'ICIC0000456', 'BCDEF2345G'),
(3, 6, 'EMP003', 'Priya', 'Sundaram',  'priya.sundaram@enterprise.com', '+919876500003', '1984-11-15', 'F', 3, 8,  1, '2020-05-10', 'ACTIVE', '910010023456791', 'State Bank of India', 'SBIN0000789', 'CDEFG3456H'),
(4, 7, 'EMP004', 'Rajesh', 'Nambiar',  'rajesh.nambiar@enterprise.com', '+919876500004', '1981-02-28', 'M', 4, 10, 1, '2020-04-01', 'ACTIVE', '910010023456792', 'Axis Bank', 'UTIB0000123', 'DEFGH4567I'),
(5, 8, 'EMP005', 'Meera', 'Kapoor',    'meera.kapoor@enterprise.com',   '+919876500005', '1986-06-19', 'F', 5, 13, 1, '2021-01-10', 'ACTIVE', '910010023456793', 'Kotak Mahindra', 'KKBK0000321', 'EFGHI5678J'),
(6, 9, 'EMP006', 'Rohan', 'Verma',     'rohan.verma@enterprise.com',    '+919876500006', '1985-09-05', 'M', 6, 15, 1, '2021-02-15', 'ACTIVE', '910010023456794', 'HDFC Bank', 'HDFC0001234', 'FGHIJ6789K');

-- Level 3: Managers & Leads
INSERT INTO employees (employee_id, user_id, emp_code, first_name, last_name, email, phone, date_of_birth, gender, department_id, designation_id, manager_id, joining_date, status, bank_account_no, bank_name, ifsc_code, pan_number)
OVERRIDING SYSTEM VALUE VALUES
(7, 10, 'EMP007', 'Siddharth', 'Gupta', 'siddharth.gupta@enterprise.com', '+919876500007', '1988-12-04', 'M', 2, 3,  2, '2021-06-01', 'ACTIVE', '910010023456795', 'ICICI Bank', 'ICIC0000456', 'GHIJK7890L'),
(8, 11, 'EMP008', 'Ananya', 'Roy',      'ananya.roy@enterprise.com',      '+919876500008', '1989-03-21', 'F', 2, 4,  2, '2021-07-15', 'ACTIVE', '910010023456796', 'HDFC Bank', 'HDFC0001234', 'HIJKL8901M'),
(9, 12, 'EMP009', 'Kavita', 'Krishnan', 'kavita.krishnan@enterprise.com', '+919876500009', '1990-07-11', 'F', 3, 9,  3, '2021-08-01', 'ACTIVE', '910010023456797', 'State Bank of India', 'SBIN0000789', 'IJKLM9012N'),
(10, 13, 'EMP010', 'Gautam', 'Iyer',    'gautam.iyer@enterprise.com',     '+919876500010', '1987-10-30', 'M', 4, 11, 4, '2021-09-01', 'ACTIVE', '910010023456798', 'Axis Bank', 'UTIB0000123', 'JKLMN0123O'),
(11, 14, 'EMP011', 'Tarun', 'Bansal',   'tarun.bansal@enterprise.com',    '+919876500011', '1991-05-18', 'M', 5, 14, 5, '2021-11-01', 'ACTIVE', '910010023456799', 'Kotak Mahindra', 'KKBK0000321', 'KLMNO1234P');

-- Level 4: Senior Engineers & Specialists
INSERT INTO employees (employee_id, user_id, emp_code, first_name, last_name, email, phone, date_of_birth, gender, department_id, designation_id, manager_id, joining_date, status, bank_account_no, bank_name, ifsc_code, pan_number)
OVERRIDING SYSTEM VALUE VALUES
(12, 15, 'EMP012', 'Arjun', 'Reddy',     'arjun.reddy@enterprise.com',     '+919876500012', '1992-01-25', 'M', 2, 5,  7, '2022-01-10', 'ACTIVE', '910010023456800', 'HDFC Bank', 'HDFC0001234', 'LMNOP2345Q'),
(13, 16, 'EMP013', 'Sneha', 'Patil',     'sneha.patil@enterprise.com',     '+919876500013', '1993-04-14', 'F', 2, 5,  7, '2022-02-01', 'ACTIVE', '910010023456801', 'ICICI Bank', 'ICIC0000456', 'MNOPQ3456R'),
(14, 17, 'EMP014', 'Nikhil', 'Joshi',    'nikhil.joshi@enterprise.com',    '+919876500014', '1992-09-08', 'M', 2, 5,  8, '2022-03-15', 'ACTIVE', '910010023456802', 'State Bank of India', 'SBIN0000789', 'NOPQR4567S'),
(15, 18, 'EMP015', 'Divya', 'Menon',     'divya.menon@enterprise.com',     '+919876500015', '1994-11-22', 'F', 2, 7,  7, '2022-04-01', 'ACTIVE', '910010023456803', 'Axis Bank', 'UTIB0000123', 'OPQRS5678T'),
(16, 19, 'EMP016', 'Rahul', 'Deshmukh',  'rahul.deshmukh@enterprise.com',  '+919876500016', '1993-06-30', 'M', 6, 15, 6, '2022-05-15', 'ACTIVE', '910010023456804', 'HDFC Bank', 'HDFC0001234', 'PQRST6789U'),
(17, 20, 'EMP017', 'Deepak', 'Chawla',   'deepak.chawla@enterprise.com',   '+919876500017', '1994-08-17', 'M', 4, 12, 10, '2022-06-01', 'ACTIVE', '910010023456805', 'Kotak Mahindra', 'KKBK0000321', 'QRSTU7890V');

-- Level 5: Engineers & Associates
INSERT INTO employees (employee_id, user_id, emp_code, first_name, last_name, email, phone, date_of_birth, gender, department_id, designation_id, manager_id, joining_date, status, bank_account_no, bank_name, ifsc_code, pan_number)
OVERRIDING SYSTEM VALUE VALUES
(18, 21, 'EMP018', 'Pooja', 'Saxena',    'pooja.saxena@enterprise.com',    '+919876500018', '1996-03-12', 'F', 2, 6, 12, '2022-08-01', 'ACTIVE', '910010023456806', 'HDFC Bank', 'HDFC0001234', 'RSTUV8901W'),
(19, 22, 'EMP019', 'Amit', 'Trivedi',    'amit.trivedi@enterprise.com',    '+919876500019', '1995-12-05', 'M', 2, 6, 12, '2022-09-15', 'ACTIVE', '910010023456807', 'ICICI Bank', 'ICIC0000456', 'STUVW9012X'),
(20, 23, 'EMP020', 'Neha', 'Bhatia',     'neha.bhatia@enterprise.com',     '+919876500020', '1997-02-19', 'F', 2, 6, 13, '2023-01-10', 'ACTIVE', '910010023456808', 'State Bank of India', 'SBIN0000789', 'TUVWX0123Y'),
(21, 24, 'EMP021', 'Karan', 'Malhotra',  'karan.malhotra@enterprise.com',  '+919876500021', '1996-07-28', 'M', 2, 6, 14, '2023-02-01', 'ACTIVE', '910010023456809', 'Axis Bank', 'UTIB0000123', 'UVWXY1234Z'),
(22, 25, 'EMP022', 'Ritu', 'Chopra',     'ritu.chopra@enterprise.com',     '+919876500022', '1998-05-14', 'F', 2, 7, 15, '2023-04-15', 'ACTIVE', '910010023456810', 'HDFC Bank', 'HDFC0001234', 'VWXYZ2345A'),
(23, 26, 'EMP023', 'Varun', 'Kashyap',   'varun.kashyap@enterprise.com',   '+919876500023', '1997-10-09', 'M', 3, 9,  9, '2023-06-01', 'ACTIVE', '910010023456811', 'Kotak Mahindra', 'KKBK0000321', 'WXYZA3456B'),
(24, 27, 'EMP024', 'Simran', 'Kaur',     'simran.kaur@enterprise.com',     '+919876500024', '1998-01-30', 'F', 5, 14, 11, '2023-07-15', 'ACTIVE', '910010023456812', 'ICICI Bank', 'ICIC0000456', 'XYZAB4567C'),
(25, 28, 'EMP025', 'Harsh', 'Vardhan',   'harsh.vardhan@enterprise.com',   '+919876500025', '1996-09-16', 'M', 6, 15, 16, '2023-09-01', 'ACTIVE', '910010023456813', 'HDFC Bank', 'HDFC0001234', 'YZABC5678D'),
-- Edge case test records:
(26, 29, 'EMP026', 'Manoj', 'Pandey',    'manoj.pandey@enterprise.com',    '+919876500026', '1995-04-03', 'M', 2, 6, 13, '2023-10-01', 'ON_LEAVE', '910010023456814', 'Axis Bank', 'UTIB0000123', 'ZABCD6789E'),
(27, 30, 'EMP027', 'Swati', 'Mishra',    'swati.mishra@enterprise.com',    '+919876500027', '1997-11-25', 'F', 2, 6, 14, '2023-11-01', 'ACTIVE',   '910010023456815', 'State Bank of India', 'SBIN0000789', 'ABCDE7890F'),
(28, 31, 'EMP028', 'Dinesh', 'Rathore',  'dinesh.rathore@enterprise.com',  '+919876500028', '1990-12-10', 'M', 2, 5,  7, '2021-04-01', 'TERMINATED', '910010023456816', 'HDFC Bank', 'HDFC0001234', 'BCDEF8901G');

-- Set exit date for terminated employee
UPDATE employees SET exit_date = '2025-09-30' WHERE employee_id = 28;

-- Advance employee identity sequence past 28
SELECT setval(pg_get_serial_sequence('employees', 'employee_id'), 28);

-- ============================================================================
-- 5. SALARY STRUCTURES
-- Demonstrates structured compensation + flexible JSONB allowances
-- ============================================================================
INSERT INTO salary_structures (employee_id, basic_pay, hra, da, special_allowance, pf_percentage, professional_tax, insurance_deduction, flexible_allowances, effective_from, effective_to, is_current) VALUES
-- CEO
(1, 250000.00, 100000.00, 50000.00, 50000.00, 12.0, 200.00, 2500.00, '{"executive_perk": 25000, "fuel": 10000, "wellness": 5000}', '2025-01-01', NULL, TRUE),
-- VPs & Directors
(2, 160000.00,  64000.00, 32000.00, 34000.00, 12.0, 200.00, 2000.00, '{"broadband": 2000, "fuel": 8000, "wellness": 3000}', '2025-01-01', NULL, TRUE),
(3, 110000.00,  44000.00, 22000.00, 24000.00, 12.0, 200.00, 1500.00, '{"broadband": 1500, "books": 1000, "wellness": 2500}', '2025-01-01', NULL, TRUE),
(4, 150000.00,  60000.00, 30000.00, 30000.00, 12.0, 200.00, 2000.00, '{"broadband": 2000, "fuel": 7000, "wellness": 3000}', '2025-01-01', NULL, TRUE),
(5, 115000.00,  46000.00, 23000.00, 21000.00, 12.0, 200.00, 1500.00, '{"broadband": 1500, "fuel": 5000, "wellness": 2000}', '2025-01-01', NULL, TRUE),
(6, 110000.00,  44000.00, 22000.00, 24000.00, 12.0, 200.00, 1500.00, '{"broadband": 2000, "fuel": 5000, "cloud_lab": 3000}', '2025-01-01', NULL, TRUE),
-- Managers & Leads
(7,  95000.00,  38000.00, 19000.00, 18000.00, 12.0, 200.00, 1200.00, '{"broadband": 1500, "medical": 2000, "fuel": 4000}', '2025-01-01', NULL, TRUE),
(8, 105000.00,  42000.00, 21000.00, 22000.00, 12.0, 200.00, 1200.00, '{"broadband": 2000, "tech_allowance": 5000}', '2025-01-01', NULL, TRUE),
(9,  45000.00,  18000.00,  9000.00,  8000.00, 12.0, 200.00,  800.00, '{"broadband": 1000, "medical": 1500}', '2025-01-01', NULL, TRUE),
(10, 55000.00,  22000.00, 11000.00, 12000.00, 12.0, 200.00,  800.00, '{"broadband": 1000, "medical": 1500}', '2025-01-01', NULL, TRUE),
(11, 48000.00,  19200.00,  9600.00,  8200.00, 12.0, 200.00,  800.00, '{"broadband": 1000, "travel": 2500}', '2025-01-01', NULL, TRUE),
-- Senior Engineers & Specialists
(12, 70000.00,  28000.00, 14000.00, 13000.00, 12.0, 200.00, 1000.00, '{"broadband": 1500, "medical": 2000, "certifications": 2500}', '2025-01-01', NULL, TRUE),
(13, 68000.00,  27200.00, 13600.00, 13200.00, 12.0, 200.00, 1000.00, '{"broadband": 1500, "medical": 2000}', '2025-01-01', NULL, TRUE),
(14, 65000.00,  26000.00, 13000.00, 12000.00, 12.0, 200.00, 1000.00, '{"broadband": 1500, "medical": 2000}', '2025-01-01', NULL, TRUE),
(15, 45000.00,  18000.00,  9000.00,  8000.00, 12.0, 200.00,  800.00, '{"broadband": 1000, "medical": 1500}', '2025-01-01', NULL, TRUE),
(16, 75000.00,  30000.00, 15000.00, 15000.00, 12.0, 200.00, 1000.00, '{"broadband": 2000, "cloud_cert": 3000}', '2025-01-01', NULL, TRUE),
(17, 35000.00,  14000.00,  7000.00,  6000.00, 12.0, 200.00,  600.00, '{"broadband": 1000, "medical": 1000}', '2025-01-01', NULL, TRUE),
-- Engineers & Associates
(18, 42000.00,  16800.00,  8400.00,  7800.00, 12.0, 200.00,  600.00, '{"broadband": 1000, "medical": 1000}', '2025-01-01', NULL, TRUE),
(19, 40000.00,  16000.00,  8000.00,  8000.00, 12.0, 200.00,  600.00, '{"broadband": 1000, "medical": 1000}', '2025-01-01', NULL, TRUE),
(20, 38000.00,  15200.00,  7600.00,  7200.00, 12.0, 200.00,  600.00, '{"broadband": 1000, "medical": 1000}', '2025-01-01', NULL, TRUE),
(21, 38000.00,  15200.00,  7600.00,  7200.00, 12.0, 200.00,  600.00, '{"broadband": 1000, "medical": 1000}', '2025-01-01', NULL, TRUE),
(22, 35000.00,  14000.00,  7000.00,  6000.00, 12.0, 200.00,  600.00, '{"broadband": 1000, "medical": 1000}', '2025-01-01', NULL, TRUE),
(23, 32000.00,  12800.00,  6400.00,  5800.00, 12.0, 200.00,  500.00, '{"broadband": 1000, "medical": 1000}', '2025-01-01', NULL, TRUE),
(24, 32000.00,  12800.00,  6400.00,  5800.00, 12.0, 200.00,  500.00, '{"broadband": 1000, "medical": 1000}', '2025-01-01', NULL, TRUE),
(25, 45000.00,  18000.00,  9000.00,  8000.00, 12.0, 200.00,  800.00, '{"broadband": 1500, "medical": 1000}', '2025-01-01', NULL, TRUE),
(26, 36000.00,  14400.00,  7200.00,  6400.00, 12.0, 200.00,  600.00, '{"broadband": 1000, "medical": 1000}', '2025-01-01', NULL, TRUE),
(27, 36000.00,  14400.00,  7200.00,  6400.00, 12.0, 200.00,  600.00, '{"broadband": 1000, "medical": 1000}', '2025-01-01', NULL, TRUE),
(28, 60000.00,  24000.00, 12000.00, 10000.00, 12.0, 200.00, 1000.00, '{"broadband": 1000}', '2024-01-01', '2025-09-30', FALSE);

-- ============================================================================
-- 6. HOLIDAYS MASTER (Covering Q4 2025 and Q1 2026)
-- ============================================================================
INSERT INTO holidays (holiday_date, holiday_name, is_optional) VALUES
('2025-10-02', 'Gandhi Jayanti', FALSE),
('2025-10-21', 'Dussehra / Vijaya Dashami', FALSE),
('2025-11-01', 'Diwali Festival', FALSE),
('2025-11-02', 'Govardhan Puja', TRUE),
('2025-12-25', 'Christmas Day', FALSE),
('2026-01-01', 'New Year''s Day', FALSE),
('2026-01-26', 'Republic Day', FALSE),
('2026-03-04', 'Holi Festival', FALSE);

-- ============================================================================
-- 7. LEAVE TYPES & ALLOCATIONS
-- ============================================================================
INSERT INTO leave_types (leave_code, leave_name, annual_quota, is_paid, carry_forward) VALUES
('CL',  'Casual Leave',          12, TRUE,  FALSE),
('SL',  'Sick Leave',            10, TRUE,  TRUE),
('PL',  'Privilege / Annual',    15, TRUE,  TRUE),
('LWP', 'Leave Without Pay',      0, FALSE, FALSE);

-- Populate 2025 & 2026 Leave Balances for all active employees
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT employee_id FROM employees WHERE status != 'TERMINATED' LOOP
        -- Year 2025
        INSERT INTO leave_balances (employee_id, leave_type_id, year, total_allocated, leaves_used) VALUES
        (r.employee_id, 1, 2025, 12.0, 4.0),
        (r.employee_id, 2, 2025, 10.0, 2.0),
        (r.employee_id, 3, 2025, 15.0, 5.0),
        (r.employee_id, 4, 2025, 0.0,  0.0);

        -- Year 2026
        INSERT INTO leave_balances (employee_id, leave_type_id, year, total_allocated, leaves_used) VALUES
        (r.employee_id, 1, 2026, 12.0, 1.0),
        (r.employee_id, 2, 2026, 10.0, 0.0),
        (r.employee_id, 3, 2026, 15.0, 2.0),
        (r.employee_id, 4, 2026, 0.0,  0.0);
    END LOOP;
END $$;

-- Sample Leave Applications
INSERT INTO leave_applications (employee_id, leave_type_id, start_date, end_date, days_count, status, approved_by, reason, applied_at, decided_at) VALUES
(12, 1, '2025-10-15', '2025-10-16', 2.0, 'APPROVED', 7, 'Family festival celebration', '2025-10-10 09:30:00+05:30', '2025-10-11 11:00:00+05:30'),
(13, 2, '2025-11-12', '2025-11-13', 2.0, 'APPROVED', 7, 'Viral fever and medical rest', '2025-11-12 08:15:00+05:30', '2025-11-12 10:00:00+05:30'),
(18, 3, '2025-12-26', '2025-12-29', 3.0, 'APPROVED', 12, 'Year end holiday trip', '2025-12-15 14:00:00+05:30', '2025-12-16 16:30:00+05:30'),
(20, 1, '2026-02-16', '2026-02-17', 2.0, 'APPROVED', 13, 'Personal emergency', '2026-02-14 10:00:00+05:30', '2026-02-14 12:00:00+05:30'),
(21, 1, '2026-03-25', '2026-03-26', 2.0, 'PENDING',  14, 'Attending family wedding', '2026-03-15 11:30:00+05:30', NULL);

-- ============================================================================
-- 8. SYSTEM CONFIGURATION & TAX SLABS
-- ============================================================================
INSERT INTO payroll_config (config_key, config_value, description) VALUES
('STANDARD_DAILY_HOURS', '8', 'Standard regular work hours per workday'),
('OVERTIME_HOURLY_MULTIPLIER', '1.5', 'Statutory multiplier on hourly rate for overtime'),
('PF_EMPLOYER_CONTRIBUTION_PCT', '12.0', 'Employer matching Provident Fund contribution rate'),
('DEFAULT_TAX_REGIME', 'NEW', 'Default income tax regime for annualized projection'),
('COMPANY_NAME', 'Enterprise Technologies Ltd.', 'Legal entity name printed on payslips');

-- New Tax Regime Slabs (FY 2025-2026)
INSERT INTO tax_slabs (financial_year, regime, min_income, max_income, tax_rate_percent, cess_percent) VALUES
('2025-2026', 'NEW', 0.00,       300000.00,  0.0, 4.0),
('2025-2026', 'NEW', 300000.00,  600000.00,  5.0, 4.0),
('2025-2026', 'NEW', 600000.00,  900000.00, 10.0, 4.0),
('2025-2026', 'NEW', 900000.00, 1200000.00, 15.0, 4.0),
('2025-2026', 'NEW', 1200000.00, 1500000.00, 20.0, 4.0),
('2025-2026', 'NEW', 1500000.00, NULL,       30.0, 4.0);

-- ============================================================================
-- 9. REALISTIC ATTENDANCE GENERATOR (6 MONTHS: OCT 2025 - MAR 2026)
-- Generates daily attendance, weekends, holidays, overtime, and occasional leaves
-- ============================================================================
DO $$
DECLARE
    v_curr_date DATE;
    v_start_date DATE := '2025-10-01';
    v_end_date DATE := '2026-03-31';
    v_emp RECORD;
    v_dow INT;
    v_is_holiday BOOLEAN;
    v_rand FLOAT;
    v_status attendance_status;
    v_in TIME;
    v_out TIME;
    v_ot NUMERIC(4,2);
BEGIN
    FOR v_emp IN SELECT employee_id, joining_date, status FROM employees WHERE employee_id <= 27 LOOP
        v_curr_date := v_start_date;
        
        WHILE v_curr_date <= v_end_date LOOP
            -- Only record attendance if employee was already joined
            IF v_curr_date >= v_emp.joining_date THEN
                v_dow := EXTRACT(DOW FROM v_curr_date);
                
                SELECT EXISTS(SELECT 1 FROM holidays WHERE holiday_date = v_curr_date AND NOT is_optional) 
                INTO v_is_holiday;

                IF v_dow = 0 THEN
                    -- Sunday: Weekend
                    INSERT INTO attendance (employee_id, attendance_date, check_in, check_out, status, overtime_hours)
                    VALUES (v_emp.employee_id, v_curr_date, NULL, NULL, 'WEEKEND', 0.00)
                    ON CONFLICT DO NOTHING;
                ELSIF v_is_holiday THEN
                    -- Official Company Holiday
                    INSERT INTO attendance (employee_id, attendance_date, check_in, check_out, status, overtime_hours)
                    VALUES (v_emp.employee_id, v_curr_date, NULL, NULL, 'HOLIDAY', 0.00)
                    ON CONFLICT DO NOTHING;
                ELSE
                    -- Standard working day with realistic probabilistic distribution
                    v_rand := random();
                    v_ot := 0.00;

                    IF v_rand < 0.90 THEN
                        -- 90% Present
                        v_status := 'PRESENT';
                        v_in := ('09:00:00'::TIME + (random() * INTERVAL '25 minutes'))::TIME;
                        -- Some employees log 1 to 2.5 hours overtime
                        IF (v_emp.employee_id IN (12, 13, 14, 16, 21, 25)) AND (v_rand < 0.25) THEN
                            v_ot := ROUND((1.0 + random() * 2.0)::NUMERIC, 2);
                            v_out := ('18:00:00'::TIME + (v_ot * INTERVAL '1 hour'))::TIME;
                        ELSE
                            v_out := ('18:00:00'::TIME + (random() * INTERVAL '15 minutes'))::TIME;
                        END IF;
                    ELSIF v_rand < 0.95 THEN
                        -- 5% Half Day
                        v_status := 'HALF_DAY';
                        v_in := '09:15:00';
                        v_out := '13:45:00';
                    ELSIF v_rand < 0.98 THEN
                        -- 3% Approved Leave
                        v_status := 'ON_LEAVE';
                        v_in := NULL;
                        v_out := NULL;
                    ELSE
                        -- 2% Unplanned Absence (Loss of Pay)
                        v_status := 'ABSENT';
                        v_in := NULL;
                        v_out := NULL;
                    END IF;

                    INSERT INTO attendance (employee_id, attendance_date, check_in, check_out, status, overtime_hours)
                    VALUES (v_emp.employee_id, v_curr_date, v_in, v_out, v_status, v_ot)
                    ON CONFLICT DO NOTHING;
                END IF;
            END IF;

            v_curr_date := v_curr_date + 1;
        END LOOP;
    END LOOP;
END $$;

-- ============================================================================
-- 10. BATCH PAYROLL EXECUTION (6 MONTHS OF HISTORICAL RUNS & PAYSLIPS)
-- Executes process_monthly_payroll, approve_payroll_run, and disburse_payroll
-- ============================================================================

-- Month 1: October 2025 (Finalized & Paid)
CALL process_monthly_payroll(2025, 10, 3);
CALL approve_payroll_run(1);
CALL disburse_payroll(1, 'HDFC-SAL-OCT25');

-- Month 2: November 2025 (Finalized & Paid)
CALL process_monthly_payroll(2025, 11, 3);
CALL approve_payroll_run(2);
CALL disburse_payroll(2, 'HDFC-SAL-NOV25');

-- Month 3: December 2025 (Finalized & Paid)
CALL process_monthly_payroll(2025, 12, 3);
CALL approve_payroll_run(3);
CALL disburse_payroll(3, 'HDFC-SAL-DEC25');

-- Month 4: January 2026 (Finalized & Paid)
CALL process_monthly_payroll(2026, 1, 3);
CALL approve_payroll_run(4);
CALL disburse_payroll(4, 'HDFC-SAL-JAN26');

-- Month 5: February 2026 (Finalized & Paid)
CALL process_monthly_payroll(2026, 2, 3);
CALL approve_payroll_run(5);
CALL disburse_payroll(5, 'HDFC-SAL-FEB26');

-- Month 6: March 2026 (Processed, ready for approval / live demo in presentation)
CALL process_monthly_payroll(2026, 3, 3);

-- Refresh Materialized View to sync pre-computed metrics
CALL refresh_payroll_analytics_mv();
