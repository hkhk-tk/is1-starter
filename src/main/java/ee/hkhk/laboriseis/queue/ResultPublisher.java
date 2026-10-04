package ee.hkhk.laboriseis.queue;

import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Service;

/** Paneb tulemuse järjekorda. RabbitMQ rikke korral viskab AmqpException'i. */
@Service
public class ResultPublisher {

    private final RabbitTemplate rabbit;

    public ResultPublisher(RabbitTemplate rabbit) {
        this.rabbit = rabbit;
    }

    public void publish(ResultEvent event) {
        rabbit.convertAndSend("", QueueConfig.QUEUE, event);
    }
}
