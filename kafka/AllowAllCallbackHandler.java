import org.apache.kafka.common.security.auth.AuthenticateCallbackHandler;
import org.apache.kafka.common.security.plain.PlainAuthenticateCallback;

import javax.security.auth.callback.Callback;
import javax.security.auth.callback.NameCallback;
import javax.security.auth.callback.UnsupportedCallbackException;
import javax.security.auth.login.AppConfigurationEntry;
import java.io.IOException;
import java.util.List;
import java.util.Map;

/**
 * Dev-only SASL server callback handler that accepts any username/password.
 * Replaces PlainServerCallbackHandler so credentials from GCP IAM (SA email +
 * base64 JSON key) are accepted without being listed in the JAAS config.
 */
public class AllowAllCallbackHandler implements AuthenticateCallbackHandler {

    @Override
    public void configure(Map<String, ?> configs, String mechanism,
                          List<AppConfigurationEntry> jaasConfigEntries) {
        // No configuration needed — we accept everything
    }

    @Override
    public void handle(Callback[] callbacks) throws IOException, UnsupportedCallbackException {
        for (Callback callback : callbacks) {
            if (callback instanceof NameCallback) {
                NameCallback nc = (NameCallback) callback;
                nc.setName(nc.getDefaultName());
            } else if (callback instanceof PlainAuthenticateCallback) {
                ((PlainAuthenticateCallback) callback).authenticated(true);
            } else {
                throw new UnsupportedCallbackException(callback);
            }
        }
    }

    @Override
    public void close() {}
}
