/**
 * Test harness application for listmonk-module.
 *
 * MODULE_NAME matches the repository / ForgeBox folder slug used for
 * registerAndActivateModule. WireBox aliases use modelNamespace "listmonk"
 * from ModuleConfig.cfc.
 */
component {

	// Folder slug used by registerAndActivateModule( moduleroot / MODULE_NAME )
	request.MODULE_NAME = "listmonk-module";

	// Application properties
	this.name              = hash( getCurrentTemplatePath() );
	this.sessionManagement = true;
	this.sessionTimeout    = createTimespan( 0, 0, 15, 0 );
	this.setClientCookies  = true;

	// COLDBOX STATIC PROPERTY, DO NOT CHANGE UNLESS THIS IS NOT THE ROOT OF YOUR COLDBOX APP
	COLDBOX_APP_ROOT_PATH = getDirectoryFromPath( getCurrentTemplatePath() );
	// The web server mapping to this application. Used for remote purposes or static purposes
	COLDBOX_APP_MAPPING   = "";
	// COLDBOX PROPERTIES
	COLDBOX_CONFIG_FILE   = "";
	// COLDBOX APPLICATION KEY OVERRIDE
	COLDBOX_APP_KEY       = "";

	// Mappings
	this.mappings[ "/root" ] = COLDBOX_APP_ROOT_PATH;

	// Map back to its root (Ortus module-template pattern)
	moduleRootPath = REReplaceNoCase(
		this.mappings[ "/root" ],
		"#request.MODULE_NAME#(\\|/)test-harness(\\|/)",
		""
	);
	modulePath = REReplaceNoCase(
		this.mappings[ "/root" ],
		"test-harness(\\|/)",
		""
	);

	// Module Root + Path Mappings
	this.mappings[ "/moduleroot" ]             = moduleRootPath;
	this.mappings[ "/#request.MODULE_NAME#" ]  = modulePath;
	// CF mapping from ModuleConfig this.cfmapping
	this.mappings[ "/listmonk" ]               = modulePath;
	this.mappings[ "/tests" ]                  = COLDBOX_APP_ROOT_PATH & "tests";

	// Hyper module mapping
	this.mappings[ "/hyper" ] = COLDBOX_APP_ROOT_PATH & "modules/hyper";

	/**
	 * Application start — bootstrap ColdBox.
	 */
	public boolean function onApplicationStart() {
		application.cbBootstrap = new coldbox.system.Bootstrap(
			COLDBOX_CONFIG_FILE,
			COLDBOX_APP_ROOT_PATH,
			COLDBOX_APP_KEY,
			COLDBOX_APP_MAPPING
		);
		application.cbBootstrap.loadColdbox();
		return true;
	}

	/**
	 * Request start — process through ColdBox.
	 */
	public boolean function onRequestStart( String targetPage ) {
		application.cbBootstrap.onRequestStart( arguments.targetPage );
		return true;
	}

	public void function onSessionStart() {
		application.cbBootstrap.onSessionStart();
	}

	public void function onSessionEnd( struct sessionScope, struct appScope ) {
		application.cbBootstrap.onSessionEnd( argumentCollection = arguments );
	}

	public boolean function onMissingTemplate( template ) {
		return application.cbBootstrap.onMissingTemplate( argumentCollection = arguments );
	}

}
