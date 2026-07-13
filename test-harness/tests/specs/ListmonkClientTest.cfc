/**
 * Integration tests for ListmonkClient using Hyper faking.
 *
 * Uses Hyper's built-in fake mechanism to intercept HTTP requests
 * and return canned Listmonk-shaped responses. Tests the full pipeline:
 *   ListmonkClient method → Hyper request → fake response → ListmonkResponse
 *
 * No live Listmonk required.
 */
component extends="testbox.system.BaseSpec" {

    // The Hyper builder instance we'll fake
    variables.hyper = "";

    function beforeAll() {
        addMatchers( "hyper.models.TestBoxMatchers" );
    }

    function beforeEach() {
        // Get the pre-configured Hyper builder registered by ModuleConfig
        hyper = wirebox.getInstance( "ListmonkHyperClient" );
    }

    function afterEach() {
        hyper.clearFakes();
    }

    function run() {
        describe( "ListmonkClient (faked)", function() {

            // ---------------------------------------------------------------
            // Health
            // ---------------------------------------------------------------

            describe( "healthCheck", function() {
                it( "should return ok on healthy Listmonk", function() {
                    hyper.fake( {
                        "*/api/health": function( newFakeResponse ) {
                            return newFakeResponse( 200, "OK", serializeJSON( { "data" : true } ) );
                        }
                    } );

                    var client = wirebox.getInstance( "ListmonkClient" );
                    var result = client.healthCheck();

                    expect( result.isOk() ).toBeTrue();
                    expect( result.data() ).toBeTrue();
                } );
            } );

            // ---------------------------------------------------------------
            // Transactional email
            // ---------------------------------------------------------------

            describe( "sendTransactional", function() {
                it( "should send a transactional email successfully", function() {
                    hyper.fake( {
                        "*/api/tx": function( newFakeResponse ) {
                            return newFakeResponse( 200, "OK", serializeJSON( { "data" : "success" } ) );
                        }
                    } );

                    var client = wirebox.getInstance( "ListmonkClient" );
                    var result = client.sendTransactional( {
                        subscriber_emails : [ "test@example.com" ],
                        template_id       : 1,
                        data              : { subject : "Hello", body : "<h1>Hi</h1>" },
                        content_type      : "html"
                    } );

                    expect( result.isOk() ).toBeTrue();
                    expect( hyper ).toHaveSentRequest( function( req ) {
                        return req.getFullUrl() contains "/api/tx"
                            && req.getMethod() == "POST";
                    } );
                } );

                it( "should handle template not found error", function() {
                    hyper.fake( {
                        "*/api/tx": function( newFakeResponse ) {
                            return newFakeResponse( 400, "Bad Request", serializeJSON( {
                                "message" : "template does not exist"
                            } ) );
                        }
                    } );

                    var client = wirebox.getInstance( "ListmonkClient" );
                    var result = client.sendTransactional( {
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
                    hyper.fake( {
                        "*/api/subscribers?*": function( newFakeResponse ) {
                            return newFakeResponse( 200, "OK", serializeJSON( {
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
                        },
                        "*/api/subscribers": function( newFakeResponse ) {
                            return newFakeResponse( 200, "OK", serializeJSON( {
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

                    var client = wirebox.getInstance( "ListmonkClient" );
                    var result = client.getSubscribers();

                    expect( result.isOk() ).toBeTrue();
                    expect( result.data().results ).toBeArray();
                    expect( result.data().results ).toHaveLength( 2 );
                    expect( result.data().total ).toBe( 2 );
                } );

                it( "should get a subscriber by ID", function() {
                    hyper.fake( {
                        "*/api/subscribers/1": function( newFakeResponse ) {
                            return newFakeResponse( 200, "OK", serializeJSON( {
                                "data" : { "id" : 1, "email" : "a@test.com", "name" : "Alice" }
                            } ) );
                        }
                    } );

                    var client = wirebox.getInstance( "ListmonkClient" );
                    var result = client.getSubscriber( 1 );

                    expect( result.isOk() ).toBeTrue();
                    expect( result.data().id ).toBe( 1 );
                    expect( result.data().email ).toBe( "a@test.com" );
                } );

                it( "should create a subscriber", function() {
                    hyper.fake( {
                        "*/api/subscribers": function( newFakeResponse ) {
                            return newFakeResponse( 200, "OK", serializeJSON( {
                                "data" : { "id" : 3, "email" : "c@test.com", "name" : "Charlie" }
                            } ) );
                        }
                    } );

                    var client = wirebox.getInstance( "ListmonkClient" );
                    var result = client.createSubscriber( {
                        email  : "c@test.com",
                        name   : "Charlie",
                        status : "enabled",
                        lists  : [ { id : 1 } ]
                    } );

                    expect( result.isOk() ).toBeTrue();
                    expect( result.data().id ).toBe( 3 );
                } );

                it( "should update a subscriber", function() {
                    hyper.fake( {
                        "*/api/subscribers/1": function( newFakeResponse ) {
                            return newFakeResponse( 200, "OK", serializeJSON( {
                                "data" : { "id" : 1, "email" : "a@test.com", "name" : "Alice Updated" }
                            } ) );
                        }
                    } );

                    var client = wirebox.getInstance( "ListmonkClient" );
                    var result = client.updateSubscriber( 1, { name : "Alice Updated" } );

                    expect( result.isOk() ).toBeTrue();
                    expect( result.data().name ).toBe( "Alice Updated" );
                    expect( hyper ).toHaveSentRequest( function( req ) {
                        return req.getFullUrl() contains "/api/subscribers/1"
                            && req.getMethod() == "PUT";
                    } );
                } );

                it( "should delete a subscriber", function() {
                    hyper.fake( {
                        "*/api/subscribers/1": function( newFakeResponse ) {
                            return newFakeResponse( 200, "OK", serializeJSON( { "data" : true } ) );
                        }
                    } );

                    var client = wirebox.getInstance( "ListmonkClient" );
                    var result = client.deleteSubscriber( 1 );

                    expect( result.isOk() ).toBeTrue();
                    expect( hyper ).toHaveSentRequest( function( req ) {
                        return req.getMethod() == "DELETE";
                    } );
                } );

                it( "should return error for non-existent subscriber", function() {
                    hyper.fake( {
                        "*/api/subscribers/999": function( newFakeResponse ) {
                            return newFakeResponse( 404, "Not Found", serializeJSON( {
                                "message" : "subscriber not found"
                            } ) );
                        }
                    } );

                    var client = wirebox.getInstance( "ListmonkClient" );
                    var result = client.getSubscriber( 999 );

                    expect( result.isError() ).toBeTrue();
                    expect( result.status() ).toBe( 404 );
                } );
            } );

            // ---------------------------------------------------------------
            // Lists
            // ---------------------------------------------------------------

            describe( "lists", function() {
                it( "should list all mailing lists", function() {
                    hyper.fake( {
                        "*/api/lists": function( newFakeResponse ) {
                            return newFakeResponse( 200, "OK", serializeJSON( {
                                "data" : [
                                    { "id" : 1, "name" : "Parents", "type" : "public" },
                                    { "id" : 2, "name" : "Coaches", "type" : "private" }
                                ]
                            } ) );
                        }
                    } );

                    var client = wirebox.getInstance( "ListmonkClient" );
                    var result = client.getLists();

                    expect( result.isOk() ).toBeTrue();
                    expect( result.data() ).toBeArray();
                    expect( result.data() ).toHaveLength( 2 );
                } );

                it( "should create a list", function() {
                    hyper.fake( {
                        "*/api/lists": function( newFakeResponse ) {
                            return newFakeResponse( 200, "OK", serializeJSON( {
                                "data" : { "id" : 3, "name" : "New List", "type" : "public" }
                            } ) );
                        }
                    } );

                    var client = wirebox.getInstance( "ListmonkClient" );
                    var result = client.createList( { name : "New List", type : "public" } );

                    expect( result.isOk() ).toBeTrue();
                    expect( result.data().id ).toBe( 3 );
                } );
            } );

            // ---------------------------------------------------------------
            // Templates
            // ---------------------------------------------------------------

            describe( "templates", function() {
                it( "should list all templates", function() {
                    hyper.fake( {
                        "*/api/templates": function( newFakeResponse ) {
                            return newFakeResponse( 200, "OK", serializeJSON( {
                                "data" : [
                                    { "id" : 1, "name" : "Default", "subject" : "{{ .Tx.Data.subject }}" }
                                ]
                            } ) );
                        }
                    } );

                    var client = wirebox.getInstance( "ListmonkClient" );
                    var result = client.getTemplates();

                    expect( result.isOk() ).toBeTrue();
                    expect( result.data() ).toBeArray();
                } );

                it( "should get a template by ID", function() {
                    hyper.fake( {
                        "*/api/templates/1": function( newFakeResponse ) {
                            return newFakeResponse( 200, "OK", serializeJSON( {
                                "data" : { "id" : 1, "name" : "Default", "subject" : "Hello" }
                            } ) );
                        }
                    } );

                    var client = wirebox.getInstance( "ListmonkClient" );
                    var result = client.getTemplate( 1 );

                    expect( result.isOk() ).toBeTrue();
                    expect( result.data().id ).toBe( 1 );
                } );
            } );

            // ---------------------------------------------------------------
            // Settings
            // ---------------------------------------------------------------

            describe( "settings", function() {
                it( "should get settings", function() {
                    hyper.fake( {
                        "*/api/settings": function( newFakeResponse ) {
                            return newFakeResponse( 200, "OK", serializeJSON( {
                                "data" : { "app" : { "site_name" : "Test Listmonk" } }
                            } ) );
                        }
                    } );

                    var client = wirebox.getInstance( "ListmonkClient" );
                    var result = client.getSettings();

                    expect( result.isOk() ).toBeTrue();
                    expect( result.data().app.site_name ).toBe( "Test Listmonk" );
                } );

                it( "should reload the app", function() {
                    hyper.fake( {
                        "*/api/admin/reload": function( newFakeResponse ) {
                            return newFakeResponse( 200, "OK", serializeJSON( { "data" : true } ) );
                        }
                    } );

                    var client = wirebox.getInstance( "ListmonkClient" );
                    var result = client.reloadApp();

                    expect( result.isOk() ).toBeTrue();
                    expect( hyper ).toHaveSentRequest( function( req ) {
                        return req.getFullUrl() contains "/api/admin/reload"
                            && req.getMethod() == "POST";
                    } );
                } );
            } );

            // ---------------------------------------------------------------
            // System
            // ---------------------------------------------------------------

            describe( "system", function() {
                it( "should get server config", function() {
                    hyper.fake( {
                        "*/api/config": function( newFakeResponse ) {
                            return newFakeResponse( 200, "OK", serializeJSON( {
                                "data" : { "version" : "6.2.0", "app_url" : "http://localhost:9002" }
                            } ) );
                        }
                    } );

                    var client = wirebox.getInstance( "ListmonkClient" );
                    var result = client.getConfig();

                    expect( result.isOk() ).toBeTrue();
                    expect( result.data().version ).toBe( "6.2.0" );
                } );

                it( "should get about info", function() {
                    hyper.fake( {
                        "*/api/about": function( newFakeResponse ) {
                            return newFakeResponse( 200, "OK", serializeJSON( {
                                "data" : { "version" : "6.2.0", "build" : "2024-01-01" }
                            } ) );
                        }
                    } );

                    var client = wirebox.getInstance( "ListmonkClient" );
                    var result = client.getAbout();

                    expect( result.isOk() ).toBeTrue();
                } );
            } );

            // ---------------------------------------------------------------
            // Tier 3 stubs still throw
            // ---------------------------------------------------------------

            describe( "unimplemented stubs", function() {
                it( "should throw for getCampaigns", function() {
                    var client = wirebox.getInstance( "ListmonkClient" );
                    expect( function() {
                        client.getCampaigns();
                    } ).toThrow( "ListmonkNotImplemented" );
                } );

                it( "should throw for getUsers", function() {
                    var client = wirebox.getInstance( "ListmonkClient" );
                    expect( function() {
                        client.getUsers();
                    } ).toThrow( "ListmonkNotImplemented" );
                } );

                it( "should throw for getDashboardCharts", function() {
                    var client = wirebox.getInstance( "ListmonkClient" );
                    expect( function() {
                        client.getDashboardCharts();
                    } ).toThrow( "ListmonkNotImplemented" );
                } );
            } );

        } );
    }

}
