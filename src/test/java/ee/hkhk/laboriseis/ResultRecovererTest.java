package ee.hkhk.laboriseis;

import static org.assertj.core.api.Assertions.assertThatThrownBy;

import ee.hkhk.laboriseis.queue.ResultRecoverer;
import org.junit.jupiter.api.Test;
import org.springframework.amqp.AmqpRejectAndDontRequeueException;
import org.springframework.amqp.ImmediateRequeueAmqpException;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.core.MessageProperties;
import org.springframework.amqp.support.converter.MessageConversionException;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.dao.DataIntegrityViolationException;

/** Ajutine rike → sõnum jääb järjekorda; püsiv viga → sõnum visatakse ära, järjekord ei jää kinni. */
class ResultRecovererTest {

    private final ResultRecoverer recoverer = new ResultRecoverer();
    private final Message message = new Message("{}".getBytes(), new MessageProperties());

    @Test
    void databaseDownKeepsMessage() {
        RuntimeException cause = new RuntimeException("listener", new DataAccessResourceFailureException("db01"));
        assertThatThrownBy(() -> recoverer.recover(message, cause))
                .isInstanceOf(ImmediateRequeueAmqpException.class);
    }

    @Test
    void unknownStudentDropsMessage() {
        RuntimeException cause = new RuntimeException("listener", new DataIntegrityViolationException("fk_student"));
        assertThatThrownBy(() -> recoverer.recover(message, cause))
                .isInstanceOf(AmqpRejectAndDontRequeueException.class);
    }

    @Test
    void unreadableMessageDropsMessage() {
        assertThatThrownBy(() -> recoverer.recover(message, new MessageConversionException("vigane JSON")))
                .isInstanceOf(AmqpRejectAndDontRequeueException.class);
    }
}
