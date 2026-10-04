package ee.hkhk.laboriseis.web;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import ee.hkhk.laboriseis.cache.CacheService;
import ee.hkhk.laboriseis.data.ResultRepository;
import ee.hkhk.laboriseis.data.SummaryRow;
import java.util.List;
import java.util.Optional;
import org.springframework.stereotype.Service;

/** Koondtabel: esmalt Memcachedist, siis andmebaasist (ja tagasi vahemällu 30 s). */
@Service
public class SummaryService {

    static final String KEY = "summary:all";
    static final int TTL_SECONDS = 30;

    private final ResultRepository results;
    private final CacheService cache;
    private final ObjectMapper json;

    public SummaryService(ResultRepository results, CacheService cache, ObjectMapper json) {
        this.results = results;
        this.cache = cache;
        this.json = json;
    }

    public SummaryView summary() {
        Optional<String> cached = cache.get(KEY);
        if (cached.isPresent()) {
            try {
                List<SummaryRow> rows = json.readValue(cached.get(), new TypeReference<List<SummaryRow>>() { });
                return new SummaryView(rows, true, true);
            } catch (Exception e) {
                cache.delete(KEY);
            }
        }
        List<SummaryRow> rows = results.summary();
        try {
            cache.set(KEY, TTL_SECONDS, json.writeValueAsString(rows));
        } catch (Exception e) {
            // vahemällu kirjutamine ei ole kohustuslik
        }
        return new SummaryView(rows, false, cache.isAvailable());
    }

    public void invalidate() {
        cache.delete(KEY);
    }
}
