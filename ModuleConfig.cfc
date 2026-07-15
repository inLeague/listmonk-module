/**
 * Listmonk Module — ColdBox module for Listmonk email server integration.
 *
 * Provides a typed API client for transactional email, subscribers,
 * lists, templates, and other Listmonk resources via Hyper HTTP client.
 */
component {

	// Module Properties
	this.title          = "Listmonk";
	this.author         = "inLeague LLC";
	this.webURL         = "https://github.com/inLeague/listmonk-module";
	this.description    = "ColdBox module for interacting with a Listmonk email server";
	this.version        = "0.1.0";
	this.modelNamespace = "listmonk";
	this.cfmapping      = "listmonk";
	this.dependencies   = [ "hyper" ];
	this.autoMapModels  = true;

	/**
	 * Configure module settings.
	 *
	 * Settings can be overridden in the host app via:
	 *   moduleSettings = { listmonk = { baseUrl: "...", apiToken: "..." } }
	 */
	function configure() {
		settings = {
			"baseUrl"        : "http://localhost:9002",
			"apiToken"       : "",
			"timeout"        : 30,
			"subscriberMode" : "fallback",
			"contentType"    : "html",
			"defaultTemplateId" : 0
		};

	}

	/**
	 * Register Hyper client after module settings (including host overrides) are merged.
	 * Use onLoad + forceMap (not afterAspectsLoad + map): host apps may construct consumers
	 * (or pre-map this alias) before afterAspectsLoad runs; forceMap refreshes tokens/settings.
	 * @see https://hyper.ortusbooks.com/customizing-hyper/hyper-clients
	 */
	function onLoad() {
		binder
			.forceMap( "ListmonkHyperClient@listmonk" )
			.to( "hyper.models.HyperBuilder" )
			.asSingleton()
			.initWith(
				baseUrl    = settings.baseUrl,
				timeout    = settings.timeout,
				bodyFormat = "json",
				headers    = {
					"Authorization" : "Token #settings.apiToken#",
					"Content-Type"  : "application/json",
					"Accept"        : "application/json"
				}
			);
	}

	/**
	 * Fired when the module is unregistered and unloaded.
	 */
	function onUnload() {
		if ( binder.mappingExists( "ListmonkHyperClient@listmonk" ) ) {
			binder.unMap( "ListmonkHyperClient@listmonk" );
		}
	}

}
