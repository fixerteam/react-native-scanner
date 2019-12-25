package com.scanlibrary;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;

import com.facebook.react.bridge.BaseActivityEventListener;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;

public class DocScannerModule extends ReactContextBaseJavaModule {
    private static final String MODULE_NAME = "DocScanner";
    private static final String ACTIVITY_NOT_FOUND = "E_ACTIVITY_NOT_FOUND";
    private static final String PICKER_CANCELLED = "E_PICKER_CANCELLED";
    private static final String NO_IMAGE_DATA_FOUND = "E_NO_IMAGE_DATA_FOUND";
    private static final String ACTIVITY_NOT_FOUND_MSG = "React activity has destroyed";
    private static final String PICKER_CANCELLED_MSG = "Document scanner was cancelled";
    private static final String NO_IMAGE_DATA_FOUND_MSG = "No image data found";
    private static final int MODULE_REQUEST_CODE = 77;

    private Promise activityResultPromise;

    DocScannerModule(ReactApplicationContext reactContext) {
        super(reactContext);
        reactContext.addActivityEventListener(new BaseActivityEventListener() {
            @Override
            public void onActivityResult(Activity activity, int requestCode, int resultCode, Intent data) {
                if (activityResultPromise != null) {
                    if (requestCode == MODULE_REQUEST_CODE && resultCode == Activity.RESULT_OK) {
                        Bundle extras = data.getExtras();
                        if (extras != null) {
                            Uri uri = extras.getParcelable(ScanConstants.SCANNED_RESULT);
                            if (uri == null) {
                                activityResultPromise.reject(NO_IMAGE_DATA_FOUND, NO_IMAGE_DATA_FOUND_MSG);
                            } else {
                                activityResultPromise.resolve(uri.toString());
                            }
                        } else {
                            activityResultPromise.reject(NO_IMAGE_DATA_FOUND, NO_IMAGE_DATA_FOUND_MSG);
                        }
                    } else {
                        activityResultPromise.reject(PICKER_CANCELLED, PICKER_CANCELLED_MSG);
                    }

                    activityResultPromise = null;

                }
            }
        });
    }

    @Override
    public String getName() {
        return MODULE_NAME;
    }

    @ReactMethod
    public void startScan(String mode, Promise promise) {
        Activity currentActivity = getCurrentActivity();
        if (currentActivity == null) {
            promise.reject(ACTIVITY_NOT_FOUND, ACTIVITY_NOT_FOUND_MSG);
            return;
        }
        activityResultPromise = promise;

        int preference = ScanConstants.OPEN_SELECTOR;
        switch (mode) {
            case "camera": {
                preference = ScanConstants.OPEN_CAMERA;
                break;
            }
            case "gallery": {
                preference = ScanConstants.OPEN_MEDIA;
                break;
            }
        }

        Intent intent = new Intent(currentActivity, ScanActivity.class);
        intent.putExtra(ScanConstants.OPEN_INTENT_PREFERENCE, preference);
        currentActivity.startActivityForResult(intent, MODULE_REQUEST_CODE);
    }
}
