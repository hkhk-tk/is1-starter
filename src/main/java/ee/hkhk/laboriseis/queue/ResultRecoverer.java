package ee.hkhk.laboriseis.queue;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.AmqpRejectAndDontRequeueException;
import org.springframework.amqp.ImmediateRequeueAmqpException;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.rabbit.retry.MessageRecoverer;
import org.springframework.dao.DataIntegrityViolationException;

/**
 * Otsustab pärast viimast korduskatset, mis sõnumist saab.
 *
 * <p>Ajutine rike (db01 ei vasta, võrk katkes): sõnum läheb järjekorda tagasi ja kirjutatakse, kui baas tagasi
 * tuleb. See on README lubadus "tulemused ootavad järjekorras".
 *
 * <p>Püsiv viga (sõnumit ei saa lugeda, õppijat pole enam andmebaasis): sõnum visatakse ära ja logitakse.
 * Muidu jääks see igavesti järjekorra etteotsa ja ükski teine tulemus ei jõuaks andmebaasi (prefetch=1).
 */
public class ResultRecoverer implements MessageRecoverer {

    private static final Logger LOG = LoggerFactory.getLogger(ResultRecoverer.class);

    @Override
    public void recover(Message message, Throwable cause) {
        if (isPermanent(cause)) {
            LOG.error("Tulemus visatakse ära, seda ei saa salvestada: {}", rootMessage(cause));
            throw new AmqpRejectAndDontRequeueException("püsiv viga", cause);
        }
        LOG.warn("Tulemus jääb järjekorda, proovime hiljem uuesti: {}", rootMessage(cause));
        throw new ImmediateRequeueAmqpException("ajutine viga", cause);
    }

    /** Püsiv = sama sõnum kukub ka järgmisel korral. */
    static boolean isPermanent(Throwable cause) {
        for (Throwable t = cause; t != null; t = t.getCause()) {
            if (t instanceof DataIntegrityViolationException
                    || t instanceof org.springframework.amqp.support.converter.MessageConversionException
                    || t instanceof org.springframework.messaging.converter.MessageConversionException) {
                return true;
            }
            if (t.getCause() == t) {
                break;
            }
        }
        return false;
    }

    private static String rootMessage(Throwable cause) {
        Throwable t = cause;
        while (t != null && t.getCause() != null && t.getCause() != t) {
            t = t.getCause();
        }
        return t == null ? "?" : t.toString();
    }
}
