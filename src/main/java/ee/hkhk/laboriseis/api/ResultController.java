package ee.hkhk.laboriseis.api;

import ee.hkhk.laboriseis.data.Result;
import ee.hkhk.laboriseis.data.ResultRepository;
import ee.hkhk.laboriseis.data.Student;
import ee.hkhk.laboriseis.queue.ResultEvent;
import ee.hkhk.laboriseis.queue.ResultPublisher;
import ee.hkhk.laboriseis.web.TokenService;
import jakarta.validation.Valid;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.springframework.amqp.AmqpException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Kontrollskriptide API. */
@RestController
@RequestMapping("/api/results")
public class ResultController {

    private final TokenService tokens;
    private final ResultPublisher publisher;
    private final ResultRepository results;

    public ResultController(TokenService tokens, ResultPublisher publisher, ResultRepository results) {
        this.tokens = tokens;
        this.publisher = publisher;
        this.results = results;
    }

    @PostMapping
    public ResponseEntity<Map<String, String>> submit(
            @RequestHeader(value = "Authorization", required = false) String auth,
            @Valid @RequestBody ResultRequest req) {
        String token = TokenService.bearer(auth);
        Optional<Student> student;
        if (tokens.isTeacher(token)) {
            if (req.student() == null || req.student().isBlank()) {
                return error(HttpStatus.BAD_REQUEST, "koolitaja tokeniga on väli 'student' kohustuslik");
            }
            student = tokens.studentByGithub(req.student());
        } else {
            student = tokens.student(token);
        }
        if (student.isEmpty()) {
            return error(HttpStatus.UNAUTHORIZED, "vale või puuduv token");
        }
        ResultEvent event = new ResultEvent(student.get().id(), req.lab(), req.check(), req.status(),
                req.message(), req.host(), Instant.now());
        try {
            publisher.publish(event);
        } catch (AmqpException e) {
            return error(HttpStatus.SERVICE_UNAVAILABLE, "järjekord ei vasta");
        }
        return ResponseEntity.status(HttpStatus.ACCEPTED).body(Map.of("status", "accepted"));
    }

    @GetMapping
    public ResponseEntity<List<Result>> list(@RequestHeader(value = "Authorization", required = false) String auth) {
        Optional<Student> student = tokens.student(TokenService.bearer(auth));
        if (student.isEmpty()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }
        return ResponseEntity.ok(results.latestForStudent(student.get().id()));
    }

    private static ResponseEntity<Map<String, String>> error(HttpStatus status, String message) {
        return ResponseEntity.status(status).body(Map.of("error", message));
    }
}
