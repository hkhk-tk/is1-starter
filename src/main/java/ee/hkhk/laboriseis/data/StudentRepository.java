package ee.hkhk.laboriseis.data;

import java.util.List;
import java.util.Optional;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

/** Õppijate päringud. */
@Repository
public class StudentRepository {

    private static final String SELECT = """
            SELECT s.id, s.name, s.github, c.code
            FROM student s JOIN course c ON c.id = s.course_id
            """;

    private static final RowMapper<Student> MAPPER = (rs, i) ->
            new Student(rs.getLong(1), rs.getString(2), rs.getString(3), rs.getString(4));

    private final JdbcTemplate jdbc;

    public StudentRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public Optional<Student> findByToken(String token) {
        List<Student> rows = jdbc.query(SELECT + " WHERE s.token = ?", MAPPER, token);
        return rows.stream().findFirst();
    }

    public Optional<Student> findByGithub(String github) {
        List<Student> rows = jdbc.query(SELECT + " WHERE s.github = ?", MAPPER, github);
        return rows.stream().findFirst();
    }
}
