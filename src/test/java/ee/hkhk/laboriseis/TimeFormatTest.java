package ee.hkhk.laboriseis;

import static org.assertj.core.api.Assertions.assertThat;

import ee.hkhk.laboriseis.web.TimeFormat;
import java.time.Instant;
import org.junit.jupiter.api.Test;

/** Ajad näidatakse Eesti ajas, sõltumata serveri ajavööndist (konteineris on see tavaliselt UTC). */
class TimeFormatTest {

    private final TimeFormat fmt = new TimeFormat();

    @Test
    void winterTimeIsUtcPlusTwo() {
        // 31.10.2026 = kursuse esimene laupäev, suveaeg on lõppenud 25.10
        assertThat(fmt.time(Instant.parse("2026-10-31T09:00:00Z"))).isEqualTo("31.10 11:00:00");
    }

    @Test
    void summerTimeIsUtcPlusThree() {
        assertThat(fmt.time(Instant.parse("2026-07-01T09:00:00Z"))).isEqualTo("01.07 12:00:00");
    }

    @Test
    void missingTimeIsDash() {
        assertThat(fmt.time(null)).isEqualTo("-");
    }
}
