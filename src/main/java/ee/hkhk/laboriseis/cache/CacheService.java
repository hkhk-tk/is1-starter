package ee.hkhk.laboriseis.cache;

import jakarta.annotation.PreDestroy;
import java.net.InetSocketAddress;
import java.time.Duration;
import java.time.Instant;
import java.util.Optional;
import java.util.concurrent.TimeUnit;
import net.spy.memcached.MemcachedClient;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

/**
 * Memcachedi ümbris. Kui Memcached ei vasta, ei kuku rakendus: get tagastab tühja
 * ja {@link #isAvailable()} ütleb false. Ühendust proovitakse uuesti iga 30 sekundi järel.
 */
@Service
public class CacheService {

    private static final Logger LOG = LoggerFactory.getLogger(CacheService.class);
    private static final Duration RETRY = Duration.ofSeconds(30);
    private static final long TIMEOUT_MS = 300;

    static {
        // spymemcached kirjutab vaikimisi oma logid otse stderr'i (iga taasühenduse katse). Suuname need SLF4J-sse,
        // siis kehtivad tavalised logback'i tasemed. Peab olema seatud enne esimest MemcachedClient'i.
        if (System.getProperty("net.spy.log.LoggerImpl") == null) {
            System.setProperty("net.spy.log.LoggerImpl", "net.spy.memcached.compat.log.SLF4JLogger");
        }
    }

    private final String host;
    private final int port;
    private MemcachedClient client;
    private Instant nextAttempt = Instant.EPOCH;
    private volatile boolean available;

    public CacheService(@Value("${app.memcached.host}") String host, @Value("${app.memcached.port}") int port) {
        this.host = host;
        this.port = port;
    }

    public Optional<String> get(String key) {
        MemcachedClient c = client();
        if (c == null) {
            return Optional.empty();
        }
        try {
            Object value = c.asyncGet(key).get(TIMEOUT_MS, TimeUnit.MILLISECONDS);
            available = true;
            return Optional.ofNullable((String) value);
        } catch (Exception e) {
            markDown(e);
            return Optional.empty();
        }
    }

    public void set(String key, int ttlSeconds, String value) {
        MemcachedClient c = client();
        if (c == null) {
            return;
        }
        try {
            c.set(key, ttlSeconds, value).get(TIMEOUT_MS, TimeUnit.MILLISECONDS);
            available = true;
        } catch (Exception e) {
            markDown(e);
        }
    }

    public void delete(String key) {
        MemcachedClient c = client();
        if (c == null) {
            return;
        }
        try {
            c.delete(key).get(TIMEOUT_MS, TimeUnit.MILLISECONDS);
            available = true;
        } catch (Exception e) {
            markDown(e);
        }
    }

    /** Kontrollib ühendust (kasutab /health). */
    public boolean ping() {
        MemcachedClient c = client();
        if (c == null) {
            return false;
        }
        try {
            c.asyncGet("ping").get(TIMEOUT_MS, TimeUnit.MILLISECONDS);
            available = true;
        } catch (Exception e) {
            markDown(e);
        }
        return available;
    }

    public boolean isAvailable() {
        return available;
    }

    private synchronized MemcachedClient client() {
        if (client != null) {
            return client;
        }
        if (Instant.now().isBefore(nextAttempt)) {
            return null;
        }
        try {
            client = new MemcachedClient(new InetSocketAddress(host, port));
            return client;
        } catch (Exception e) {
            nextAttempt = Instant.now().plus(RETRY);
            markDown(e);
            return null;
        }
    }

    private void markDown(Exception e) {
        if (available) {
            LOG.warn("Memcached {}:{} ei vasta: {}", host, port, e.toString());
        }
        available = false;
    }

    @PreDestroy
    public synchronized void close() {
        if (client != null) {
            client.shutdown(1, TimeUnit.SECONDS);
        }
    }
}
