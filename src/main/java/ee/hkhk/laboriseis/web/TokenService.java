package ee.hkhk.laboriseis.web;

import ee.hkhk.laboriseis.data.Student;
import ee.hkhk.laboriseis.data.StudentRepository;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

/** Tokenite kontroll: koolitaja token keskkonnamuutujast, õppija token andmebaasist. */
@Service
public class TokenService {

    private final StudentRepository students;
    private final String teacherToken;
    /** Tuntud tokenid mälus: POST töötab edasi ka siis, kui andmebaas korraks ei vasta. */
    private final Map<String, Student> known = new ConcurrentHashMap<>();

    public TokenService(StudentRepository students, @Value("${app.teacher-token:}") String teacherToken) {
        this.students = students;
        this.teacherToken = teacherToken;
    }

    public boolean isTeacher(String token) {
        if (token == null || teacherToken.isBlank()) {
            return false;
        }
        return MessageDigest.isEqual(token.getBytes(StandardCharsets.UTF_8),
                teacherToken.getBytes(StandardCharsets.UTF_8));
    }

    public Optional<Student> student(String token) {
        if (token == null || token.isBlank()) {
            return Optional.empty();
        }
        Student cached = known.get(token);
        if (cached != null) {
            return Optional.of(cached);
        }
        Optional<Student> found = students.findByToken(token);
        found.ifPresent(s -> known.put(token, s));
        return found;
    }

    public Optional<Student> studentByGithub(String github) {
        Student cached = known.get("gh:" + github);
        if (cached != null) {
            return Optional.of(cached);
        }
        Optional<Student> found = students.findByGithub(github);
        found.ifPresent(s -> known.put("gh:" + github, s));
        return found;
    }

    /** "Bearer abc" → "abc". */
    public static String bearer(String header) {
        if (header == null || !header.startsWith("Bearer ")) {
            return null;
        }
        return header.substring("Bearer ".length()).trim();
    }
}
