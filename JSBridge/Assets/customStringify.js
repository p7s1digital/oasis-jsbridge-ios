
function __jsBridge__stringify(err) {
    var replaceErrors = function(_key, value) {
        if (value instanceof Error) {
            // Replace Error instance into plain JS objects using Error own properties
            return Object.getOwnPropertyNames(value).reduce(function(acc, key) {
                acc[key] = value[key];
                return acc;
            }, {});
        }

        return value;
    };

    return JSON.stringify(err, replaceErrors);
}
