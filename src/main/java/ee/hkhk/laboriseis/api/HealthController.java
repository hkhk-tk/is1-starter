package ee.hkhk.laboriseis.api;

import ee.hkhk.laboriseis.cache.CacheService;
import ee.hkhk.laboriseis.data.ResultRepository;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.amqp.rabbit.connection.Connection;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Kaks tervisekontrolli, kaks küsimust.
 *
 * <p>{@code /health}: kas rakendus saab oma tööd teha? Kontrollib sõltuvusi. HTTP 200, kui andmebaas ja järjekord
 * vastavad (vahemälu pole kohustuslik), muidu 503. Kasutavad Docker HEALTHCHECK, compose {@code depends_on},
 * pipeline'i deploy-kontroll, smoke test ja Kubernetes'i readinessProbe.
 *
 * <p>{@code /health/live}: kas protsess elab? Sõltuvusi ei kontrolli, vastab alati 200, kui JVM ja Tomcat
 * töötavad. Kubernetes'i livenessProbe ja startupProbe jaoks: kui db01 kaob, ei tohi app01 restartida,
 * sest restart ei too andmebaasi tagasi.
 */
@RestController
public class HealthController {

    private static final String UP = "UP";
    private static final String DOWN = "DOWN";

    private final ResultRepository db;
    private final ConnectionFactory rabbit;
    private final CacheService cache;

    public HealthController(ResultRepository db, ConnectionFactory rabbit, CacheService cache) {
        this.db = db;
        this.rabbit = rabbit;
        this.cache = cache;
    }

    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        boolean dbUp = check(db::ping);
        boolean queueUp = check(() -> {
            try (Connection c = rabbit.createConnection()) {
                if (!c.isOpen()) {
                    throw new IllegalStateException("ühendus suletud");
                }
            }
        });
        boolean cacheUp = cache.ping();
        boolean up = dbUp && queueUp;

        Map<String, String> body = new LinkedHashMap<>();
        body.put("status", up ? UP : DOWN);
        body.put("db", dbUp ? UP : DOWN);
        body.put("queue", queueUp ? UP : DOWN);
        body.put("cache", cacheUp ? UP : DOWN);
        return ResponseEntity.status(up ? HttpStatus.OK : HttpStatus.SERVICE_UNAVAILABLE)
                .cacheControl(CacheControl.noStore())
                .body(body);
    }

    @GetMapping("/health/live")
    public ResponseEntity<Map<String, String>> live() {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(Map.of("status", UP));
    }

    private static boolean check(Runnable probe) {
        try {
            probe.run();
            return true;
        } catch (RuntimeException e) {
            return false;
        }
    }
}
