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
			it( "foo", function() {
				var listMonkClient = wirebox.getInstance( "ListMonkClient@listmonk" );

				expect( listMonkClient.getLists().getOkOrFail().results ).toBeArray()
			} );
		} );
	}

}
