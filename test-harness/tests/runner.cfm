<cfsetting showDebugOutput="false">
<cfparam name="url.debug" default="false">
<cfparam name="url.reporter" default="simple">
<cfparam name="url.directory" default="tests.specs">
<cfparam name="url.recurse" default="true">
<cfscript>
    testResults = new testbox.system.TestBox(
        bundles      = url.directory,
        recurse      = url.recurse,
        reporter     = url.reporter
    );

    if ( url.debug ) {
        testResults.run( reporter = "simple" );
    } else {
        testResults.run();
        writeOutput( testResults.runreport( url.reporter ) );
    }
</cfscript>
