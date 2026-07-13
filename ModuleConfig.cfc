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
     * Configure module settings and WireBox bindings.
     *
     * Settings can be overridden in the host app via:
     *   moduleSettings = { listmonkModule = { baseUrl: "...", apiToken: "..." } }
     */
    function configure() {
        settings = {
            // Listmonk server base URL (no trailing slash)
            "baseUrl"          : "http://localhost:9002",
            // API authentication token (Settings > Security in Listmonk admin)
            "apiToken"         : "",
            // HTTP request timeout in seconds
            "timeout"          : 30,
            // Default subscriber mode for transactional sends: "external", "default", "fallback"
            "subscriberMode"   : "external",
            // Default content type: "html" or "plain"
            "contentType"      : "html"
        };

        // WireBox mappings
        wirebox.map( "ListmonkClient" )
            .to( "#this.cfmapping#.models.ListmonkClient" )
            .asSingleton();
    }

    /**
     * Called after WireBox aspects are loaded.
     * Registers the pre-configured Hyper client for Listmonk.
     */
    function onLoad() {
        var baseUrl  = settings.baseUrl;
        var apiToken = settings.apiToken;
        var timeout  = settings.timeout;

        wirebox.getInstance( "HyperBuilder@hyper" )
            .setBaseUrl( baseUrl )
            .setTimeout( timeout )
            .asJson()
            .withHeaders( {
                "Authorization" : "Token #apiToken#"
            } )
            .registerAs( "ListmonkHyperClient" );
    }

    /**
     * Called when the module is unloaded.
     */
    function onUnload() {
    }

}
