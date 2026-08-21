/**
 * Canary spec — always fails so we can confirm the runner works.
 * Delete this file once CLI results and the browser runner both show the failure.
 */
component extends="tests.ColdboxBase" {

	function beforeAll() {
		super.beforeAll()
		wirebox.clearSingletons();
	}

	function run() {
		describe( "test runner canary", function() {
			it( "fails on purpose so we can see a failure in CLI and browser", function() {
				var listMonkClient = wirebox.getInstance( "ListMonkClient@listmonk" );

				var v = listMonkClient.getLists();
				writedump(v.getOkOrFail());

				fail( "Intentional canary failure. Once you see this in tests/results and in the browser, delete AlwaysFailingSpec.cfc." );
			} );
		} );
	}

}
