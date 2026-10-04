package ee.hkhk.laboriseis.queue;

import java.time.Instant;

/** Järjekorda pandav sõnum. */
public record ResultEvent(long studentId, String lab, String check, String status, String message, String host,
                          Instant receivedAt) {
}
