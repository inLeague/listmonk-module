<cfsetting showDebugOutput="false">
<cfparam name="url.reporter" default="text">
<cfparam name="url.directory" default="tests.specs">
<cfparam name="url.recurse" default="true">
<cfscript>
	testResults = new testbox.system.TestBox(
		directory = url.directory,
		recurse   = url.recurse,
		reporter  = url.reporter
	);

	writeOutput( testResults.run() );
</cfscript>
