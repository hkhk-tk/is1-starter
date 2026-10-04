package ee.hkhk.laboriseis.queue;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.amqp.core.Queue;
import org.springframework.amqp.rabbit.retry.MessageRecoverer;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** RabbitMQ järjekord, JSON-teisendus ja see, mis saab sõnumist pärast korduskatseid. */
@Configuration
public class QueueConfig {

    public static final String QUEUE = "results";

    @Bean
    public Queue resultsQueue() {
        return new Queue(QUEUE, true);
    }

    /**
     * Spring Boot seob selle bean'i tarbija korduskatsetega (spring.rabbitmq.listener.simple.retry.*).
     * Andmebaasi rike → sõnum tagasi järjekorda; vigane sõnum → ära visata, et see ei blokeeriks järjekorda.
     */
    @Bean
    public MessageRecoverer resultRecoverer() {
        return new ResultRecoverer();
    }

    @Bean
    public MessageConverter jsonMessageConverter(ObjectMapper objectMapper) {
        return new Jackson2JsonMessageConverter(objectMapper);
    }
}
