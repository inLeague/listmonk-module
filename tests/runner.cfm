<cfsetting showDebugOutput="false">
<cfsetting requesttimeout="999999">
<!---
	Browser: http://127.0.0.1:60299/tests/runner.cfm
	Default reporter is HTML (`simple`) so writeDump() / debug() show on the page.

	CLI (`box testbox run`) passes reporter=json and writes tests/results/.
--->
<cfparam name="url.reporter"            default="simple">
<cfparam name="url.directory"           default="tests.specs">
<cfparam name="url.recurse"             default="true" type="boolean">
<cfparam name="url.bundles"             default="">
<cfparam name="url.labels"              default="">
<cfparam name="url.excludes"            default="">
<cfparam name="url.reportpath"          default="#expandPath( '/tests/results' )#">
<cfparam name="url.propertiesFilename"  default="TEST.properties">
<cfparam name="url.propertiesSummary"   default="true" type="boolean">
<cfparam name="url.editor"              default="vscode">
<cfparam name="url.bundlesPattern"      default="*Spec*.cfc|*Test*.cfc|*Spec*.bx|*Test*.bx">
<cfparam name="url.coverageEnabled"     default="false" type="boolean">
<cfscript>
	if ( !directoryExists( url.reportpath ) ) {
		directoryCreate( url.reportpath, true, true );
	}
</cfscript>
<cfinclude template="/testbox/system/runners/HTMLRunner.cfm">
