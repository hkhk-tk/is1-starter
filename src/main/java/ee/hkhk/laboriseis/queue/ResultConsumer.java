package ee.hkhk.laboriseis.queue;

import ee.hkhk.laboriseis.data.Result;
import ee.hkhk.laboriseis.data.ResultRepository;
import ee.hkhk.laboriseis.web.SummaryService;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

/**
 * Loeb järjekorda ja kirjutab andmebaasi. Kui andmebaas ei vasta, jääb sõnum järjekorda
 * (vt spring.rabbitmq.listener.simple.* seadistust) ja kirjutatakse, kui baas tagasi tuleb.
 */
@Component
public class ResultConsumer {

    private final ResultRepository results;
    private final SummaryService summary;

    public ResultConsumer(ResultRepository results, SummaryService summary) {
        this.results = results;
        this.summary = summary;
    }

    @RabbitListener(queues = QueueConfig.QUEUE)
    public void onResult(ResultEvent e) {
        Result r = new Result(e.lab(), e.check(), e.status(), e.message(), e.host(), e.receivedAt());
        results.insert(e.studentId(), r);
        summary.invalidate();
    }
}
