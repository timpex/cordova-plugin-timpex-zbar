package no.timpex.zbar;

import org.apache.cordova.CordovaPlugin;

import java.util.ArrayList;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.app.Activity;
import android.content.Intent;
import android.content.Context;
import android.util.Log;

import no.timpex.zbar.ZBarScannerActivity;

public class ZBar extends CordovaPlugin {

    // Configuration ---------------------------------------------------

    private static int SCAN_CODE = 1;

    // Actions ---------------------------------------------------

    private static String ACTION_SCAN = "scan";
    private static String ACTION_ADD_VALID_ITEM = "addValidItem";
    private static String ACTION_ADD_INVALID_ITEM = "addInvalidItem";
    

    // State -----------------------------------------------------------

    private boolean isInProgress = false;
    private CallbackContext scanCallbackContext;
    private boolean isMultiscan = false;
    private static ZBar listener;
    private static ZBarScannerActivity activity;


    // Plugin API ------------------------------------------------------

    @Override
    public boolean execute (String action, JSONArray args, CallbackContext callbackContext)
    throws JSONException
    {
        Context appCtx = cordova.getActivity().getApplicationContext();
        if(ACTION_SCAN.equals(action)) {
            if(isInProgress) {
                callbackContext.error("A scan is already in progress!");
            } else {
                if(listener == null) {
                    listener = this;
                }
                
                isInProgress = true;
                scanCallbackContext = callbackContext;
                JSONObject params = args.optJSONObject(0);
                isMultiscan = params.optBoolean("multiscan", false);
                
                Intent intent = new Intent(appCtx, ZBarScannerActivity.class);
                intent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
                intent.putExtra(ZBarScannerActivity.EXTRA_PARAMS, params.toString());         
                cordova.startActivityForResult(this, intent, SCAN_CODE);
            }
            return true;
        } else if(ACTION_ADD_VALID_ITEM.equals(action)) {
            String value = args.optString(0);
            if(activity != null) {
                activity.addValidValue(value);
            }
            return true;
        } else if(ACTION_ADD_INVALID_ITEM.equals(action)) {
            String value = args.optString(0);
            if(activity != null) {
                activity.addInvalidValue(value);
            }
            return true;
        } else {
            return false;
        }
    }


    // External results handler ----------------------------------------

    @Override
    public void onActivityResult (int requestCode, int resultCode, Intent result)
    {
        if(requestCode == SCAN_CODE) {
            handleSingleScan(resultCode, result);
        }
    }

    private void handleSingleScan(int resultCode, Intent result) {
        String barcodeValue = "";
        switch(resultCode) {
            case Activity.RESULT_OK:
                barcodeValue = result.getStringExtra(ZBarScannerActivity.EXTRA_QRVALUE);
                scanCallbackContext.success(barcodeValue);
                break;
            case Activity.RESULT_CANCELED:
                scanCallbackContext.error("cancelled");
                break;
            case ZBarScannerActivity.RESULT_ERROR:
                scanCallbackContext.error("Scan failed due to an error");
                break;
            case ZBarScannerActivity.RESULT_DONE:
                scanCallbackContext.sendPluginResult(new PluginResult(PluginResult.Status.NO_RESULT));
                break;
            default:
                scanCallbackContext.error("Unknown error");
        }
        onFinish();
    }

    private void onFinish() {
        isInProgress = false;
        scanCallbackContext = null;
        listener = null;
    }

    private PluginResult createPluginResult(String value) {
        PluginResult result = new PluginResult(PluginResult.Status.OK, value);
        result.setKeepCallback(isMultiscan);
        return result;
    }

    public void onMultiScanValue(String value) {
        scanCallbackContext.sendPluginResult(createPluginResult(value));
    }

    public static void setActivity(ZBarScannerActivity zBarScannerActivity) {
        activity = zBarScannerActivity;
    }

    public static void addResult(String value) {
        listener.onMultiScanValue(value);
    }
}
