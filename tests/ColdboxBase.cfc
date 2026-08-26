component extends="coldbox.system.testing.BaseTestCase" appMapping="/root" {

	function beforeAll() {
		super.beforeAll();
		variables.wirebox = getController().getWireBox();
		resetListmonkDb();
	}

	/**
	 * Local-only: restart the Listmonk app container (fresh --install).
	 * CI/ACT skip this. The API token is regenerated; reload it from creds.
	 */
	private void function resetListmonkDb() {
		if ( isCiOrAct() ) {
			return;
		}
		var script = expandPath( "/root/docker/reset-listmonk.sh" );
		if ( !fileExists( script ) ) {
			throw( type = "ListmonkTestReset", message = "Listmonk reset script not found at #script#" );
		}
		var result = systemExecute(
			name      = "/bin/bash",
			arguments = [ script ],
			timeout   = 180
		);
		if ( result.timeout ?: false ) {
			throw( type = "ListmonkTestReset", message = "Listmonk reinstall timed out" );
		}
		if ( val( result.exitCode ?: -1 ) != 0 ) {
			throw(
				type    = "ListmonkTestReset",
				message = "Listmonk reinstall failed (exit #val( result.exitCode ?: -1 )#): #result.error ?: ""# #result.output ?: ""#"
			);
		}
		reloadListmonkCreds();
	}

	private boolean function isCiOrAct() {
		var sys = createObject( "java", "java.lang.System" );
		for ( var key in [ "CI", "ACT" ] ) {
			if ( len( trim( server.system.environment[ key ] ?: "" ) ) ) {
				return true;
			}
			var fromJava = sys.getenv( key ); // AI thinks boxlang might not have the value in `server.system.environment`?
			if ( !isNull( fromJava ) && len( trim( fromJava ) ) ) {
				return true;
			}
		}
		return false;
	}

	private void function reloadListmonkCreds() {
		var credsPath = expandPath( "/root/docker/creds/api.json.env" );
		if ( !fileExists( credsPath ) ) {
			throw( type = "ListmonkTest.MissingCreds", message = "Listmonk credentials missing after reinstall at #credsPath#" );
		}
		var creds = deserializeJSON( fileRead( credsPath ) );
		for ( var key in [ "LISTMONK_URL", "LISTMONK_API_USER", "LISTMONK_API_TOKEN" ] ) {
			if ( !creds.keyExists( key ) || !len( creds[ key ] ) ) {
				throw( type = "ListmonkTest.MissingCreds", message = "api.json.env is missing #key# after reinstall" );
			}
		}
		applyListmonkCreds( getController().getSetting( "moduleSettings" ).listmonk, creds );
		applyListmonkCreds( getController().getModuleSettings( "listmonk" ), creds );
	}

	private void function applyListmonkCreds( required struct settings, required struct creds ) {
		arguments.settings.baseUrl  = arguments.creds.LISTMONK_URL;
		arguments.settings.apiUser  = arguments.creds.LISTMONK_API_USER;
		arguments.settings.apiToken = arguments.creds.LISTMONK_API_TOKEN;
	}

}
