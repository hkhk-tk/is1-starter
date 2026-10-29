-- Labori seis: andmebaasi skeem (MariaDB 10.5+: AlmaLinux 9 AppStream; Ubuntu 24.04 10.11; konteiner 11.4)
CREATE TABLE IF NOT EXISTS course (
    id    INT AUTO_INCREMENT PRIMARY KEY,
    code  VARCHAR(32)  NOT NULL UNIQUE,
    name  VARCHAR(200) NOT NULL
);

CREATE TABLE IF NOT EXISTS student (
    id        INT AUTO_INCREMENT PRIMARY KEY,
    course_id INT          NOT NULL,
    name      VARCHAR(200) NOT NULL,
    github    VARCHAR(64)  NOT NULL UNIQUE,
    token     VARCHAR(64)  NOT NULL UNIQUE,
    CONSTRAINT fk_student_course FOREIGN KEY (course_id) REFERENCES course (id)
);

CREATE TABLE IF NOT EXISTS lab (
    id        INT AUTO_INCREMENT PRIMARY KEY,
    course_id INT          NOT NULL,
    code      VARCHAR(32)  NOT NULL,
    title     VARCHAR(200) NOT NULL,
    day       INT          NOT NULL,
    UNIQUE KEY uq_lab (course_id, code),
    CONSTRAINT fk_lab_course FOREIGN KEY (course_id) REFERENCES course (id)
);

CREATE TABLE IF NOT EXISTS result (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    student_id  INT          NOT NULL,
    lab_code    VARCHAR(32)  NOT NULL,
    check_name  VARCHAR(64)  NOT NULL,
    status      ENUM('OK', 'FAIL') NOT NULL,
    message     VARCHAR(500),
    host        VARCHAR(64),
    received_at TIMESTAMP(3) NOT NULL,
    KEY idx_result_latest (student_id, lab_code, check_name, received_at),
    CONSTRAINT fk_result_student FOREIGN KEY (student_id) REFERENCES student (id)
);
