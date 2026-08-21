/**
 * ColdBox + TestBox application for top-level specs.
 *
 * The module under test is at tests/modules/listmonk (symlink to the checkout),
 * which is ColdBox's conventional modules folder for this app.
 *
 * BoxLang applies this.mappings after onApplicationStart; loadColdBox() waits
 * until the first request so /root/modules resolves.
 */
component {

	this.name              = "listmonkTests";
	this.sessionManagement = true;
	this.sessionTimeout    = createTimespan( 0, 0, 15, 0 );
	this.setClientCookies  = true;

	COLDBOX_APP_ROOT_PATH = getDirectoryFromPath( getCurrentTemplatePath() );
	COLDBOX_APP_MAPPING   = "/root";
	COLDBOX_CONFIG_FILE   = "";
	COLDBOX_APP_KEY       = "";

	repoRoot = reReplaceNoCase( COLDBOX_APP_ROOT_PATH, "tests[\\/]?$", "" );
	repoRoot = reReplace( repoRoot, "[\\/]+$", "" );

	coldboxPath = directoryExists( repoRoot & "/coldbox" )
		? repoRoot & "/coldbox"
		: repoRoot & "/test-harness/coldbox";

	this.mappings = {
		"/tests"    : COLDBOX_APP_ROOT_PATH,
		"/root"     : COLDBOX_APP_ROOT_PATH,
		"/listmonk" : repoRoot,
		"/testbox"  : repoRoot & "/testbox",
		"/hyper"    : repoRoot & "/modules/hyper",
		"/coldbox"  : coldboxPath
	};

	public boolean function onApplicationStart() {
		return true;
	}

	public boolean function onRequestStart( string targetPage ) {
		loadColdBox();
		application.cbBootstrap.onRequestStart( arguments.targetPage );
		return true;
	}

	public void function onSessionStart() {
		loadColdBox();
		application.cbBootstrap.onSessionStart();
	}

	public void function onSessionEnd( struct sessionScope, struct appScope ) {
		if ( !isNull( application.cbBootstrap ) ) {
			application.cbBootstrap.onSessionEnd( argumentCollection = arguments );
		}
	}

	public boolean function onMissingTemplate( template ) {
		loadColdBox();
		return application.cbBootstrap.onMissingTemplate( argumentCollection = arguments );
	}

	/**
	 * ColdBox must start after this.mappings are live so /root/modules exists.
	 */
	private void function loadColdBox() {
		if ( !isNull( application.cbBootstrap ) ) {
			return;
		}
		lock name="listmonkTests.coldbox.boot" type="exclusive" timeout="60" {
			if ( !isNull( application.cbBootstrap ) ) {
				return;
			}
			application.cbBootstrap = new coldbox.system.Bootstrap(
				COLDBOX_CONFIG_FILE,
				COLDBOX_APP_ROOT_PATH,
				COLDBOX_APP_KEY,
				COLDBOX_APP_MAPPING
			);
			application.cbBootstrap.loadColdbox();
		}
	}

}
