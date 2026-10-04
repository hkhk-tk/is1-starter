-- Näidisandmed. Päris õppijad lisatakse scripts/add-students.sh abil.
INSERT IGNORE INTO course (id, code, name) VALUES
    (1, 'IS1-26', 'IT-infrastruktuuri automatiseerimine I');

INSERT IGNORE INTO lab (course_id, code, title, day) VALUES
    (1, 'lab-01', 'Bash', 1),
    (1, 'lab-02', 'Ansible', 2),
    (1, 'lab-03', 'Docker', 3),
    (1, 'lab-04', 'OpenTofu', 4),
    (1, 'lab-05', 'GitHub Actions', 5),
    (1, 'lab-06', 'Jenkins', 6),
    (1, 'lab-07', 'Kubernetes', 7);

-- Demotokenid: kasuta ainult laboris, mitte päris kursusel.
INSERT IGNORE INTO student (course_id, name, github, token) VALUES
    (1, 'Kati Kask', 'demo-kati', 'demo-kati-token'),
    (1, 'Mati Maasikas', 'demo-mati', 'demo-mati-token'),
    (1, 'Juku Juurikas', 'demo-juku', 'demo-juku-token');
