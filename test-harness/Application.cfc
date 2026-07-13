component {

    this.name              = "listmonk-module-test-harness";
    this.applicationTimeout = createTimespan( 0, 0, 15, 0 );
    this.sessionTimeout    = createTimespan( 0, 0, 15, 0 );
    this.setClientCookies  = true;
    this.scriptProtect     = "none";

    // Mappings
    this.mappings[ "/tests" ] = getDirectoryFromPath( getCurrentTemplatePath() ) & "tests";
    this.mappings[ "/listmonkModule" ] = expandPath( "/listmonkModule" );

    function onApplicationStart() {
        application.coldbox = createObject( "coldbox.system.Coldbox" ).init(
            configLocation = expandPath( "/config/ColdBox.cfc" )
        );
    }

    function onRequestStart( targetPage ) {
        if ( structKeyExists( url, "fwreinit" ) ) {
            application.coldbox.reload( url.fwreinit );
        }
        application.coldbox.processRequest();
    }

    function onMissingTemplate( targetPage ) {
        return false;
    }

}
