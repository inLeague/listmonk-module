/**
 * Unit tests for ListmonkResponse wrapper.
 *
 * Pure unit tests — no WireBox, no HTTP. Tests the response
 * wrapping logic in isolation.
 */
component extends="testbox.system.BaseSpec" {

    function run() {
        describe( "ListmonkResponse", function() {
            it( "should report ok for 2xx status", function() {
                var mockRaw = new HyperResponseMock( 200, "OK", { "data" : true } );
                var response = new listmonk.models.ListmonkResponse( mockRaw );

                expect( response.isOk() ).toBeTrue();
                expect( response.isError() ).toBeFalse();
                expect( response.status() ).toBe( 200 );
                expect( response.data() ).toBeTrue();
                expect( response.message() ).toBe( "" );
            } );

            it( "should report error for 4xx status", function() {
                var mockRaw = new HyperResponseMock( 404, "Not Found", { "message" : "not found" } );
                var response = new listmonk.models.ListmonkResponse( mockRaw );

                expect( response.isError() ).toBeTrue();
                expect( response.isOk() ).toBeFalse();
                expect( response.status() ).toBe( 404 );
                expect( response.message() ).toBe( "not found" );
            } );

            it( "should report error for 5xx status", function() {
                var mockRaw = new HyperResponseMock( 500, "Internal Server Error", { "message" : "internal server error" } );
                var response = new listmonk.models.ListmonkResponse( mockRaw );

                expect( response.isError() ).toBeTrue();
                expect( response.status() ).toBe( 500 );
            } );

            it( "should extract data from Listmonk response envelope", function() {
                var mockRaw = new HyperResponseMock( 200, "OK", {
                    "data" : {
                        "id"    : 1,
                        "email" : "test@example.com",
                        "name"  : "Test User"
                    }
                } );
                var response = new listmonk.models.ListmonkResponse( mockRaw );

                expect( response.data() ).toBeStruct();
                expect( response.data().id ).toBe( 1 );
                expect( response.data().email ).toBe( "test@example.com" );
            } );

            it( "should handle array data from list endpoints", function() {
                var mockRaw = new HyperResponseMock( 200, "OK", {
                    "data" : [
                        { "id" : 1, "name" : "List 1" },
                        { "id" : 2, "name" : "List 2" }
                    ]
                } );
                var response = new listmonk.models.ListmonkResponse( mockRaw );

                expect( response.data() ).toBeArray();
                expect( response.data() ).toHaveLength( 2 );
            } );

            it( "should return raw HyperResponse", function() {
                var mockRaw = new HyperResponseMock( 200, "OK", { "data" : true } );
                var response = new listmonk.models.ListmonkResponse( mockRaw );

                expect( response.raw() ).toBe( mockRaw );
            } );

            it( "should handle non-JSON responses gracefully", function() {
                var mockRaw = new HyperResponseMock( 200, "OK", "" );
                var brokenMock = createObject( "tests.specs.HyperResponseMock" );
                brokenMock.init( 200, "OK", "" );
                brokenMock.json = function() {
                    throw( type = "JsonException" );
                };
                var response = new listmonk.models.ListmonkResponse( brokenMock );

                expect( response.isOk() ).toBeTrue();
                expect( response.data() ).toBe( "" );
            } );
        } );
    }

}
