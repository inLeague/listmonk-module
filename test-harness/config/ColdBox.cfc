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
            development : "localhost,127\\.0\\.0\\.1"
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
     * Also register the Hyper client for Listmonk so injection works in tests.
     */
    function afterAspectsLoad( event, interceptData, rc, prc ) {
        // Register the module
        controller.getModuleService()
            .registerAndActivateModule(
                moduleName     = "listmonkModule",
                invocationPath = "moduleroot"
            );

        // Also register the Listmonk Hyper client directly
        // (in case the module's afterAspectsLoad doesn't fire or fires too late)
        var injector = wirebox.getInjector();
        if ( !wirebox.getBinder().mappingExists( "ListmonkHyperClient" ) ) {
            injector.getInstance( "HyperBuilder@hyper" )
                .setBaseUrl( "http://localhost:9002" )
                .setTimeout( 5 )
                .asJson()
                .withHeaders( {
                    "Authorization" : "Token test-token"
                } )
                .registerAs( "ListmonkHyperClient" );
        }
    }

}
