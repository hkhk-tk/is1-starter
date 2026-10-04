package ee.hkhk.laboriseis.web;

import ee.hkhk.laboriseis.data.ResultRepository;
import ee.hkhk.laboriseis.data.Student;
import jakarta.servlet.http.HttpServletResponse;
import java.util.Optional;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DataAccessException;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;

/** HTML-vaated: koolitaja koondtabel ja õppija enda seis. */
@Controller
public class WebController {

    private final TokenService tokens;
    private final SummaryService summary;
    private final ResultRepository results;
    private final String version;
    private final TimeFormat fmt = new TimeFormat();

    public WebController(TokenService tokens, SummaryService summary, ResultRepository results,
                         @Value("${app.version}") String version) {
        this.tokens = tokens;
        this.summary = summary;
        this.results = results;
        this.version = version;
    }

    @GetMapping("/")
    public String index(@RequestParam(value = "token", required = false) String token, Model model,
                        HttpServletResponse response) {
        model.addAttribute("version", version);
        model.addAttribute("fmt", fmt);
        if (!tokens.isTeacher(token)) {
            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
            return "login";
        }
        try {
            SummaryView view = summary.summary();
            response.setHeader("X-Cache", view.fromCache() ? "HIT" : "MISS");
            model.addAttribute("view", view);
        } catch (DataAccessException e) {
            response.setStatus(HttpServletResponse.SC_SERVICE_UNAVAILABLE);
            model.addAttribute("dbError", true);
        }
        return "index";
    }

    @GetMapping("/s/{token}")
    public String student(@PathVariable("token") String token, Model model, HttpServletResponse response) {
        model.addAttribute("version", version);
        model.addAttribute("fmt", fmt);
        try {
            Optional<Student> student = tokens.student(token);
            if (student.isEmpty()) {
                response.setStatus(HttpServletResponse.SC_NOT_FOUND);
                return "login";
            }
            model.addAttribute("student", student.get());
            model.addAttribute("results", results.latestForStudent(student.get().id()));
        } catch (DataAccessException e) {
            response.setStatus(HttpServletResponse.SC_SERVICE_UNAVAILABLE);
            model.addAttribute("dbError", true);
        }
        return "student";
    }
}
