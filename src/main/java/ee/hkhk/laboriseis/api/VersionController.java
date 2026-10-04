package ee.hkhk.laboriseis.api;

import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/** /version: versioon, commit ja ehitusaeg. Pipeline paneb GIT_SHA keskkonnamuutujaks või image'isse. */
@RestController
public class VersionController {

    private final Map<String, String> info;

    public VersionController(@Value("${app.version}") String version,
                             @Value("${app.build-time}") String buildTime,
                             @Value("${app.git-sha}") String gitSha) {
        this.info = Map.of("version", version, "commit", gitSha, "built", buildTime);
    }

    @GetMapping("/version")
    public Map<String, String> version() {
        return info;
    }
}
