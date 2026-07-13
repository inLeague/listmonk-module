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
                var mockRaw = createMock( "listmonkModule.models.ListmonkResponse" );
                mockRaw.status = 200;
                mockRaw.json = function() {
                    return { "data" : true };
                };

                var response = new listmonkModule.models.ListmonkResponse().init( mockRaw );

                expect( response.isOk() ).toBeTrue();
                expect( response.isError() ).toBeFalse();
                expect( response.status() ).toBe( 200 );
                expect( response.data() ).toBeTrue();
                expect( response.message() ).toBe( "" );
            } );

            it( "should report error for 4xx status", function() {
                var mockRaw = createMock( "listmonkModule.models.ListmonkResponse" );
                mockRaw.status = 404;
                mockRaw.json = function() {
                    return { "message" : "not found" };
                };

                var response = new listmonkModule.models.ListmonkResponse().init( mockRaw );

                expect( response.isError() ).toBeTrue();
                expect( response.isOk() ).toBeFalse();
                expect( response.status() ).toBe( 404 );
                expect( response.message() ).toBe( "not found" );
            } );

            it( "should report error for 5xx status", function() {
                var mockRaw = createMock( "listmonkModule.models.ListmonkResponse" );
                mockRaw.status = 500;
                mockRaw.json = function() {
                    return { "message" : "internal server error" };
                };

                var response = new listmonkModule.models.ListmonkResponse().init( mockRaw );

                expect( response.isError() ).toBeTrue();
                expect( response.status() ).toBe( 500 );
            } );

            it( "should extract data from Listmonk response envelope", function() {
                var mockRaw = createMock( "listmonkModule.models.ListmonkResponse" );
                mockRaw.status = 200;
                mockRaw.json = function() {
                    return {
                        "data" : {
                            "id"    : 1,
                            "email" : "test@example.com",
                            "name"  : "Test User"
                        }
                    };
                };

                var response = new listmonkModule.models.ListmonkResponse().init( mockRaw );

                expect( response.data() ).toBeStruct();
                expect( response.data().id ).toBe( 1 );
                expect( response.data().email ).toBe( "test@example.com" );
            } );

            it( "should handle array data from list endpoints", function() {
                var mockRaw = createMock( "listmonkModule.models.ListmonkResponse" );
                mockRaw.status = 200;
                mockRaw.json = function() {
                    return {
                        "data" : [
                            { "id" : 1, "name" : "List 1" },
                            { "id" : 2, "name" : "List 2" }
                        ]
                    };
                };

                var response = new listmonkModule.models.ListmonkResponse().init( mockRaw );

                expect( response.data() ).toBeArray();
                expect( response.data() ).toHaveLength( 2 );
            } );

            it( "should return raw HyperResponse", function() {
                var mockRaw = createMock( "listmonkModule.models.ListmonkResponse" );
                mockRaw.status = 200;
                mockRaw.json = function() {
                    return { "data" : true };
                };

                var response = new listmonkModule.models.ListmonkResponse().init( mockRaw );

                expect( response.raw() ).toBe( mockRaw );
            } );

            it( "should handle non-JSON responses gracefully", function() {
                var mockRaw = createMock( "listmonkModule.models.ListmonkResponse" );
                mockRaw.status = 200;
                mockRaw.json = function() {
                    throw( type = "JsonException" );
                };

                var response = new listmonkModule.models.ListmonkResponse().init( mockRaw );

                expect( response.isOk() ).toBeTrue();
                expect( response.data() ).toBe( "" );
            } );
        } );
    }

}
