**This repository is looking for a maintainer! If you believe you are the right person, please [leave a comment](https://github.com/tjwoon/csZBar/issues/60)!**



# ZBar Barcode Scanner Plugin

This plugin integrates with the [ZBar](http://zbar.sourceforge.net/) library,
exposing a JavaScript interface for scanning barcodes (QR Code, EAN-13/UPC-A, UPC-E, EAN-8, Code 128, Code 39, Interleaved 2 of 5, etc).
In this fork a button has been added to turn off and on device flash. In addition the plugin can now handle the device orientation change.

## Installation

    cordova plugin add cordova-plugin-cszbar

## API

### Scan barcode

    cloudSky.zBar.scan(params, onSuccess, onFailure)

Arguments:

- **params**: Optional parameters:

    ```javascript
    {
        camera: "front" || "back" // defaults to "back"
        flash: "on" || "off" || "auto" // defaults to "auto". See Quirks
        linearOnly: true || false // allow scanning of 2d codes. If linearOnly is true, a red line will show the active area of the camera. Not setting this will start the scanner in the last mode used.
        multiscan: true || false // allowing to scan multiple times before exiting.
        validate: function (s) {} // Callback function used for validating the scanned qr-/barcode in Javascript. Is valid if no exception is thrown or function returns true.
    }
    ```

- **onSuccess**: function (s) {...} _Callback for successful scan._
- **onFailure**: function (s) {...} _Callback for cancelled scan or error._

Return:

- success('scanned bar code') _Successful scan with value of scanned code_
- error('cancelled') _If user cancelled the scan (with back button etc)_
- error('misc error message') _Misc failure_

Status:

- Android: DONE
- iOS: DONE


## LICENSE [Apache 2.0](LICENSE.md)

This plugin is released under the Apache 2.0 license, but the ZBar library on which it depends (and which is distribute with this plugin) is under the LGPL license (2.1).


## Thanks

Thank you to @PaoloMessina and @nickgerman for code contributions.
