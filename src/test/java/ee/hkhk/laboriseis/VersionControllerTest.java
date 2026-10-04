package ee.hkhk.laboriseis;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import ee.hkhk.laboriseis.api.VersionController;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.test.web.servlet.MockMvc;

/** Pipeline'i deploy-kontroll võrdleb /version commit'i GITHUB_SHA-ga. See test hoiab välja nime paigal. */
@WebMvcTest(controllers = VersionController.class, properties = "app.git-sha=0123456789abcdef")
class VersionControllerTest {

    @Autowired
    private MockMvc mvc;

    @Test
    void showsCommitFromEnvironment() throws Exception {
        mvc.perform(get("/version"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.commit").value("0123456789abcdef"))
                .andExpect(jsonPath("$.version").isNotEmpty())
                .andExpect(jsonPath("$.built").isNotEmpty());
    }
}
