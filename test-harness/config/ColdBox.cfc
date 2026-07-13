/**
 * ColdBox configuration for listmonk-module test harness.
 */
component {

    function configure() {
        coldbox = {
            appName                  : "listmonk-module-tests",
            reinitPassword           : "",
            handlersIndexAutoReload  : true,
            modulesExternalLocation  : [],
            handlerCaching           : false,
            eventCaching             : false
        };

        environments = {
            development : "localhost,127\.0\.0\.1"
        };

        // Disable auto-module discovery — we register manually in afterAspectsLoad
        modules = {
            include : [],
            exclude : []
        };

        interceptors = [];

        moduleSettings = {
            listmonkModule = {
                baseUrl          : "http://localhost:9002",
                apiToken         : "test-token",
                timeout          : 5,
                subscriberMode   : "external",
                contentType      : "html"
            }
        };
    }

    /**
     * Register the module under test after WireBox is loaded.
     */
    function afterAspectsLoad( event, interceptData, rc, prc ) {
        controller.getModuleService()
            .registerAndActivateModule(
                moduleName     = "listmonkModule",
                invocationPath = "moduleroot"
            );
    }

}
