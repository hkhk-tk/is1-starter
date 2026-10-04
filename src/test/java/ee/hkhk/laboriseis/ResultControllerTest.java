package ee.hkhk.laboriseis;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import ee.hkhk.laboriseis.api.ResultController;
import ee.hkhk.laboriseis.data.ResultRepository;
import ee.hkhk.laboriseis.data.Student;
import ee.hkhk.laboriseis.queue.ResultPublisher;
import ee.hkhk.laboriseis.web.TokenService;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.amqp.AmqpConnectException;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(ResultController.class)
class ResultControllerTest {

    private static final String BODY = """
            {"lab":"lab-01","check":"nginx","status":"OK","host":"web01"}
            """;

    @Autowired
    private MockMvc mvc;

    @MockitoBean
    private TokenService tokens;

    @MockitoBean
    private ResultPublisher publisher;

    @MockitoBean
    private ResultRepository results;

    private static final Student KATI = new Student(1, "Kati Kask", "katikask", "IS1-26");

    @Test
    void acceptsValidResult() throws Exception {
        when(tokens.student("abc")).thenReturn(Optional.of(KATI));
        mvc.perform(post("/api/results").header("Authorization", "Bearer abc")
                        .contentType(MediaType.APPLICATION_JSON).content(BODY))
                .andExpect(status().isAccepted());
        verify(publisher).publish(any());
    }

    @Test
    void rejectsUnknownToken() throws Exception {
        when(tokens.student(any())).thenReturn(Optional.empty());
        mvc.perform(post("/api/results").header("Authorization", "Bearer vale")
                        .contentType(MediaType.APPLICATION_JSON).content(BODY))
                .andExpect(status().isUnauthorized());
        verify(publisher, never()).publish(any());
    }

    @Test
    void rejectsInvalidStatus() throws Exception {
        when(tokens.student("abc")).thenReturn(Optional.of(KATI));
        mvc.perform(post("/api/results").header("Authorization", "Bearer abc")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"lab\":\"lab-01\",\"check\":\"nginx\",\"status\":\"MAYBE\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void returns503WhenQueueIsDown() throws Exception {
        when(tokens.student("abc")).thenReturn(Optional.of(KATI));
        doThrow(new AmqpConnectException(new java.net.ConnectException("rmq01"))).when(publisher).publish(any());
        mvc.perform(post("/api/results").header("Authorization", "Bearer abc")
                        .contentType(MediaType.APPLICATION_JSON).content(BODY))
                .andExpect(status().isServiceUnavailable());
    }

    @Test
    void returns503WhenDatabaseIsDown() throws Exception {
        when(tokens.student("abc")).thenThrow(new DataAccessResourceFailureException("db01"));
        mvc.perform(post("/api/results").header("Authorization", "Bearer abc")
                        .contentType(MediaType.APPLICATION_JSON).content(BODY))
                .andExpect(status().isServiceUnavailable());
    }

    @Test
    void teacherMustNameStudent() throws Exception {
        when(tokens.isTeacher("opetaja")).thenReturn(true);
        mvc.perform(post("/api/results").header("Authorization", "Bearer opetaja")
                        .contentType(MediaType.APPLICATION_JSON).content(BODY))
                .andExpect(status().isBadRequest());
    }
}
