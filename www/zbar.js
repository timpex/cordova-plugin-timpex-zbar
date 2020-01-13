var argscheck = require('cordova/argscheck'),
    exec      = require('cordova/exec');

function ZBar () {};

ZBar.prototype = {

    scan: function (params, success, failure)
    {
        argscheck.checkArgs('*fF', 'CsZBar.scan', arguments);

        params = params || {};
        if(params.camera != "front") params.camera = "back";
        if(params.flash != "on" && params.flash != "off") params.flash = "auto";
        if(params.multiscan === undefined) params.multiscan = false;

        params.onScanned = params.onScanned || (() => true);
        function onScanned(value) {
            Promise.resolve(value).then(params.onScanned).then(() => {
                if(params.multiscan) {
                    exec(() => {}, () => {}, 'CsZBar', 'addValidItem', [value]);
                }
                
                success(value);
            }, e => {
                exec(() => {}, () => {}, 'CsZBar', 'addInvalidItem', [value]);
            });
        }
               
        exec(onScanned, failure, 'CsZBar', 'scan', [params]);
    },

};

module.exports = new ZBar;
