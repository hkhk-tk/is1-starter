package ee.hkhk.laboriseis.data;

import java.time.Instant;

/** Koondtabeli rida: üks õppija ja üks labor, iga kontrolli viimane tulemus. */
public record SummaryRow(String student, String github, String lab, int ok, int fail, Instant last) {
}
