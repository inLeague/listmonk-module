/**
 * ColdBox configuration for the listmonk module test harness.
 */
component {

	function configure() {
		coldbox = {
			appName                 : "listmonk-tests",
			reinitPassword          : "",
			handlersIndexAutoReload : true,
			modulesExternalLocation : [],
			handlerCaching          : false,
			eventCaching            : false
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

		// Key matches ModuleConfig this.modelNamespace
		moduleSettings = {
			listmonk : {
				baseUrl        : "http://localhost:9002",
				apiToken       : "test-token",
				timeout        : 5,
				subscriberMode : "external",
				contentType    : "html"
			}
		};
	}

	/**
	 * Register the module under test after WireBox is loaded.
	 * MODULE_NAME is the folder slug; WireBox aliases use modelNamespace "listmonk".
	 */
	function afterAspectsLoad( event, interceptData, rc, prc ) {
		controller
			.getModuleService()
			.registerAndActivateModule(
				moduleName     = request.MODULE_NAME,
				invocationPath = "moduleroot"
			);
	}

}
