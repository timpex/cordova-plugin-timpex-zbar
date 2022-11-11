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

        params.validate = params.validate || (() => true);
        function onScanned(value) {
            if (Array.isArray(value)) {
                success(value);
            } else {
                Promise.resolve(value).then(params.validate).then((isValid) => {
                    if (!isValid) {
                        exec(() => {}, () => {}, 'CsZBar', 'addInvalidItem', [value]);    
                    } else if (params.multiscan) {
                        exec(() => {}, () => {}, 'CsZBar', 'addValidItem', [value]);
                    } else {
                        success(value);
                    }
                }, e => {
                    exec(() => {}, () => {}, 'CsZBar', 'addInvalidItem', [value]);
                });
            }

        }
               
        exec(onScanned, failure, 'CsZBar', 'scan', [params]);
    },

};

module.exports = new ZBar;
