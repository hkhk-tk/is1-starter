package ee.hkhk.laboriseis;

import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import ee.hkhk.laboriseis.api.HealthController;
import ee.hkhk.laboriseis.cache.CacheService;
import ee.hkhk.laboriseis.data.ResultRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.amqp.AmqpConnectException;
import org.springframework.amqp.rabbit.connection.Connection;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

/** /health ja /health/live semantika: mis kukub ja mis mitte. */
@WebMvcTest(HealthController.class)
class HealthControllerTest {

    @Autowired
    private MockMvc mvc;

    @MockitoBean
    private ResultRepository db;

    @MockitoBean
    private ConnectionFactory rabbit;

    @MockitoBean
    private CacheService cache;

    @BeforeEach
    void allUp() {
        Connection connection = mock(Connection.class);
        when(connection.isOpen()).thenReturn(true);
        when(rabbit.createConnection()).thenReturn(connection);
        when(cache.ping()).thenReturn(true);
    }

    @Test
    void upWhenEverythingAnswers() throws Exception {
        mvc.perform(get("/health"))
                .andExpect(status().isOk())
                .andExpect(header().string("Cache-Control", "no-store"))
                .andExpect(jsonPath("$.status").value("UP"))
                .andExpect(jsonPath("$.db").value("UP"))
                .andExpect(jsonPath("$.queue").value("UP"))
                .andExpect(jsonPath("$.cache").value("UP"));
    }

    @Test
    void downWhenDatabaseIsDown() throws Exception {
        doThrow(new DataAccessResourceFailureException("db01")).when(db).ping();
        mvc.perform(get("/health"))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.status").value("DOWN"))
                .andExpect(jsonPath("$.db").value("DOWN"))
                .andExpect(jsonPath("$.queue").value("UP"));
    }

    @Test
    void downWhenQueueIsDown() throws Exception {
        when(rabbit.createConnection()).thenThrow(new AmqpConnectException(new java.net.ConnectException("rmq01")));
        mvc.perform(get("/health"))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.queue").value("DOWN"));
    }

    @Test
    void cacheIsOptional() throws Exception {
        when(cache.ping()).thenReturn(false);
        mvc.perform(get("/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"))
                .andExpect(jsonPath("$.cache").value("DOWN"));
    }

    @Test
    void liveDoesNotDependOnServices() throws Exception {
        doThrow(new DataAccessResourceFailureException("db01")).when(db).ping();
        when(rabbit.createConnection()).thenThrow(new AmqpConnectException(new java.net.ConnectException("rmq01")));
        when(cache.ping()).thenReturn(false);
        mvc.perform(get("/health/live"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"));
    }
}
