-- =========================================
-- Project: Demonstrating SQL Joins
-- Author: Vidhi
-- =========================================

-- Step 1: Drop tables if they already exist (for clean re-runs)
DROP TABLE IF EXISTS Students;
DROP TABLE IF EXISTS Courses;

-- Step 2: Creating tables
CREATE TABLE Students (
    student_id INT PRIMARY KEY,
    name VARCHAR(50),
    course_id INT
);

CREATE TABLE Courses (
    course_id INT PRIMARY KEY,
    course_name VARCHAR(50)
);

-- Step 3: Inserting sample data
INSERT INTO Students (student_id, name, course_id) VALUES
(1, 'Aditi', 101),
(2, 'Rahul', 102),
(3, 'Sneha', 103),
(4, 'Karan', NULL),
(5, 'Meera', 104),
(6, 'Arjun', 105),
(7, 'Priya', 106),
(8, 'Vikas', NULL),
(9, 'Neha', 102),
(10, 'Rohan', 107);

INSERT INTO Courses (course_id, course_name) VALUES
(101, 'Math'),
(102, 'Science'),
(103, 'English'),
(104, 'History'),
(105, 'Economics'),
(106, 'Computer Science'),
(108, 'Philosophy'),
(109, 'Art');

-- Step 4: Demonstrate Joins

-- INNER JOIN: Students with valid courses
SELECT s.student_id, s.name, c.course_name
FROM Students s
INNER JOIN Courses c
ON s.course_id = c.course_id;

-- LEFT JOIN: All students, even if no course
SELECT s.student_id, s.name, c.course_name
FROM Students s
LEFT JOIN Courses c
ON s.course_id = c.course_id;

-- RIGHT JOIN: All courses, even if no student
SELECT s.student_id, s.name, c.course_name
FROM Students s
RIGHT JOIN Courses c
ON s.course_id = c.course_id;