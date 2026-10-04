package ee.hkhk.laboriseis.api;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * POST /api/results sisu. {@code student} (GitHubi kasutajanimi) on vajalik ainult koolitaja tokeniga.
 */
public record ResultRequest(
        @NotBlank @Size(max = 32) @Pattern(regexp = "[a-z0-9-]+") String lab,
        @NotBlank @Size(max = 64) String check,
        @NotBlank @Pattern(regexp = "OK|FAIL") String status,
        @Size(max = 500) String message,
        @Size(max = 64) String host,
        @Size(max = 64) String student) {
}
