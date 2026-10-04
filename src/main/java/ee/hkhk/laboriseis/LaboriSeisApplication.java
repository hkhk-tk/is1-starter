package ee.hkhk.laboriseis;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.boot.web.servlet.support.SpringBootServletInitializer;

/** Rakenduse käivituspunkt. Töötab nii WAR-ina Tomcatis kui ka {@code java -jar} abil. */
@SpringBootApplication
public class LaboriSeisApplication extends SpringBootServletInitializer {

    @Override
    protected SpringApplicationBuilder configure(SpringApplicationBuilder builder) {
        return builder.sources(LaboriSeisApplication.class);
    }

    public static void main(String[] args) {
        SpringApplication.run(LaboriSeisApplication.class, args);
    }
}
