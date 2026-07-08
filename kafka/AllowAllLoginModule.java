import javax.security.auth.*;
import javax.security.auth.callback.*;
import javax.security.auth.login.*;
import javax.security.auth.spi.*;
import java.util.Map;

/**
 * Dev-only SASL LoginModule that accepts any credentials.
 * Replaces GCP IAM-based auth (SASL/PLAIN with SA key as password)
 * which cannot be replicated in a plain Kafka container.
 */
public class AllowAllLoginModule implements LoginModule {
    private Subject subject;
    private CallbackHandler callbackHandler;

    @Override
    public void initialize(Subject subject, CallbackHandler callbackHandler,
                           Map<String, ?> sharedState, Map<String, ?> options) {
        this.subject = subject;
        this.callbackHandler = callbackHandler;
    }

    @Override
    public boolean login() throws LoginException {
        try {
            NameCallback nc = new NameCallback("Username: ");
            callbackHandler.handle(new Callback[]{nc});
        } catch (Exception ignored) {}
        return true;
    }

    @Override
    public boolean commit() throws LoginException { return true; }

    @Override
    public boolean abort() throws LoginException { return false; }

    @Override
    public boolean logout() throws LoginException { return true; }
}
