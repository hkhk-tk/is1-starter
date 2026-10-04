package ee.hkhk.laboriseis.web;

import ee.hkhk.laboriseis.data.SummaryRow;
import java.util.List;

/** Koondvaade koos infoga, kust andmed tulid. */
public record SummaryView(List<SummaryRow> rows, boolean fromCache, boolean cacheAvailable) {
}
