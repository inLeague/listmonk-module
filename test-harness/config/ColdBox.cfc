component {

    function configure() {
        coldbox = {
            appName          : "listmonk-module-tests",
            appMapping       : "/",
            reinitPassword   : "",
            HandlersIndexAutoReload : true,
            handlerAutoReload       : true
        };

        modules = {
            "listmonkModule" : {
                settings : {
                    baseUrl   : "http://localhost:9002",
                    apiToken  : "test-token",
                    timeout   : 5,
                    subscriberMode : "external",
                    contentType   : "html"
                }
            }
        };
    }

}
