/**
 * Listmonk Module — ColdBox module for Listmonk email server integration.
 *
 * Provides a typed API client for transactional email, subscribers,
 * lists, templates, and other Listmonk resources via Hyper HTTP client.
 *
 * Models under models/ are auto-mapped as {Name}@listmonk
 * (ListmonkClient@listmonk, ListmonkResponse@listmonk).
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
	 * Settings can be overridden in the host app via:
	 *   moduleSettings = { listmonk = { baseUrl: "...", apiToken: "..." } }
	 */
	function configure() {
		settings = {
			"baseUrl"           : "http://localhost:9002",
			"apiToken"          : "",
			"timeout"           : 30,
			"subscriberMode"    : "fallback",
			"contentType"       : "html",
			"defaultTemplateId" : 0
		};
	}

}
