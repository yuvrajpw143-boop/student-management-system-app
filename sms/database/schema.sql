CREATE DATABASE IF NOT EXISTS student_mgmt; USE student_mgmt;
CREATE TABLE users(id INT AUTO_INCREMENT PRIMARY KEY,name VARCHAR(100) NOT NULL,email VARCHAR(150) NOT NULL UNIQUE,password_hash VARCHAR(255) NOT NULL,created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE students(id INT AUTO_INCREMENT PRIMARY KEY,name VARCHAR(100) NOT NULL,roll_no VARCHAR(30) NOT NULL UNIQUE,class_name VARCHAR(50) NOT NULL,email VARCHAR(150),phone VARCHAR(30),photo_url VARCHAR(500),created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE subjects(id INT AUTO_INCREMENT PRIMARY KEY,name VARCHAR(100) NOT NULL,code VARCHAR(20) NOT NULL UNIQUE);
CREATE TABLE attendance(id INT AUTO_INCREMENT PRIMARY KEY,student_id INT NOT NULL,date DATE NOT NULL,status ENUM('present','absent') NOT NULL,UNIQUE KEY uq(student_id,date),FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE);
CREATE TABLE marks(id INT AUTO_INCREMENT PRIMARY KEY,student_id INT NOT NULL,subject_id INT NOT NULL,exam VARCHAR(50) NOT NULL,score DECIMAL(5,2) NOT NULL,max_score DECIMAL(5,2) NOT NULL DEFAULT 100,FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE,FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE CASCADE);
CREATE TABLE notices(id INT AUTO_INCREMENT PRIMARY KEY,title VARCHAR(150) NOT NULL,body TEXT NOT NULL,created_by INT NULL,created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,FOREIGN KEY(created_by) REFERENCES users(id) ON DELETE SET NULL);
-- Demo data (the admin@school.com / admin123 user is created automatically on first server start)
INSERT INTO students(name,roll_no,class_name,email,phone) VALUES
('Aarav Sharma','R001','10-A','aarav@example.com','9876500001'),('Diya Patel','R002','10-A','diya@example.com','9876500002'),
('Kabir Singh','R003','10-B','kabir@example.com','9876500003'),('Meera Nair','R004','10-B','meera@example.com','9876500004'),
('Rohan Verma','R005','9-A','rohan@example.com','9876500005'),('Sara Khan','R006','9-A','sara@example.com','9876500006');
INSERT INTO subjects(name,code) VALUES('Mathematics','MATH'),('Science','SCI'),('English','ENG'),('History','HIS');
INSERT INTO attendance(student_id,date,status) SELECT id,CURDATE()-INTERVAL d DAY,IF((id*7+d*3)%5<=id%3,'absent','present') FROM students CROSS JOIN (SELECT 0 d UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5) x;
INSERT INTO marks(student_id,subject_id,exam,score,max_score) SELECT st.id,su.id,'Midterm',25+((st.id*23+su.id*17)%70),100 FROM students st CROSS JOIN subjects su;
INSERT INTO notices(title,body) VALUES('Welcome back','Term begins Monday. Please check your timetable.'),('Parent meeting','Parent-teacher meeting this Friday at 4 PM.');
