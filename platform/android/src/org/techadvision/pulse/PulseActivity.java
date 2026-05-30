package org.techadvision.pulse;

import java.util.ArrayList; //TODO
import java.util.HashMap; // TODO
import java.io.File;
import java.util.List;
import java.lang.reflect.Method;

import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.os.PowerManager;
import android.net.wifi.WifiManager;
import android.provider.Settings;
import android.util.Log;
import android.view.WindowManager;
import android.app.Activity;
import android.os.storage.StorageManager;
import android.os.storage.StorageVolume;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import com.hoho.android.usbserial.driver.*;
//import org.qtproject.qt5.android.bindings.QtActivity;
//import org.qtproject.qt5.android.bindings.QtApplication;
import android.widget.Toast;
import android.os.Handler;
import android.os.Looper;
import java.util.concurrent.atomic.AtomicBoolean;

import android.content.pm.ActivityInfo;

import android.os.Build;
import android.view.View;
import android.view.WindowManager.LayoutParams;

import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import android.graphics.Color;

import android.view.ViewTreeObserver;
import java.util.concurrent.atomic.AtomicBoolean;

import android.content.res.Configuration;
import java.lang.reflect.Method;
import java.lang.Class;

import org.qtproject.qt.android.bindings.QtActivity;

// media store imports

import android.os.ParcelFileDescriptor;
import android.content.ContentValues;
import android.content.ContentResolver;
import android.provider.MediaStore;
import android.os.ParcelFileDescriptor;

import java.io.FileOutputStream;
import java.io.File;


public class PulseActivity extends QtActivity {
    private static final String TAG = PulseActivity.class.getSimpleName();
        private static final String SCREEN_BRIGHT_WAKE_LOCK_TAG = "Pulse Echo Sounder";
        private static final String MULTICAST_LOCK_TAG = "Pulse Echo Sounder";
    
        private static final int ORIENTATION_UNSPECIFIED = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED;
        private static final int ORIENTATION_LANDSCAPE   = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE;

        private static PulseActivity m_instance = null;

        private PowerManager.WakeLock m_wakeLock;
        private WifiManager.MulticastLock m_wifiMulticastLock;
        private boolean multiWindow = false;
        
        // Native C++ functions
        public native boolean nativeInit();
        public native void koggerLogDebug(final String message);
        public native void koggerLogWarning(final String message);
        private static native void notifyInsets(int left, int top, int right, int bottom, int imeBottom);
        private static native void notifyDexState(boolean enabled, boolean fullscreen);


        public PulseActivity() {
            m_instance = this;
        }

        /**
         * Returns the singleton instance of PulseActivity.
         *
         * @return The current instance of PulseActivity.
         */
        public static PulseActivity getInstance() {
            return m_instance;
        }

        @Override
        public void onCreate(Bundle savedInstanceState) {
            super.onCreate(savedInstanceState);

            nativeInit();

            // 1) LANDSCAPE ENFORCE (when not multi-window)
            if (!isInMultiWindowMode()) {
                setRequestedOrientation(ORIENTATION_LANDSCAPE);
            } else {
                setRequestedOrientation(ORIENTATION_UNSPECIFIED);
            }

            // 2) EDGE-TO-EDGE + INSETS + DEX
            setupEdgeToEdgeInsetsAndDex();

            // keep upstream setup
            //checkStoragePermissions();
            acquireWakeLock();
            keepScreenOn();
            setupMulticastLock();

            // upstream USB integration (keep this)
            KoggerUsbSerialManager.initialize(this);
        }

        @Override
        protected void onDestroy() {
            try {
                releaseMulticastLock();
                releaseWakeLock();
                KoggerUsbSerialManager.cleanup(this);
            } catch (final Exception e) {
                Log.e(TAG, "Exception onDestroy()", e);
            }

            super.onDestroy();
        }
    
        // PULSE METHODS
    
        @Override
        protected void onResume() {
            super.onResume();

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                setRequestedOrientation(isInMultiWindowMode()
                    ? ORIENTATION_UNSPECIFIED
                    : ORIENTATION_LANDSCAPE);
            }

            final View root = getWindow().getDecorView();
            root.post(() -> ViewCompat.requestApplyInsets(root));
        }
    
        @Override
        public void onMultiWindowModeChanged(boolean isInMultiWindowMode) {
            super.onMultiWindowModeChanged(isInMultiWindowMode);

            if (isInMultiWindowMode) {
                setRequestedOrientation(ORIENTATION_UNSPECIFIED);
            } else {
                setRequestedOrientation(ORIENTATION_LANDSCAPE);
            }
            multiWindow = isInMultiWindowMode;

            Log.d(TAG, "INSETS: App in multi window? " + isInMultiWindowMode());
            ViewCompat.requestApplyInsets(getWindow().getDecorView());
        }
    
        private void setupEdgeToEdgeInsetsAndDex() {
            // SDK35 Edge-to-edge
            WindowCompat.setDecorFitsSystemWindows(getWindow(), false);

            if (Build.VERSION.SDK_INT >= 21) {
                getWindow().setStatusBarColor(Color.TRANSPARENT);
                getWindow().setNavigationBarColor(Color.TRANSPARENT);
            }
            if (Build.VERSION.SDK_INT >= 29) {
                getWindow().setNavigationBarContrastEnforced(false);
            }
            if (Build.VERSION.SDK_INT >= 28) {
                WindowManager.LayoutParams lp = getWindow().getAttributes();
                lp.layoutInDisplayCutoutMode =
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
                getWindow().setAttributes(lp);
            }

            // ensure not fullscreen
            getWindow().clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN);

            getWindow().getDecorView().setSystemUiVisibility(
                  View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            );

            getWindow().addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);

            final View root = getWindow().getDecorView();
            final AtomicBoolean insetsReady = new AtomicBoolean(false);

            ViewCompat.setOnApplyWindowInsetsListener(root, (v, insets) -> {
                WindowInsetsCompat wi = insets;

                Insets barsNow    = wi.getInsets(WindowInsetsCompat.Type.systemBars());
                Insets barsStable = wi.getInsetsIgnoringVisibility(WindowInsetsCompat.Type.systemBars());
                Insets cutout     = wi.getInsets(WindowInsetsCompat.Type.displayCutout());
                Insets tappable   = wi.getInsets(WindowInsetsCompat.Type.tappableElement());
                Insets ime        = wi.getInsets(WindowInsetsCompat.Type.ime());


                int left   = Math.max(Math.max(barsNow.left,  barsStable.left),  cutout != null ? cutout.left : 0);
                int top    = Math.max(Math.max(barsNow.top,   barsStable.top),   cutout != null ? cutout.top  : 0);
                int right  = Math.max(Math.max(barsNow.right, barsStable.right), Math.max(tappable.right,  cutout != null ? cutout.right : 0));
                int bottom = Math.max(Math.max(barsNow.bottom,barsStable.bottom),Math.max(tappable.bottom, cutout != null ? cutout.bottom: 0));

                int imeBottom = Math.max(0, ime.bottom);

                Log.d(TAG, "INSETS: base top inset =" + top);


                //boolean multiWindow = appInMultiWindowMode;
                boolean dexOn = isDexEnabled(this);
                boolean dexFS = isDexFullscreen();
                Log.d(TAG, "INSETS: Dex on?? " + dexOn);
                Log.d(TAG, "INSETS: Dex full screen?? " + dexFS);

                if (isInMultiWindowMode()) {
                    top = top + 36;
                    Log.d(TAG, "INSETS: multi window mode, increasing top inset");
                    //dexOn = true;
                    //dexFS = true;
                }

                /*
                int systemTop = Math.max(
                    Math.max(barsNow.top, barsStable.top),
                    cutout != null ? cutout.top : 0
                );

                int left = Math.max(
                    Math.max(barsNow.left, barsStable.left),
                    cutout != null ? cutout.left : 0
                );

                int right = Math.max(
                    Math.max(barsNow.right, barsStable.right),
                    Math.max(tappable.right, cutout != null ? cutout.right : 0)
                );

                int bottom = Math.max(
                    Math.max(barsNow.bottom, barsStable.bottom),
                    Math.max(tappable.bottom, cutout != null ? cutout.bottom : 0)
                );
                */

                /*
                 * Critical difference:
                 *
                 * In normal fullscreen edge-to-edge mode, allow the echogram to use y=0.
                 * In split screen / windowed DeX, reserve the top system area so newest
                 * side-scan data is not hidden behind the black bar.
                 */
                //int top;
                /*
                if (multiWindow || (dexOn && !dexFS)) {
                    top = systemTop;
                } else {
                    top = 0;
                }
                */

                //int imeBottom = Math.max(0, ime.bottom);

                notifyInsets(left, top, right, bottom, imeBottom);
                notifyDexState(dexOn, dexFS);

                insetsReady.set(true);
                root.getViewTreeObserver().dispatchOnGlobalLayout();
                return insets;

                /*
                notifyInsets(left, top, right, bottom, imeBottom);
                notifyDexState(dexOn, dexFS);

                insetsReady.set(true);
                root.getViewTreeObserver().dispatchOnGlobalLayout();
                return insets;
                */
            });

            root.getViewTreeObserver().addOnPreDrawListener(new ViewTreeObserver.OnPreDrawListener() {
                @Override public boolean onPreDraw() {
                    if (!insetsReady.get()) return false;
                    root.getViewTreeObserver().removeOnPreDrawListener(this);
                    return true;
                }
            });

            ViewCompat.requestApplyInsets(root);
        }

        private boolean isDexEnabled(Context ctx) {
            try {
                Configuration config = ctx.getResources().getConfiguration();
                Class<?> cls = config.getClass();
                int FLAG = cls.getField("SEM_DESKTOP_MODE_ENABLED").getInt(cls);
                int value = cls.getField("semDesktopModeEnabled").getInt(config);
                return value == FLAG;
            } catch (Throwable t) {
                return false;
            }
        }

        private boolean isDexFullscreen() {
            return isDexEnabled(this) && !isInMultiWindowMode();
        }



        /**
         * Keeps the screen on by adding the appropriate window flag.
         */
        private void keepScreenOn() {
            getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        }

        /**
         * Acquires a wake lock to keep the CPU running.
         */
        private void acquireWakeLock() {
            final PowerManager pm = (PowerManager) getSystemService(Context.POWER_SERVICE);
            m_wakeLock = pm.newWakeLock(PowerManager.SCREEN_BRIGHT_WAKE_LOCK, SCREEN_BRIGHT_WAKE_LOCK_TAG);
            if (m_wakeLock != null) {
                m_wakeLock.acquire();
            } else {
                Log.w(TAG, "SCREEN_BRIGHT_WAKE_LOCK not acquired!");
            }
        }

        /**
         * Releases the wake lock if held.
         */
        private void releaseWakeLock() {
            if (m_wakeLock != null && m_wakeLock.isHeld()) {
                m_wakeLock.release();
            }
        }

        /**
         * Sets up a multicast lock to allow multicast packets.
         */
        private void setupMulticastLock() {
            if (m_wifiMulticastLock == null) {
                final WifiManager wifi = (WifiManager) getSystemService(Context.WIFI_SERVICE);
                m_wifiMulticastLock = wifi.createMulticastLock(MULTICAST_LOCK_TAG);
                m_wifiMulticastLock.setReferenceCounted(true);
            }

            m_wifiMulticastLock.acquire();
            Log.d(TAG, "Multicast lock: " + m_wifiMulticastLock.toString());
        }

        /**
         * Releases the multicast lock if held.
         */
        private void releaseMulticastLock() {
            if (m_wifiMulticastLock != null && m_wifiMulticastLock.isHeld()) {
                m_wifiMulticastLock.release();
                Log.d(TAG, "Multicast lock released.");
            }
        }

        /**
         * Moves the app task to background (same UX as Home button).
         */
        public static void moveTaskToBackApp() {
            if (m_instance == null) {
                Log.w(TAG, "moveTaskToBackApp: activity instance is null");
                return;
            }

            m_instance.runOnUiThread(() -> m_instance.moveTaskToBack(true));
        }

        public static String getSDCardPath() {
            StorageManager storageManager = (StorageManager)m_instance.getSystemService(Activity.STORAGE_SERVICE);
            List<StorageVolume> volumes = storageManager.getStorageVolumes();
            
            for (StorageVolume vol : volumes) {
                if (!vol.isRemovable()) {
                    continue;
                }
                
                String path = null;
                
                // For Android 11+ (API 30+), use the proper getDirectory() method
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    File directory = vol.getDirectory();
                    if (directory != null) {
                        path = directory.getAbsolutePath();
                    }
                } else {
                    // For older versions, use reflection to get the path
                    try {
                        Method mMethodGetPath = vol.getClass().getMethod("getPath");
                        path = (String) mMethodGetPath.invoke(vol);
                    } catch (Exception e) {
                        Log.e(TAG, "Failed to get path via reflection", e);
                        continue;
                    }
                }
                
                if (path != null && !path.isEmpty()) {
                    Log.i(TAG, "removable sd card mounted at " + path);
                    return path;
                }
            }
            
            Log.w(TAG, "No removable SD card found");
            return "";
        }

        /**
         * Checks and requests storage permissions for SD card access.
         * For Android 11+ (API 30+), this requires MANAGE_EXTERNAL_STORAGE permission.
         *
         * @return true if permissions are granted, false otherwise
         */
        public static boolean checkStoragePermissions() {
            if (m_instance == null) {
                Log.e(TAG, "Activity instance is null");
                return false;
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                // Android 11+ (API 30+) requires MANAGE_EXTERNAL_STORAGE for full SD card access
                if (!Environment.isExternalStorageManager()) {
                    Log.i(TAG, "MANAGE_EXTERNAL_STORAGE not granted, requesting...");
                    try {
                        Intent intent = new Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION);
                        intent.setData(Uri.parse("package:" + m_instance.getPackageName()));
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                        m_instance.startActivity(intent);
                    } catch (Exception e) {
                        Log.e(TAG, "Failed to open storage permission settings", e);
                        // Fallback to general settings
                        Intent intent = new Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION);
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                        m_instance.startActivity(intent);
                    }
                    return false;
                }
                Log.i(TAG, "MANAGE_EXTERNAL_STORAGE already granted");
                return true;
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // Android 6.0+ (API 23+) requires runtime permissions
                String[] permissions = {
                    android.Manifest.permission.READ_EXTERNAL_STORAGE,
                    android.Manifest.permission.WRITE_EXTERNAL_STORAGE
                };

                boolean allGranted = true;
                for (String permission : permissions) {
                    if (ContextCompat.checkSelfPermission(m_instance, permission) != PackageManager.PERMISSION_GRANTED) {
                        allGranted = false;
                        break;
                    }
                }

                if (!allGranted) {
                    Log.i(TAG, "Storage permissions not granted, requesting...");
                    ActivityCompat.requestPermissions(m_instance, permissions, 1);
                    return false;
                }

                Log.i(TAG, "Storage permissions already granted");
                return true;
            } else {
                // Below Android 6.0, permissions are granted at install time
                return true;
            }
        }

    // Public MEDIA STORE file access solution with no use of permissions


    public static int openPulseLogFileDescriptor(String displayName,
                                                 String mimeType,
                                                 boolean append) {
        if (m_instance == null || displayName == null || displayName.isEmpty()) {
            return -1;
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                return openPulseLogFileDescriptorMediaStore(displayName, mimeType);
            } else {
                return openPulseLogFileDescriptorLegacy(displayName, append);
            }
        } catch (Exception e) {
            Log.e(TAG, "openPulseLogFileDescriptor failed", e);
            return -1;
        }
    }

    private static int openPulseLogFileDescriptorMediaStore(String displayName,
                                                            String mimeType) throws Exception {
        ContentResolver resolver = m_instance.getContentResolver();

        ContentValues values = new ContentValues();
        values.put(MediaStore.MediaColumns.DISPLAY_NAME, displayName);
        values.put(MediaStore.MediaColumns.MIME_TYPE,
                mimeType == null || mimeType.isEmpty()
                        ? "application/octet-stream"
                        : mimeType);

        // This is the important part:
        // Creates/uses Documents/Pulse, not Documents/Pulse/logs.
        values.put(MediaStore.MediaColumns.RELATIVE_PATH,
                Environment.DIRECTORY_DOCUMENTS + "/Pulse");

        Uri collection = MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY);
        Uri itemUri = resolver.insert(collection, values);

        if (itemUri == null) {
            Log.e(TAG, "MediaStore insert failed for: " + displayName);
            return -1;
        }

        ParcelFileDescriptor pfd = resolver.openFileDescriptor(itemUri, "w");
        if (pfd == null) {
            Log.e(TAG, "Could not open MediaStore fd for: " + displayName);
            return -1;
        }

        Log.i(TAG, "Pulse log created through MediaStore: Documents/Pulse/" + displayName);
        return pfd.detachFd();
    }

    private static int openPulseLogFileDescriptorLegacy(String displayName,
                                                        boolean append) throws Exception {
        File docs = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS);
        File pulseDir = new File(docs, "Pulse");

        if (!pulseDir.exists() && !pulseDir.mkdirs()) {
            Log.e(TAG, "Could not create legacy Pulse directory: " + pulseDir.getAbsolutePath());
            return -1;
        }

        File file = new File(pulseDir, displayName);
        FileOutputStream stream = new FileOutputStream(file, append);

        Log.i(TAG, "Pulse log created legacy path: " + file.getAbsolutePath());
        return ParcelFileDescriptor.dup(stream.getFD()).detachFd();
    }

    public static boolean hasPulseLogFolderAccess() {
        if (m_instance == null) {
            return false;
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            return true;
        }

        return ContextCompat.checkSelfPermission(
                m_instance,
                android.Manifest.permission.WRITE_EXTERNAL_STORAGE
        ) == PackageManager.PERMISSION_GRANTED;
    }

    public static void requestPulseLogFolderAccess() {
        if (m_instance == null) {
            return;
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // No picker and no storage permission required for our own MediaStore-created files.
            return;
        }

        m_instance.runOnUiThread(() -> ActivityCompat.requestPermissions(
                m_instance,
                new String[] {
                        android.Manifest.permission.WRITE_EXTERNAL_STORAGE,
                        android.Manifest.permission.READ_EXTERNAL_STORAGE
                },
                703
        ));
    }

}
