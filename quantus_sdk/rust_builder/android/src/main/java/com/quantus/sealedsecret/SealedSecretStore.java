package com.quantus.sealedsecret;

import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.security.keystore.KeyPermanentlyInvalidatedException;
import android.security.keystore.KeyProperties;
import android.security.keystore.KeyProtection;
import android.util.AtomicFile;
import android.util.Log;
import androidx.annotation.Keep;
import androidx.biometric.BiometricManager;
import androidx.biometric.BiometricManager.Authenticators;
import androidx.biometric.BiometricPrompt;
import androidx.fragment.app.FragmentActivity;
import androidx.lifecycle.Lifecycle;
import androidx.lifecycle.LifecycleEventObserver;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.Key;
import java.security.KeyStore;
import java.security.SecureRandom;
import java.security.UnrecoverableKeyException;
import java.util.Arrays;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.BlockingQueue;
import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

/**
 * The Android half of the Rust module {@code sealed_secret}, which is its only caller.
 *
 * <p>A secret is encrypted in this process under a fresh AES-256-GCM key, and that key is imported into the
 * Android Keystore (StrongBox where the device has one) for decryption only, usable for one operation after the
 * system prompt has authenticated the user. Importing needs no authentication, so sealing never prompts. The
 * Keystore invalidates the key when another biometric is enrolled or the screen lock is removed. The ciphertext
 * is a file the device never backs up.
 */
@Keep
public final class SealedSecretStore {
    private static final String TAG = "SealedSecretStore";
    private static final String KEYSTORE = "AndroidKeyStore";
    private static final String TRANSFORMATION = "AES/GCM/NoPadding";
    private static final int IV_BYTES = 12;
    private static final int TAG_BITS = 128;

    // Operations, policies and statuses, numbered as sealed_secret/android.rs numbers them.
    private static final int CAN_AUTHENTICATE = 0, STORED = 1, STORE = 2, READ = 3, DELETE = 4;
    private static final int NONE = 0, BIOMETRY = 1, DEVICE_PASSCODE = 2;
    private static final int OK = 0, CANCELLED = 1, NOT_RECOGNISED = 2, MISSING = 3, UNAVAILABLE = 4, PLATFORM = 5;

    private static final SealedSecretStore INSTANCE = new SealedSecretStore();

    static {
        System.loadLibrary("rust_lib_quantus_wallet");
    }

    private static final class Refusal extends Exception {
        final int status;

        Refusal(int status, String detail) {
            super(detail);
            this.status = status;
        }
    }

    private volatile Context context;
    private volatile FragmentActivity activity;
    private volatile BlockingQueue<Object> answer;

    private SealedSecretStore() {}

    /** Connects the Rust half and shows the prompts over {@code activity}. Call it from the activity's onCreate. */
    public static void bind(FragmentActivity activity) {
        INSTANCE.context = activity.getApplicationContext();
        INSTANCE.activity = activity;
        activity.getLifecycle().addObserver((LifecycleEventObserver) (owner, event) -> {
            if (event == Lifecycle.Event.ON_DESTROY) INSTANCE.unbind(activity);
        });
        INSTANCE.attach();
    }

    private native void attach();

    private void unbind(FragmentActivity closed) {
        if (activity == closed) activity = null;
        BlockingQueue<Object> waiting = answer;
        if (waiting != null) waiting.offer(new Refusal(CANCELLED, "An activity closed under the prompt"));
    }

    /** Called from Rust. Answers a status byte, then the payload of a success or the reason for a failure. */
    private byte[] call(int operation, String slot, int policy, String prompt, byte[] secret) {
        try {
            return reply(OK, run(operation, slot, policy, prompt, secret));
        } catch (Refusal refusal) {
            return failure(refusal.status, refusal.getMessage());
        } catch (Exception e) {
            Log.e(TAG, "Sealed secret operation " + operation + " failed", e);
            return failure(PLATFORM, e.toString());
        }
    }

    private byte[] run(int operation, String slot, int policy, String prompt, byte[] secret) throws Exception {
        switch (operation) {
            case CAN_AUTHENTICATE:
                return new byte[] {(byte) canAuthenticate(policy)};
            case STORED:
                return new byte[] {(byte) stored(slot)};
            case STORE:
                store(slot, policy, secret);
                return new byte[0];
            case READ:
                return read(slot, prompt);
            case DELETE:
                delete(slot);
                return new byte[0];
            default:
                throw new IllegalArgumentException("Unknown operation " + operation);
        }
    }

    private static byte[] reply(int status, byte[] payload) {
        byte[] reply = new byte[payload.length + 1];
        reply[0] = (byte) status;
        System.arraycopy(payload, 0, reply, 1, payload.length);
        Arrays.fill(payload, (byte) 0);
        return reply;
    }

    private static byte[] failure(int status, String detail) {
        return reply(status, detail.getBytes(StandardCharsets.UTF_8));
    }

    /**
     * What BiometricManager answers for {@code policy}, which sealed_secret reads. Before Android 11 the Keystore
     * authorises a single use of a key by a biometric only, so the screen lock is unsupported there.
     */
    private int canAuthenticate(int policy) {
        BiometricManager manager = BiometricManager.from(context);
        switch (policy) {
            case BIOMETRY:
                return manager.canAuthenticate(Authenticators.BIOMETRIC_STRONG);
            case DEVICE_PASSCODE:
                return Build.VERSION.SDK_INT >= Build.VERSION_CODES.R
                        ? manager.canAuthenticate(Authenticators.DEVICE_CREDENTIAL)
                        : BiometricManager.BIOMETRIC_ERROR_UNSUPPORTED;
            default:
                throw new IllegalArgumentException("Unknown policy " + policy);
        }
    }

    private static String alias(String slot) {
        return "sealed_secret." + slot;
    }

    private AtomicFile file(String slot) {
        if (!slot.matches("[a-z0-9_]+")) throw new IllegalArgumentException("Not a slot name: " + slot);
        return new AtomicFile(new File(new File(context.getNoBackupFilesDir(), "sealed_secret"), slot));
    }

    /** The policy byte, the nonce and the ciphertext of {@code slot}, or null when nothing is sealed there. */
    private byte[] sealed(String slot) throws IOException {
        try {
            return file(slot).readFully();
        } catch (FileNotFoundException e) {
            return null;
        }
    }

    private static KeyStore keyStore() throws Exception {
        KeyStore keyStore = KeyStore.getInstance(KEYSTORE);
        keyStore.load(null);
        return keyStore;
    }

    /**
     * The cipher that opens {@code sealed} once the user has authenticated. Starting it needs no authentication,
     * and is where the Keystore says that it has invalidated the key: the slot is then emptied.
     */
    private Cipher opener(String slot, byte[] sealed) throws Exception {
        try {
            Key key = keyStore().getKey(alias(slot), null);
            if (key != null) {
                Cipher cipher = Cipher.getInstance(TRANSFORMATION);
                cipher.init(Cipher.DECRYPT_MODE, key, new GCMParameterSpec(TAG_BITS, sealed, 1, IV_BYTES));
                return cipher;
            }
        } catch (KeyPermanentlyInvalidatedException | UnrecoverableKeyException e) {
            Log.w(TAG, "The key of slot " + slot + " was invalidated", e);
        }
        delete(slot);
        throw new Refusal(MISSING, "The Keystore no longer holds the key of this slot");
    }

    private int stored(String slot) throws Exception {
        byte[] sealed = sealed(slot);
        if (sealed == null) return NONE;
        try {
            opener(slot, sealed);
        } catch (Refusal emptied) {
            return NONE;
        }
        return sealed[0];
    }

    /**
     * A raw AES key that hands out the one array it holds. SecretKeySpec copies its input and hands out further
     * copies, none of which can be wiped. This one lets wiping {@code key} wipe what the cipher and the Keystore
     * import were given.
     */
    private static final class SealingKey implements SecretKey {
        private final byte[] key;

        SealingKey(byte[] key) {
            this.key = key;
        }

        @Override
        public String getAlgorithm() {
            return KeyProperties.KEY_ALGORITHM_AES;
        }

        @Override
        public String getFormat() {
            return "RAW";
        }

        @Override
        public byte[] getEncoded() {
            return key;
        }
    }

    /** The policy has been checked by sealed_secret; only the item of {@code slot} is replaced. */
    private void store(String slot, int policy, byte[] secret) throws Exception {
        delete(slot);
        byte[] key = new byte[32];
        byte[] sealed = new byte[1 + IV_BYTES + secret.length + TAG_BITS / 8];
        SecureRandom random = new SecureRandom();
        random.nextBytes(key);
        random.nextBytes(sealed);
        sealed[0] = (byte) policy;
        try {
            SecretKey aes = new SealingKey(key);
            Cipher cipher = Cipher.getInstance(TRANSFORMATION);
            cipher.init(Cipher.ENCRYPT_MODE, aes, new GCMParameterSpec(TAG_BITS, sealed, 1, IV_BYTES));
            cipher.doFinal(secret, 0, secret.length, sealed, 1 + IV_BYTES);
            keyStore().setEntry(alias(slot), new KeyStore.SecretKeyEntry(aes), protection(policy));
        } finally {
            Arrays.fill(key, (byte) 0);
        }
        AtomicFile file = file(slot);
        FileOutputStream stream = file.startWrite();
        try {
            stream.write(sealed);
            file.finishWrite(stream);
        } catch (IOException e) {
            file.failWrite(stream);
            throw e;
        }
    }

    /** A key that needs authentication is invalidated by a new biometric enrolment unless told otherwise. */
    private KeyProtection protection(int policy) {
        KeyProtection.Builder protection = new KeyProtection.Builder(KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setUserAuthenticationRequired(true);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            protection.setUserAuthenticationParameters(
                    0, policy == BIOMETRY ? KeyProperties.AUTH_BIOMETRIC_STRONG : KeyProperties.AUTH_DEVICE_CREDENTIAL);
        }
        if (context.getPackageManager().hasSystemFeature(PackageManager.FEATURE_STRONGBOX_KEYSTORE)) {
            protection.setIsStrongBoxBacked(true);
        }
        return protection.build();
    }

    private byte[] read(String slot, String prompt) throws Exception {
        byte[] sealed = sealed(slot);
        if (sealed == null) throw new Refusal(MISSING, "Nothing is sealed in this slot");
        Cipher cipher = opener(slot, sealed);
        authenticate(cipher, sealed[0], prompt);
        return cipher.doFinal(sealed, 1 + IV_BYTES, sealed.length - 1 - IV_BYTES);
    }

    /** Blocks the calling thread until the system prompt has authorised {@code cipher} or has been closed. */
    private synchronized void authenticate(Cipher cipher, int policy, String title) throws Exception {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            throw new IllegalStateException("The main thread cannot wait for the prompt it draws");
        }
        FragmentActivity activity = this.activity;
        if (activity == null) throw new Refusal(UNAVAILABLE, "No activity to prompt over");
        BiometricPrompt.PromptInfo.Builder info = new BiometricPrompt.PromptInfo.Builder().setTitle(title);
        if (policy == BIOMETRY) {
            info.setAllowedAuthenticators(Authenticators.BIOMETRIC_STRONG)
                    .setNegativeButtonText(activity.getString(android.R.string.cancel));
        } else {
            info.setAllowedAuthenticators(Authenticators.DEVICE_CREDENTIAL);
        }
        BlockingQueue<Object> answer = new ArrayBlockingQueue<>(1);
        this.answer = answer;
        new Handler(Looper.getMainLooper()).post(() -> {
            try {
                new BiometricPrompt(activity, Runnable::run, new BiometricPrompt.AuthenticationCallback() {
                    @Override
                    public void onAuthenticationSucceeded(BiometricPrompt.AuthenticationResult result) {
                        answer.offer(cipher);
                    }

                    @Override
                    public void onAuthenticationError(int code, CharSequence message) {
                        answer.offer(new Refusal(status(code), "Prompt error " + code + ": " + message));
                    }
                }).authenticate(info.build(), new BiometricPrompt.CryptoObject(cipher));
            } catch (RuntimeException e) {
                answer.offer(e);
            }
        });
        Object given = answer.take();
        if (given instanceof Exception) throw (Exception) given;
    }

    private static int status(int promptError) {
        switch (promptError) {
            case BiometricPrompt.ERROR_USER_CANCELED:
            case BiometricPrompt.ERROR_NEGATIVE_BUTTON:
            case BiometricPrompt.ERROR_CANCELED:
            case BiometricPrompt.ERROR_TIMEOUT:
                return CANCELLED;
            case BiometricPrompt.ERROR_LOCKOUT:
            case BiometricPrompt.ERROR_LOCKOUT_PERMANENT:
                return NOT_RECOGNISED;
            case BiometricPrompt.ERROR_NO_BIOMETRICS:
            case BiometricPrompt.ERROR_NO_DEVICE_CREDENTIAL:
            case BiometricPrompt.ERROR_HW_NOT_PRESENT:
            case BiometricPrompt.ERROR_HW_UNAVAILABLE:
                return UNAVAILABLE;
            default:
                return PLATFORM;
        }
    }

    private void delete(String slot) throws Exception {
        keyStore().deleteEntry(alias(slot));
        file(slot).delete();
    }
}
