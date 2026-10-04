package ee.hkhk.laboriseis.web;

import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;

/** Aja kuvamine Eesti ajas mallides: {@code ${fmt.time(x)}}. */
public final class TimeFormat {

    private static final DateTimeFormatter FMT =
            DateTimeFormatter.ofPattern("dd.MM HH:mm:ss").withZone(ZoneId.of("Europe/Tallinn"));

    public String time(Instant instant) {
        return instant == null ? "-" : FMT.format(instant);
    }
}
