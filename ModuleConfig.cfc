/**
 * Listmonk Module — ColdBox module for Listmonk email server integration.
 *
 * Provides a typed API client for transactional email, subscribers,
 * lists, templates, and other Listmonk resources via Hyper HTTP client.
 */
component {

    // Module Properties
    this.title       = "Listmonk Module";
    this.author      = "inLeague LLC";
    this.webURL      = "https://github.com/inLeague/listmonk-module";
    this.description = "ColdBox module for interacting with a Listmonk email server";
    this.version     = "0.1.0";
    this.cfmapping   = "listmonkModule";
    this.dependencies = [ "hyper" ];

    /**
     * Configure module settings and WireBox mappings.
     *
     * Settings can be overridden in the host app via:
     *   moduleSettings = { listmonkModule = { baseUrl: "...", apiToken: "..." } }
     */
    function configure() {
        settings = {
            "baseUrl"          : "http://localhost:9002",
            "apiToken"         : "",
            "timeout"          : 30,
            "subscriberMode"   : "external",
            "contentType"      : "html"
        };

        // WireBox mappings — ListmonkClient gets its HyperBuilder via init()
        wirebox.map( "ListmonkClient" )
            .to( "#this.cfmapping#.models.ListmonkClient" )
            .asSingleton();
    }

    /**
     * Called after WireBox aspects are loaded.
     * Registers the pre-configured Hyper client for Listmonk.
     *
     * Follows the Hyper docs pattern for custom HTTP clients:
     * https://hyper.ortusbooks.com/customizing-hyper/hyper-clients
     */
    function afterAspectsLoad() {
        var injector = wirebox.getInjector();

        injector.getInstance( "HyperBuilder@hyper" )
            .setBaseUrl( settings.baseUrl )
            .setTimeout( settings.timeout )
            .asJson()
            .withHeaders( {
                "Authorization" : "Token #settings.apiToken#"
            } )
            .registerAs( "ListmonkHyperClient" );
    }

    function onUnload() {
    }

}
