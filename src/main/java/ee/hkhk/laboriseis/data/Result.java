package ee.hkhk.laboriseis.data;

import java.time.Instant;

/** Üks kontrolli tulemus. */
public record Result(String lab, String check, String status, String message, String host, Instant receivedAt) {
}
