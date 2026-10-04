package ee.hkhk.laboriseis;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.json.JsonMapper;
import ee.hkhk.laboriseis.cache.CacheService;
import ee.hkhk.laboriseis.data.ResultRepository;
import ee.hkhk.laboriseis.data.SummaryRow;
import ee.hkhk.laboriseis.web.SummaryService;
import ee.hkhk.laboriseis.web.SummaryView;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class SummaryServiceTest {

    private final ObjectMapper json = JsonMapper.builder().findAndAddModules().build();
    private ResultRepository repo;
    private CacheService cache;
    private SummaryService service;

    private final List<SummaryRow> rows = List.of(
            new SummaryRow("Kati Kask", "katikask", "lab-01", 3, 1, Instant.parse("2026-10-31T09:00:00Z")));

    @BeforeEach
    void setUp() {
        repo = mock(ResultRepository.class);
        cache = mock(CacheService.class);
        service = new SummaryService(repo, cache, json);
    }

    @Test
    void usesCacheWhenPresent() throws Exception {
        when(cache.get(anyString())).thenReturn(Optional.of(json.writeValueAsString(rows)));
        SummaryView view = service.summary();
        assertThat(view.fromCache()).isTrue();
        assertThat(view.rows()).isEqualTo(rows);
        verify(repo, never()).summary();
    }

    @Test
    void fallsBackToDatabaseAndFillsCache() {
        when(cache.get(anyString())).thenReturn(Optional.empty());
        when(cache.isAvailable()).thenReturn(true);
        when(repo.summary()).thenReturn(rows);
        SummaryView view = service.summary();
        assertThat(view.fromCache()).isFalse();
        assertThat(view.rows()).isEqualTo(rows);
        verify(cache).set(anyString(), eq(30), anyString());
    }

    @Test
    void worksWhenCacheIsDown() {
        when(cache.get(anyString())).thenReturn(Optional.empty());
        when(cache.isAvailable()).thenReturn(false);
        when(repo.summary()).thenReturn(rows);
        SummaryView view = service.summary();
        assertThat(view.cacheAvailable()).isFalse();
        assertThat(view.rows()).hasSize(1);
        verify(cache).set(anyString(), anyInt(), anyString());
    }
}
