/**
 * Integration tests for ListmonkClient using Hyper faking.
 *
 * Follows the Hyper docs pattern:
 * https://hyper.ortusbooks.com/testing/faking-requests
 *
 * The HyperBuilder's verb methods (get, post, etc.) create fresh
 * HyperRequests automatically — faking is configured on the builder
 * and propagated to each request via setFakeConfiguration.
 *
 * No live Listmonk required.
 */
component extends="testbox.system.BaseSpec" {

    function beforeAll() {
        try {
            addMatchers( "hyper.models.TestBoxMatchers" );
        } catch ( any e ) {
            // TestBoxMatchers not available in this environment
        }
    }

    function run() {
        describe( "ListmonkClient (faked)", function() {

            // ---------------------------------------------------------------
            // Helper: create a faked HyperBuilder + ListmonkClient pair
            // ---------------------------------------------------------------
            function createFakedClient( struct fakePatterns = {} ) {
                var h = new hyper.models.HyperBuilder();
                h.fake( arguments.fakePatterns );

                var c = new listmonkModule.models.ListmonkClient( h );

                return { client: c, hyper: h };
            }

            // ---------------------------------------------------------------
            // Health
            // ---------------------------------------------------------------

            describe( "healthCheck", function() {
                it( "should return ok on healthy Listmonk", function() {
                    var pair = createFakedClient( {
                        "*/api/health": function( r ) {
                            return r( 200, "OK", serializeJSON( { "data" : true } ) );
                        }
                    } );

                    var result = pair.client.healthCheck();

                    expect( result.isOk() ).toBeTrue();
                    expect( result.data() ).toBeTrue();
                } );
            } );

            // ---------------------------------------------------------------
            // Transactional Email
            // ---------------------------------------------------------------

            describe( "sendTransactional", function() {
                it( "should send a transactional email successfully", function() {
                    var pair = createFakedClient( {
                        "*/api/tx": function( r ) {
                            return r( 200, "OK", serializeJSON( { "data" : "success" } ) );
                        }
                    } );

                    var result = pair.client.sendTransactional( {
                        subscriber_emails : [ "test@example.com" ],
                        template_id       : 1,
                        data              : { subject : "Hello", body : "<h1>Hi</h1>" },
                        content_type      : "html"
                    } );

                    expect( result.isOk() ).toBeTrue();
                    expect( pair.hyper.getFakeRequestCount() ).toBeGTE( 1 );
                } );

                it( "should handle template not found error", function() {
                    var pair = createFakedClient( {
                        "*/api/tx": function( r ) {
                            return r( 400, "Bad Request", serializeJSON( {
                                "message" : "template does not exist"
                            } ) );
                        }
                    } );

                    var result = pair.client.sendTransactional( {
                        subscriber_emails : [ "test@example.com" ],
                        template_id       : 999,
                        data              : {},
                        content_type      : "html"
                    } );

                    expect( result.isError() ).toBeTrue();
                    expect( result.status() ).toBe( 400 );
                    expect( result.message() ).toContain( "template does not exist" );
                } );
            } );

            // ---------------------------------------------------------------
            // Subscribers
            // ---------------------------------------------------------------

            describe( "subscribers", function() {
                it( "should list subscribers", function() {
                    var pair = createFakedClient( {
                        "*/api/subscribers*": function( r ) {
                            return r( 200, "OK", serializeJSON( {
                                "data" : {
                                    "query"   : "",
                                    "results" : [
                                        { "id" : 1, "email" : "a@test.com", "name" : "Alice" },
                                        { "id" : 2, "email" : "b@test.com", "name" : "Bob" }
                                    ],
                                    "total"   : 2,
                                    "per_page": 20,
                                    "page"    : 1
                                }
                            } ) );
                        }
                    } );

                    var result = pair.client.getSubscribers();

                    expect( result.isOk() ).toBeTrue();
                    expect( result.data().results ).toBeArray();
                    expect( result.data().results ).toHaveLength( 2 );
                    expect( result.data().total ).toBe( 2 );
                } );

                it( "should get a subscriber by ID", function() {
                    var pair = createFakedClient( {
                        "*/api/subscribers/1": function( r ) {
                            return r( 200, "OK", serializeJSON( {
                                "data" : { "id" : 1, "email" : "a@test.com", "name" : "Alice" }
                            } ) );
                        }
                    } );

                    var result = pair.client.getSubscriber( 1 );

                    expect( result.isOk() ).toBeTrue();
                    expect( result.data().id ).toBe( 1 );
                    expect( result.data().email ).toBe( "a@test.com" );
                } );

                it( "should create a subscriber", function() {
                    var pair = createFakedClient( {
                        "*/api/subscribers": function( r ) {
                            return r( 200, "OK", serializeJSON( {
                                "data" : { "id" : 3, "email" : "c@test.com", "name" : "Charlie" }
                            } ) );
                        }
                    } );

                    var result = pair.client.createSubscriber( {
                        email  : "c@test.com",
                        name   : "Charlie",
                        status : "enabled",
                        lists  : [ { id : 1 } ]
                    } );

                    expect( result.isOk() ).toBeTrue();
                    expect( result.data().id ).toBe( 3 );
                } );

                it( "should return error for non-existent subscriber", function() {
                    var pair = createFakedClient( {
                        "*/api/subscribers/999": function( r ) {
                            return r( 404, "Not Found", serializeJSON( {
                                "message" : "subscriber not found"
                            } ) );
                        }
                    } );

                    var result = pair.client.getSubscriber( 999 );

                    expect( result.isError() ).toBeTrue();
                    expect( result.status() ).toBe( 404 );
                } );
            } );

            // ---------------------------------------------------------------
            // Lists
            // ---------------------------------------------------------------

            describe( "lists", function() {
                it( "should list all mailing lists", function() {
                    var pair = createFakedClient( {
                        "*/api/lists": function( r ) {
                            return r( 200, "OK", serializeJSON( {
                                "data" : [
                                    { "id" : 1, "name" : "Parents", "type" : "public" },
                                    { "id" : 2, "name" : "Coaches", "type" : "private" }
                                ]
                            } ) );
                        }
                    } );

                    var result = pair.client.getLists();

                    expect( result.isOk() ).toBeTrue();
                    expect( result.data() ).toBeArray();
                    expect( result.data() ).toHaveLength( 2 );
                } );

                it( "should create a list", function() {
                    var pair = createFakedClient( {
                        "*/api/lists": function( r ) {
                            return r( 200, "OK", serializeJSON( {
                                "data" : { "id" : 3, "name" : "New List", "type" : "public" }
                            } ) );
                        }
                    } );

                    var result = pair.client.createList( { name : "New List", type : "public" } );

                    expect( result.isOk() ).toBeTrue();
                    expect( result.data().id ).toBe( 3 );
                } );
            } );

            // ---------------------------------------------------------------
            // Templates
            // ---------------------------------------------------------------

            describe( "templates", function() {
                it( "should list all templates", function() {
                    var pair = createFakedClient( {
                        "*/api/templates": function( r ) {
                            return r( 200, "OK", serializeJSON( {
                                "data" : [
                                    { "id" : 1, "name" : "Default", "subject" : "Hello" }
                                ]
                            } ) );
                        }
                    } );

                    var result = pair.client.getTemplates();

                    expect( result.isOk() ).toBeTrue();
                    expect( result.data() ).toBeArray();
                } );
            } );

            // ---------------------------------------------------------------
            // Settings
            // ---------------------------------------------------------------

            describe( "settings", function() {
                it( "should get settings", function() {
                    var pair = createFakedClient( {
                        "*/api/settings": function( r ) {
                            return r( 200, "OK", serializeJSON( {
                                "data" : { "app" : { "site_name" : "Test Listmonk" } }
                            } ) );
                        }
                    } );

                    var result = pair.client.getSettings();

                    expect( result.isOk() ).toBeTrue();
                    expect( result.data().app.site_name ).toBe( "Test Listmonk" );
                } );
            } );

            // ---------------------------------------------------------------
            // System
            // ---------------------------------------------------------------

            describe( "system", function() {
                it( "should get server config", function() {
                    var pair = createFakedClient( {
                        "*/api/config": function( r ) {
                            return r( 200, "OK", serializeJSON( {
                                "data" : { "version" : "6.2.0", "app_url" : "http://localhost:9002" }
                            } ) );
                        }
                    } );

                    var result = pair.client.getConfig();

                    expect( result.isOk() ).toBeTrue();
                    expect( result.data().version ).toBe( "6.2.0" );
                } );
            } );

            // ---------------------------------------------------------------
            // Unimplemented stubs
            // ---------------------------------------------------------------

            describe( "unimplemented stubs", function() {
                it( "should throw for getCampaigns", function() {
                    var pair = createFakedClient();
                    expect( function() {
                        pair.client.getCampaigns();
                    } ).toThrow( "ListmonkNotImplemented" );
                } );

                it( "should throw for getUsers", function() {
                    var pair = createFakedClient();
                    expect( function() {
                        pair.client.getUsers();
                    } ).toThrow( "ListmonkNotImplemented" );
                } );

                it( "should throw for getDashboardCharts", function() {
                    var pair = createFakedClient();
                    expect( function() {
                        pair.client.getDashboardCharts();
                    } ).toThrow( "ListmonkNotImplemented" );
                } );
            } );

        } );
    }

}
