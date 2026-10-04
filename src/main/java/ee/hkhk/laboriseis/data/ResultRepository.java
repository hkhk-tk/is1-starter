package ee.hkhk.laboriseis.data;

import java.sql.Timestamp;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/** Tulemuste salvestamine ja päringud. */
@Repository
public class ResultRepository {

    private static final String LATEST = """
            SELECT r.*, ROW_NUMBER() OVER (
                PARTITION BY r.student_id, r.lab_code, r.check_name
                ORDER BY r.received_at DESC, r.id DESC) AS rn
            FROM result r
            """;

    private final JdbcTemplate jdbc;

    public ResultRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public void insert(long studentId, Result r) {
        jdbc.update("""
                INSERT INTO result (student_id, lab_code, check_name, status, message, host, received_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                studentId, r.lab(), r.check(), r.status(), r.message(), r.host(), Timestamp.from(r.receivedAt()));
    }

    /** Iga õppija × labori kohta OK/FAIL arv kontrollide viimaste tulemuste põhjal. */
    public List<SummaryRow> summary() {
        return jdbc.query("SELECT s.name, s.github, x.lab_code,"
                        + " SUM(x.status = 'OK') AS ok, SUM(x.status = 'FAIL') AS fail, MAX(x.received_at) AS last"
                        + " FROM (" + LATEST + ") x JOIN student s ON s.id = x.student_id"
                        + " WHERE x.rn = 1"
                        + " GROUP BY s.id, s.name, s.github, x.lab_code"
                        + " ORDER BY s.name, x.lab_code",
                (rs, i) -> new SummaryRow(rs.getString(1), rs.getString(2), rs.getString(3),
                        rs.getInt(4), rs.getInt(5), rs.getTimestamp(6).toInstant()));
    }

    /** Õppija kõigi kontrollide viimased tulemused. */
    public List<Result> latestForStudent(long studentId) {
        return jdbc.query("SELECT x.lab_code, x.check_name, x.status, x.message, x.host, x.received_at"
                        + " FROM (" + LATEST + ") x WHERE x.rn = 1 AND x.student_id = ?"
                        + " ORDER BY x.lab_code, x.check_name",
                (rs, i) -> new Result(rs.getString(1), rs.getString(2), rs.getString(3),
                        rs.getString(4), rs.getString(5), rs.getTimestamp(6).toInstant()),
                studentId);
    }

    public void ping() {
        jdbc.queryForObject("SELECT 1", Integer.class);
    }
}
