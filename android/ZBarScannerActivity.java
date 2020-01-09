package no.timpex.zbar;

import java.io.IOException;
import java.lang.RuntimeException;
import org.json.JSONException;
import org.json.JSONObject;
import org.json.JSONArray;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog.Builder;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.content.res.Configuration;
import android.content.res.Resources;
import android.content.Context;
import android.content.SharedPreferences;
import android.hardware.Camera;
import android.hardware.Camera.CameraInfo;
import android.hardware.Camera.Parameters;
import android.hardware.Camera.PreviewCallback;
import android.hardware.Camera.AutoFocusCallback;
import android.os.Bundle;
import android.os.Handler;
import android.support.v4.app.ActivityCompat;
import android.support.v4.content.ContextCompat;
import android.util.Log;
import android.view.Gravity;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.view.ViewGroup;
import android.widget.RelativeLayout;
import android.widget.TextView;
import android.widget.Button;
import android.widget.ImageButton;
import android.widget.Toast;
import android.content.pm.PackageManager;
import android.view.Surface;

import java.util.ArrayList;
import java.util.Collection;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.Arrays;

import net.sourceforge.zbar.ImageScanner;
import net.sourceforge.zbar.Image;
import net.sourceforge.zbar.Symbol;
import net.sourceforge.zbar.SymbolSet;
import net.sourceforge.zbar.Config;

public class ZBarScannerActivity extends Activity
implements SurfaceHolder.Callback, View.OnClickListener {

    //for barcode types
    private Collection<ZBarcodeFormat> mFormats = null;

    // Config ----------------------------------------------------------

    private static int autoFocusInterval = 2000; // Interval between AFcallback and next AF attempt.

    // Public Constants ------------------------------------------------

    public static final String EXTRA_QRVALUE = "qrValue";
    public static final String EXTRA_PARAMS = "params";
    public static final int RESULT_ERROR = RESULT_FIRST_USER + 1;
    public static final int RESULT_DONE = RESULT_ERROR + 1;
    private static final int CAMERA_PERMISSION_REQUEST = 1;
    // State -----------------------------------------------------------

    private Camera camera;
    private Handler autoFocusHandler;
    private SurfaceView scannerSurface;
    private SurfaceHolder holder;
    private ImageScanner scanner;
    private int surfW, surfH;
    private ArrayList<String> scannedValues = new ArrayList<String>();
    private Toast toast = null;
    private Handler delayHandler;
    private boolean isScanBlocked = false;
    private int validCounter = 0;

    // Customisable stuff
    String whichCamera;
    String flashMode;
    private boolean inQrMode;
    private boolean multiscan;

    // Validator arrays
    private JSONArray allowedLengths;    
    private JSONArray barcodeMayContain;

    // For retrieving R.* resources, from the actual app package
    // (we can't use actual.application.package.R.* in our code as we
    // don't know the applciation package name when writing this plugin).
    private String package_name;
    private Resources resources;

    // Static initialisers (class) -------------------------------------

    static {
        // Needed by ZBar??
        System.loadLibrary("iconv");
    }

    // Activity Lifecycle ----------------------------------------------

    @Override
    public void onCreate (Bundle savedInstanceState) {
        setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_NOSENSOR);

        int permissionCheck = ContextCompat.checkSelfPermission(this.getBaseContext(), Manifest.permission.CAMERA);

        if(permissionCheck == PackageManager.PERMISSION_GRANTED){

            setUpCamera();

        } else {

            ActivityCompat.requestPermissions(this,
                    new String[]{Manifest.permission.CAMERA},
                    CAMERA_PERMISSION_REQUEST);
        }

        ZBar.setActivity(this);
        super.onCreate(savedInstanceState);


    }
    public void onRequestPermissionsResult(int requestCode,
                                           String permissions[], int[] grantResults) {
        switch (requestCode) {
            case CAMERA_PERMISSION_REQUEST: {
                if (grantResults.length > 0
                        && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    setUpCamera();
                } else {

                   onBackPressed();
                }
                return;
            }

            // other 'case' lines to check for other
            // permissions this app might request
        }
    }
    private void setUpCamera() {
        // If request is cancelled, the result arrays are empty.

        // Get parameters from JS 
        Intent startIntent = getIntent();
        String paramStr = startIntent.getStringExtra(EXTRA_PARAMS);
        JSONObject params;
        try { params = new JSONObject(paramStr); }
        catch (JSONException e) { params = new JSONObject(); }
        whichCamera = params.optString("camera");
        flashMode = params.optString("flash");
        barcodeMayContain = params.optJSONArray("barcode_may_contain");
        allowedLengths = params.optJSONArray("allowed_lengths");
        multiscan = params.optBoolean("multiscan", false);

        // Initiate instance variables
        autoFocusHandler = new Handler();
        scanner = new ImageScanner();
        toast = Toast.makeText(getApplicationContext(), "", Toast.LENGTH_SHORT);
        delayHandler = new Handler();


        // Set the config for barcode formats
        for(ZBarcodeFormat format : getFormats()) {
            scanner.setConfig(format.getId(), Config.ENABLE, 1);
        }

        // Set content view
        setContentView(getResourceId("layout/cszbarscanner"));

        // Draw/hide the sight
        findViewById(getResourceId("id/csZbarScannerSight")).setVisibility(View.INVISIBLE);
        android.widget.ImageButton switchModeButton = (android.widget.ImageButton) findViewById(getResourceId("id/csZbarSwitchModeButton"));
        switchModeButton.setOnClickListener(this);

        // Create preview SurfaceView
        scannerSurface = new SurfaceView (this) {
            @Override
            public void onSizeChanged (int w, int h, int oldW, int oldH) {
                surfW = w;
                surfH = h;
                matchSurfaceToPreviewRatio();
            }
        };
        RelativeLayout.LayoutParams layout = new RelativeLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
        );
        layout.addRule(RelativeLayout.CENTER_IN_PARENT);
        scannerSurface.setLayoutParams(layout);
        scannerSurface.getHolder().addCallback(this);

        // Add preview SurfaceView to the screen
        RelativeLayout scannerView = (RelativeLayout) findViewById(getResourceId("id/csZbarScannerView"));
        scannerView.addView(scannerSurface);

        findViewById(getResourceId("id/doneButton")).bringToFront();
        findViewById(getResourceId("id/csZbarScannerSight")).bringToFront();
        findViewById(getResourceId("id/csZbarSwitchModeButton")).bringToFront();
        findViewById(getResourceId("id/csZbarScannedItems")).bringToFront();
        findViewById(getResourceId("id/csZbarToolbar")).bringToFront();
        findViewById(getResourceId("id/csZbarValidCounter")).bringToFront();
        findViewById(getResourceId("id/csZbarScannerOverlay")).bringToFront();
        scannerView.requestLayout();
        scannerView.invalidate();

        if(params.has("linearOnly")) {
            inQrMode = !params.optBoolean("linearOnly", false);
        } else {
            getStoredQrMode();
        }

        updateViewAndButton(false);
    }

	private void getStoredQrMode() {
        final SharedPreferences sharedPref = this.getPreferences(Context.MODE_PRIVATE);
        if(sharedPref.contains("timpex-zbar-inQrMode")) {
            inQrMode = sharedPref.getBoolean("timpex-zbar-inQrMode", false);
        } else {
            inQrMode = true;
        }
	}

    @Override
    public void onResume ()
    {
        super.onResume();

        try {
            if(whichCamera.equals("front")) {
                int numCams = Camera.getNumberOfCameras();
                CameraInfo cameraInfo = new CameraInfo();
                for(int i=0; i<numCams; i++) {
                    Camera.getCameraInfo(i, cameraInfo);
                    if(cameraInfo.facing == CameraInfo.CAMERA_FACING_FRONT) {
                        camera = Camera.open(i);
                    }
                }
            } else {
                camera = Camera.open();
            }

            if(camera == null) throw new Exception ("Error: No suitable camera found.");
        } catch (RuntimeException e) {
            //die("Error: Could not open the camera.");
            return;
        } catch (Exception e) {
           // die(e.getMessage());
            return;
        }
    }
    private void setCameraDisplayOrientation(Activity activity ,int cameraId) {
        android.hardware.Camera.CameraInfo info =
                new android.hardware.Camera.CameraInfo();
        android.hardware.Camera.getCameraInfo(cameraId, info);
        int rotation = activity.getWindowManager().getDefaultDisplay()
                .getRotation();
        int degrees = 0;
        switch (rotation) {
            case Surface.ROTATION_0: degrees = 0; break;
            case Surface.ROTATION_90: degrees = 90; break;
            case Surface.ROTATION_180: degrees = 180; break;
            case Surface.ROTATION_270: degrees = 270; break;
        }

        int result;
        if (info.facing == Camera.CameraInfo.CAMERA_FACING_FRONT) {
            result = (info.orientation + degrees) % 360;
            result = (360 - result) % 360;  // compensate the mirror
        } else {  // back-facing
            result = (info.orientation - degrees + 360) % 360;
        }
        camera.setDisplayOrientation(result);
    }
    @Override
    public void onPause ()
    {
        releaseCamera();
        super.onPause();
    }

    @Override
    public void onDestroy ()
    {
        setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_SENSOR);
        if(scanner != null) scanner.destroy();
        super.onDestroy();
    }

    // Event handlers --------------------------------------------------

    @Override
    public void onBackPressed ()
    {
        setResult(RESULT_CANCELED);
        super.onBackPressed();
    }

    // SurfaceHolder.Callback implementation ---------------------------

    @Override
    public void surfaceCreated (SurfaceHolder hld)
    {
        tryStopPreview();
        holder = hld;
        tryStartPreview();
    }

    @Override
    public void surfaceDestroyed (SurfaceHolder holder)
    {
        // No surface == no preview == no point being in this Activity.
        die("The camera surface was destroyed");
    }

    @Override
    public void surfaceChanged (SurfaceHolder hld, int fmt, int w, int h)
    {
        // Sanity check - holder must have a surface...
        if(hld.getSurface() == null) die("There is no camera surface");

        surfW = w;
        surfH = h;
        matchSurfaceToPreviewRatio();

        tryStopPreview();
        holder = hld;
        tryStartPreview();
    }
    public void onConfigurationChanged(Configuration newConfig)
    {
        super.onConfigurationChanged(newConfig);
        int rotation = getWindowManager().getDefaultDisplay().getRotation();
        switch(rotation)
        {
        case 0: // '\0'
            rotation = 90;
            break;

        case 1: // '\001'
            rotation = 0;
            break;

        case 2: // '\002'
            rotation = 270;
            break;

        case 3: // '\003'
            rotation = 180;
            break;

        default:
            rotation = 90;
            break;
        }
        camera.setDisplayOrientation(rotation);
        android.hardware.Camera.Parameters params = camera.getParameters();
        tryStopPreview();
        tryStartPreview();

    }

    public void toggleFlash(View view) {
		camera.startPreview();
        android.hardware.Camera.Parameters camParams = camera.getParameters();
        //If the flash is set to off
        try {
            if (camParams.getFlashMode().equals(Parameters.FLASH_MODE_OFF) && !(camParams.getFlashMode().equals(Parameters.FLASH_MODE_TORCH)) && !(camParams.getFlashMode().equals(Parameters.FLASH_MODE_ON)))
                camParams.setFlashMode(Parameters.FLASH_MODE_TORCH);
            else //if(camParams.getFlashMode() == Parameters.FLASH_MODE_ON || camParams.getFlashMode()== Parameters.FLASH_MODE_TORCH)
                camParams.setFlashMode(Parameters.FLASH_MODE_OFF);
        }   catch(RuntimeException e) {

        }

		try {
            camera.setPreviewDisplay(holder);
            camera.setPreviewCallback(previewCb);
            camera.startPreview();
            if (android.os.Build.VERSION.SDK_INT >= 14) {
                camera.autoFocus(autoFocusCb); // We are not using any of the
                    // continuous autofocus modes as that does not seem to work
                    // well with flash setting of "on"... At least with this
                    // simple and stupid focus method, we get to turn the flash
                    // on during autofocus.
                camParams.setFocusMode(Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE);
            }

            camera.setParameters(camParams);
        } catch(RuntimeException e) {
            Log.d("csZBar", (new StringBuilder("Unsupported camera parameter reported for flash mode: ")).append(flashMode).toString());
        } catch (IOException e) {
        	Log.d("csZBar", (new StringBuilder("Wrong holder data")).append(flashMode).toString());
		}
    }
    // Continuously auto-focus -----------------------------------------
    // For API Level < 14

    private AutoFocusCallback autoFocusCb = new AutoFocusCallback()
    {
        public void onAutoFocus(boolean success, Camera camera) {
            // some devices crash without this try/catch and cancelAutoFocus()... (#9)
            try {
                camera.cancelAutoFocus();
                autoFocusHandler.postDelayed(doAutoFocus, autoFocusInterval);
            } catch (Exception e) {}
        }
    };

    private Runnable doAutoFocus = new Runnable()
    {
        public void run() {
            if(camera != null) camera.autoFocus(autoFocusCb);
        }
    };

    // Camera callbacks ------------------------------------------------

    // Receives frames from the camera and checks for barcodes.
    private PreviewCallback previewCb = new PreviewCallback()
    {
        public void onPreviewFrame(byte[] data, Camera camera) {
            if(isScanBlocked) return;
            Camera.Parameters parameters = camera.getParameters();
            Camera.Size size = parameters.getPreviewSize();
            Image barcode;

            if(!inQrMode) {
                barcode = new Image(size.width, 3, "Y800");
                byte[] dataFrame = getSliceOfImage(data, size.width, size.height);
                barcode.setData(dataFrame);
            } else {
                barcode = new Image(size.width, size.height, "Y800");
                barcode.setData(data);
            }

            if (scanner.scanImage(barcode) != 0) {
                String qrValue = "";
                delay(500);

                SymbolSet syms = scanner.getResults();
                for (Symbol sym : syms) {
                    qrValue = sym.getData();
                    
                    if (!isValidBarcode(qrValue)) {
                        toast.setText("QR/Barcode is invalid!");
                        toast.show();
                        continue;
                    }

                    if (scannedValues.contains(qrValue)) {
                        toast.setText("QR/Barcode has already been scanned!");
                        toast.show();
                        continue;
                    }

                    // Return 1st found QR code value to the calling Activity.
                    Intent result = new Intent ();
                    result.putExtra(EXTRA_QRVALUE, qrValue);
                    if(!multiscan) {
                        setResult(Activity.RESULT_OK, result);
                        finish();
                    } else {
                        toast.cancel();
                        scannedValues.add(qrValue);
                        ZBar.addResult(qrValue);
                    }
                }

            }
        }
    };

    private void delay(int ms) {
        isScanBlocked = true;
        delayHandler.postDelayed(new Runnable() {
            @Override
            public void run() {
                isScanBlocked = false; 
            }
        }, ms);
    }

    private boolean isValidBarcode(String qrValue) {
        return barcodeIsOfLength(qrValue) || barcodeContainsSubstring(qrValue);
    }

    private boolean barcodeIsOfLength(String qrValue) {
        if (allowedLengths == null)
            return true;
        for (int i = 0; i < allowedLengths.length(); i++) {
            try {
                if (allowedLengths.getInt(i) == qrValue.length())
                    return true;
            } catch (JSONException e) {
            }
        }
        return false;
    }
        

    private boolean barcodeContainsSubstring(String qrValue) {
        if (barcodeMayContain == null)
            return true;
        for (int i = 0; i < barcodeMayContain.length(); i++) {
            try {
                if (qrValue.contains(barcodeMayContain.getString(i)))
                    return true;
            } catch (JSONException e) {
            }
        }
        return false;
    }

    private byte[] getSliceOfImage(byte[] data, int width, int height) {
        if(width < height) {
            return Arrays.copyOfRange(data, width * (height/2 - 1), width * (height/2 + 1));
        }

        byte[] dataFrame = new byte[height];
        for(int i = 0; i < height; i++) {
            dataFrame[i] = data[i*width + width/2];
        }
        return dataFrame;
    }

    // Misc ------------------------------------------------------------

    // finish() due to error
    private void die (String msg)
    {
        setResult(RESULT_ERROR);
        finish();
    }

    private int getResourceId (String typeAndName)
    {
        if(package_name == null) package_name = getApplication().getPackageName();
        if(resources == null) resources = getApplication().getResources();
        return resources.getIdentifier(typeAndName, null, package_name);
    }

    // Release the camera resources and state.
    private void releaseCamera ()
    {
        if (camera != null) {
            autoFocusHandler.removeCallbacks(doAutoFocus);
            camera.setPreviewCallback(null);
            camera.release();
            camera = null;
        }
    }

    // Match the aspect ratio of the preview SurfaceView with the camera's preview aspect ratio,
    // so that the displayed preview is not stretched/squashed.
    private void matchSurfaceToPreviewRatio () {
        if(camera == null) return;
        if(surfW == 0 || surfH == 0) return;

        // Resize SurfaceView to match camera preview ratio (avoid stretching).
        Camera.Parameters params = camera.getParameters();
        Camera.Size size = params.getPreviewSize();
        float previewRatio = (float) size.height / size.width; // swap h and w as the preview is rotated 90 degrees
        float surfaceRatio = (float) surfW / surfH;
        RelativeLayout.LayoutParams layout;

        if(previewRatio > surfaceRatio) {
            layout = new RelativeLayout.LayoutParams(
                surfW,
                Math.round((float) surfW / previewRatio)
            );
        } else {
            layout = new RelativeLayout.LayoutParams(
                Math.round((float) surfH * previewRatio),
                surfH
            );
        }

        layout.addRule(RelativeLayout.CENTER_IN_PARENT);
        scannerSurface.setLayoutParams(layout);
    }

    // Stop the camera preview safely.
    private void tryStopPreview () {
        // Stop camera preview before making changes.
        try {
            camera.stopPreview();
        } catch (Exception e){
          // Preview was not running. Ignore the error.
        }
    }

    public Collection<ZBarcodeFormat> getFormats() {
        if(mFormats == null) {
            return ZBarcodeFormat.ALL_FORMATS;
        }
        return mFormats;
    }


    // Start the camera preview if possible.
    // If start is attempted but fails, exit with error message.
    private void tryStartPreview () {
        if(holder != null) {
            try {
                int rotation = getWindowManager().getDefaultDisplay().getRotation();
                switch(rotation)
                {
                case 0: // '\0'
                    rotation = 90;
                    break;

                case 1: // '\001'
                    rotation = 0;
                    break;

                case 2: // '\002'
                    rotation = 270;
                    break;

                case 3: // '\003'
                    rotation = 180;
                    break;

                default:
                    rotation = 90;
                    break;
                }
                // 90 degrees rotation for Portrait orientation Activity.
                setCameraDisplayOrientation(this, 0);

                android.hardware.Camera.Parameters camParams = camera.getParameters();

                try {
                   camParams.setFocusMode(Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE);
                   camera.setParameters(camParams);
                } catch (Exception e) {
					// TODO: don't swallow
                }

                camera.setPreviewDisplay(holder);
                camera.setPreviewCallback(previewCb);
                camera.startPreview();

                if (android.os.Build.VERSION.SDK_INT >= 14) {
                    camera.autoFocus(autoFocusCb); // We are not using any of the
                        // continuous autofocus modes as that does not seem to work
                        // well with flash setting of "on"... At least with this
                        // simple and stupid focus method, we get to turn the flash
                        // on during autofocus.
                }
            } catch (IOException e) {
                die("Could not start camera preview: " + e.getMessage());
            }
        }
    }

    @Override
    public void onClick(View v) {
        this.inQrMode = !this.inQrMode;
        this.updateViewAndButton(true);
    }

    public void updateViewAndButton(boolean shouldUpdatePrefs) {
        if(inQrMode) {
            findViewById(getResourceId("id/csZbarScannerSight")).setVisibility(View.INVISIBLE);
            android.widget.ImageButton button = (android.widget.ImageButton) findViewById(getResourceId("id/csZbarSwitchModeButton"));
            button.setImageResource(getResourceId("drawable/qrcode"));
            scanner.setConfig(0, Config.X_DENSITY, 3);
            scanner.setConfig(0, Config.Y_DENSITY, 3);
        } else {
            findViewById(getResourceId("id/csZbarScannerSight")).setVisibility(View.VISIBLE);
            android.widget.ImageButton button = (android.widget.ImageButton) findViewById(getResourceId("id/csZbarSwitchModeButton"));
            button.setImageResource(getResourceId("drawable/barcode"));
            scanner.setConfig(0, Config.X_DENSITY, 6);
            scanner.setConfig(0, Config.Y_DENSITY, 1);
        }
        if(!shouldUpdatePrefs) return;

        SharedPreferences sharedPref = this.getPreferences(Context.MODE_PRIVATE);
        sharedPref.edit().putBoolean("timpex-zbar-inQrMode", inQrMode).apply();
    }

    public void flashOverlayView(int color) {
        View overlayView = findViewById(getResourceId("id/csZbarScannerOverlay"));      
        overlayView.setBackgroundColor(color);
        overlayView.setAlpha(0f);
        overlayView.animate()
        .alpha(0.8f)
        .setDuration(200)
        .setListener(null);

        overlayView.setAlpha(0.8f);
        overlayView.animate()
        .alpha(0f)
        .setDuration(200)
        .setListener(null);
    }

    public void onDone(View view) {
        setResult(RESULT_DONE);
        finish();
    }
   
    public void addValidValue(String value) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                incrementValidCounter();
                flashOverlayView(0xFF00FF00);
                addLabelValue(value, 0xFFFFFFFF);
            }
        });
    }

    public void addInvalidValue(String value) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                flashOverlayView(0xFFFF0000);
                addLabelValue(value, 0xFFFF0000);
            }
        });
    }

    private void incrementValidCounter() {
        TextView textView = (TextView) findViewById(getResourceId("id/csZbarValidCounter"));
        validCounter += 1;
        textView.setText(String.valueOf(validCounter));
    }

    private void addLabelValue(String value, int color) {
        handleLabel2AndLabel3();
        TextView label1 = (TextView) findViewById(getResourceId("id/csZbarScannerLabel1"));
        label1.setVisibility(View.VISIBLE);
        label1.setText(value);
        label1.setTextColor(color);
    }

    private void handleLabel2AndLabel3() {
        TextView label1 = (TextView) findViewById(getResourceId("id/csZbarScannerLabel1"));
        TextView label2 = (TextView) findViewById(getResourceId("id/csZbarScannerLabel2"));
        TextView label3 = (TextView) findViewById(getResourceId("id/csZbarScannerLabel3"));
        label3.setText(label2.getText());
        label3.setTextColor(label2.getTextColors());
        label3.setVisibility(label2.getVisibility());
        label2.setText(label1.getText());
        label2.setTextColor(label1.getTextColors());
        label2.setVisibility(label1.getVisibility());
    }

    @Override
    public void finish() {
        scannedValues = null;
        validCounter = 0;
        super.finish();
    }
}
