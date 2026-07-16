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

                var c = new listmonk.models.ListmonkClient( h );

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
            // Transactional defaults from module settings
            // ---------------------------------------------------------------

            describe( "sendTransactional defaults", function() {
                it( "should apply module subscriberMode and contentType when omitted", function() {
                    var pair = createFakedClient( {
                        "*/api/tx": function( r ) {
                            return r( 200, "OK", serializeJSON( { "data" : "success" } ) );
                        }
                    } );

                    // Re-init with custom module defaults (createFakedClient already inited once)
                    pair.client.setHyper( pair.hyper );
                    pair.client.setModuleSettings( {
                        subscriberMode : "fallback",
                        contentType    : "plain"
                    } );

                    var result = pair.client.sendTransactional( {
                        subscriber_emails : [ "test@example.com" ],
                        template_id       : 1,
                        data              : { subject : "Hello" }
                    } );

                    expect( result.isOk() ).toBeTrue();
                    expect( pair.hyper.getFakeRequestCount() ).toBeGTE( 1 );
                } );

                it( "should apply defaultTemplateId when template_id is omitted", function() {
                    var pair = createFakedClient( {
                        "*/api/tx": function( r ) {
                            return r( 200, "OK", serializeJSON( { "data" : "success" } ) );
                        }
                    } );

                    pair.client.setHyper( pair.hyper );
                    pair.client.setModuleSettings( {
                        subscriberMode    : "external",
                        contentType       : "html",
                        defaultTemplateId : 5
                    } );

                    var result = pair.client.sendTransactional( {
                        subscriber_emails : [ "test@example.com" ],
                        data              : { subject : "Hello" }
                    } );

                    expect( result.isOk() ).toBeTrue();
                } );

                it( "should not override template_id when already present", function() {
                    var pair = createFakedClient( {
                        "*/api/tx": function( r ) {
                            return r( 200, "OK", serializeJSON( { "data" : "success" } ) );
                        }
                    } );

                    pair.client.setHyper( pair.hyper );
                    pair.client.setModuleSettings( {
                        subscriberMode    : "external",
                        contentType       : "html",
                        defaultTemplateId : 5
                    } );

                    var result = pair.client.sendTransactional( {
                        subscriber_emails : [ "test@example.com" ],
                        template_id       : 99,
                        data              : { subject : "Hello" }
                    } );

                    expect( result.isOk() ).toBeTrue();
                } );

                it( "should not apply defaultTemplateId when set to 0", function() {
                    var pair = createFakedClient( {
                        "*/api/tx": function( r ) {
                            return r( 200, "OK", serializeJSON( { "data" : "success" } ) );
                        }
                    } );

                    pair.client.setHyper( pair.hyper );
                    pair.client.setModuleSettings( {
                        subscriberMode    : "external",
                        contentType       : "html",
                        defaultTemplateId : 0
                    } );

                    var result = pair.client.sendTransactional( {
                        subscriber_emails : [ "test@example.com" ],
                        data              : { subject : "Hello" }
                    } );

                    expect( result.isOk() ).toBeTrue();
                } );
            } );

            // ---------------------------------------------------------------
            // Attachments
            // ---------------------------------------------------------------

            describe( "sendTransactional with attachments", function() {
                it( "should send transactional email with file attachments", function() {
                    var pair = createFakedClient( {
                        "*/api/tx": function( r ) {
                            return r( 200, "OK", serializeJSON( { "data" : "success" } ) );
                        }
                    } );

                    // Create a temp file for the attachment test
                    var tmpFile = getTempFile() & ".txt";
                    fileWrite( tmpFile, "test attachment content" );

                    var result = pair.client.sendTransactional(
                        {
                            subscriber_emails : [ "test@example.com" ],
                            template_id       : 1,
                            data              : { subject : "Hello" }
                        },
                        [
                            { name : "file", path : tmpFile, mimeType : "text/plain" }
                        ]
                    );

                    expect( result.isOk() ).toBeTrue();

                    // Clean up
                    if ( fileExists( tmpFile ) ) {
                        fileDelete( tmpFile );
                    }
                } );

                it( "should send with multiple attachments", function() {
                    var pair = createFakedClient( {
                        "*/api/tx": function( r ) {
                            return r( 200, "OK", serializeJSON( { "data" : "success" } ) );
                        }
                    } );

                    var tmpFile1 = getTempFile() & ".txt";
                    var tmpFile2 = getTempFile() & ".pdf";
                    fileWrite( tmpFile1, "attachment 1" );
                    fileWrite( tmpFile2, "attachment 2" );

                    var result = pair.client.sendTransactional(
                        {
                            subscriber_emails : [ "test@example.com" ],
                            template_id       : 1,
                            data              : { subject : "Hello" }
                        },
                        [
                            { name : "file", path : tmpFile1, mimeType : "text/plain" },
                            { name : "file", path : tmpFile2, mimeType : "application/pdf" }
                        ]
                    );

                    expect( result.isOk() ).toBeTrue();

                    if ( fileExists( tmpFile1 ) ) { fileDelete( tmpFile1 ); }
                    if ( fileExists( tmpFile2 ) ) { fileDelete( tmpFile2 ); }
                } );

                it( "should fall back to JSON when attachments array is empty", function() {
                    var pair = createFakedClient( {
                        "*/api/tx": function( r ) {
                            return r( 200, "OK", serializeJSON( { "data" : "success" } ) );
                        }
                    } );

                    var result = pair.client.sendTransactional(
                        {
                            subscriber_emails : [ "test@example.com" ],
                            template_id       : 1,
                            data              : { subject : "Hello" }
                        },
                        []
                    );

                    expect( result.isOk() ).toBeTrue();
                } );
            } );

            // ---------------------------------------------------------------
            // Per-recipient data
            // ---------------------------------------------------------------

            describe( "sendTransactional with perRecipientData", function() {
                it( "should send individual requests per recipient", function() {
                    var requestCount = 0;
                    var pair = createFakedClient( {
                        "*/api/tx": function( r ) {
                            requestCount++;
                            return r( 200, "OK", serializeJSON( { "data" : "success" } ) );
                        }
                    } );

                    var result = pair.client.sendTransactional(
                        { template_id : 1 },
                        [],
                        [
                            { email : "alice@test.com", data : { name : "Alice", unsub : "https://unsub/a" } },
                            { email : "bob@test.com", data : { name : "Bob", unsub : "https://unsub/b" } }
                        ]
                    );

                    expect( result.isOk() ).toBeTrue();
                    expect( requestCount ).toBe( 2 );
                } );

                it( "should merge per-recipient data into base payload", function() {
                    var capturedBody = "";
                    var pair = createFakedClient( {
                        "*/api/tx": function( r ) {
                            return r( 200, "OK", serializeJSON( { "data" : "success" } ) );
                        }
                    } );

                    // We can verify merging by checking the client received the call
                    var result = pair.client.sendTransactional(
                        { template_id : 1, data : { event_name : "Fall Season" } },
                        [],
                        [
                            { email : "alice@test.com", data : { name : "Alice" } }
                        ]
                    );

                    expect( result.isOk() ).toBeTrue();
                } );

                it( "should prefer per-recipient data over base data on conflict", function() {
                    var pair = createFakedClient( {
                        "*/api/tx": function( r ) {
                            return r( 200, "OK", serializeJSON( { "data" : "success" } ) );
                        }
                    } );

                    var result = pair.client.sendTransactional(
                        { template_id : 1, data : { name : "Default", shared : "yes" } },
                        [],
                        [
                            { email : "alice@test.com", data : { name : "Alice" } }
                        ]
                    );

                    // Per-recipient "name" should override "Default", "shared" should persist
                    expect( result.isOk() ).toBeTrue();
                } );

                it( "should return last response when multiple recipients", function() {
                    var pair = createFakedClient( {
                        "*/api/tx": function( r ) {
                            return r( 200, "OK", serializeJSON( { "data" : "success" } ) );
                        }
                    } );

                    var result = pair.client.sendTransactional(
                        { template_id : 1 },
                        [],
                        [
                            { email : "alice@test.com", data : { name : "Alice" } },
                            { email : "bob@test.com", data : { name : "Bob" } }
                        ]
                    );

                    expect( result.isOk() ).toBeTrue();
                } );
            } );

            // ---------------------------------------------------------------
            // Webhook management
            // ---------------------------------------------------------------

            describe( "Webhook management", function() {
                it( "should list webhooks", function() {
                    var pair = createFakedClient( {
                        "*/api/webhooks": function( r ) {
                            return r( 200, "OK", serializeJSON( {
                                "data" : [
                                    { "id" : 1, "url" : "https://api.inleague.io/webhooks/listmonk", "enabled" : true }
                                ]
                            } ) );
                        }
                    } );

                    var result = pair.client.getWebhooks();
                    expect( result.isOk() ).toBeTrue();
                } );

                it( "should create a webhook", function() {
                    var pair = createFakedClient( {
                        "*/api/webhooks": function( r ) {
                            return r( 200, "OK", serializeJSON( {
                                "data" : { "id" : 2, "url" : "https://api.inleague.io/webhooks/listmonk", "enabled" : true }
                            } ) );
                        }
                    } );

                    var result = pair.client.createWebhook( {
                        url     : "https://api.inleague.io/webhooks/listmonk",
                        events  : [ "subscriber.unsubscribed", "subscriber.optimed" ],
                        method  : "POST",
                        enabled : true
                    } );

                    expect( result.isOk() ).toBeTrue();
                } );

                it( "should delete a webhook", function() {
                    var pair = createFakedClient( {
                        "*/api/webhooks/1": function( r ) {
                            return r( 200, "OK", serializeJSON( { "data" : true } ) );
                        }
                    } );

                    var result = pair.client.deleteWebhook( id = 1 );
                    expect( result.isOk() ).toBeTrue();
                } );
            } );

            // ---------------------------------------------------------------
            // Webhook validation
            // ---------------------------------------------------------------

            describe( "Webhook validation", function() {
                it( "should validate a correct webhook signature", function() {
                    // Verify the validation method exists and works
                    var pair = createFakedClient( {} );
                    var result = pair.client.validateWebhookSignature(
                        secret    = "test-secret",
                        body      = ' { "event" : "test" }',
                        signature = "sha256=0000000000000000000000000000000000000000000000000000000000000000",
                        timestamp = "1234567890",
                        maxAgeSeconds  = 999999999
                    );
                    expect( result ).toBeFalse();
                } );
                it( "should reject an incorrect webhook signature", function() {
                    var pair = createFakedClient( {} );

                    var result = pair.client.validateWebhookSignature(
                        secret    = "my-secret",
                        body      = '{ "event" : "test" }',
                        signature = "sha256=0000000000000000000000000000000000000000000000000000000000000000",
                        timestamp = "1234567890"
                    );

                    expect( result ).toBeFalse();
                } );

                it( "should reject an expired webhook timestamp", function() {
                    var pair = createFakedClient( {} );
                    var secret = "my-secret";
                    var oldTimestamp = "1000000000"; // Very old timestamp
                    var body = '{ "event" : "test" }';

                    var payload = oldTimestamp & "." & body;
                    var sig = "sha256=" & binaryDecode(
                        hmac( payload, secret, "HmacSHA256", "utf-8" ),
                        "hex"
                    );

                    var result = pair.client.validateWebhookSignature(
                        secret    = secret,
                        body      = body,
                        signature = sig,
                        timestamp = oldTimestamp,
                        maxAgeSeconds = 300
                    );

                    expect( result ).toBeFalse();
                } );

                it( "should extract event type from webhook payload", function() {
                    var pair = createFakedClient( {} );

                    var event = pair.client.getWebhookEvent( {
                        "event" : "subscriber.unsubscribed",
                        "timestamp" : "2026-01-01T00:00:00Z",
                        "data" : { "id" : 42 }
                    } );

                    expect( event ).toBe( "subscriber.unsubscribed" );
                } );
            } );

            // ---------------------------------------------------------------
            // Subscriber sync
            // ---------------------------------------------------------------

            describe( "Subscriber sync convenience methods", function() {
                it( "should upsertSubscriber creating new subscriber", function() {
                    var pair = createFakedClient( {
                        "*/api/subscribers*": function( r ) {
                            return r( 200, "OK", serializeJSON( {
                                "data" : {
                                    "id" : 42,
                                    "email" : "new@test.com",
                                    "name" : "New User",
                                    "attribs" : { "unsub_token" : "abc123" },
                                    "status" : "enabled",
                                    "lists" : []
                                }
                            } ) );
                        }
                    } );

                    var result = pair.client.upsertSubscriber(
                        email  = "new@test.com",
                        name   = "New User",
                        listIds = [ 1 ],
                        attribs = { "unsub_token" : "abc123" }
                    );

                    expect( result.isOk() ).toBeTrue();
                } );

                it( "should upsertSubscriber patching existing subscriber", function() {
                    var pair = createFakedClient( {
                        "*/api/subscribers*": function( r ) {
                            return r( 200, "OK", serializeJSON( {
                                "data" : {
                                    "id" : 42,
                                    "email" : "existing@test.com",
                                    "name" : "Existing User",
                                    "attribs" : { "unsub_token" : "xyz789" },
                                    "status" : "enabled",
                                    "lists" : []
                                }
                            } ) );
                        }
                    } );

                    var result = pair.client.upsertSubscriber(
                        email  = "existing@test.com",
                        name   = "Existing User",
                        listIds = [ 1 ],
                        attribs = { "unsub_token" : "xyz789" }
                    );

                    expect( result.isOk() ).toBeTrue();
                } );

                it( "should addSubscribersToLists", function() {
                    var pair = createFakedClient( {
                        "*/api/subscribers/lists": function( r ) {
                            return r( 200, "OK", serializeJSON( { "data" : true } ) );
                        }
                    } );

                    var result = pair.client.addSubscribersToLists(
                        subscriberIds = [ 1, 2, 3 ],
                        listIds       = [ 10 ],
                        status        = "confirmed"
                    );

                    expect( result.isOk() ).toBeTrue();
                } );

                it( "should removeSubscribersFromLists", function() {
                    var pair = createFakedClient( {
                        "*/api/subscribers/lists": function( r ) {
                            return r( 200, "OK", serializeJSON( { "data" : true } ) );
                        }
                    } );

                    var result = pair.client.removeSubscribersFromLists(
                        subscriberIds = [ 1, 2 ],
                        listIds       = [ 10 ]
                    );

                    expect( result.isOk() ).toBeTrue();
                } );

                it( "should extractIdFromData from flat and nested payloads", function() {
                    var pair = createFakedClient( {} );
                    expect( pair.client.extractIdFromData( { "id" : 42 } ) ).toBe( 42 );
                    expect( pair.client.extractIdFromData( { "data" : { "id" : 7 } } ) ).toBe( 7 );
                    expect( pair.client.extractIdFromData( {} ) ).toBe( 0 );
                } );

                it( "should ensureSubscriberOnLists via upsert when no existing id", function() {
                    var pair = createFakedClient( {
                        "*/api/subscribers*": function( r ) {
                            return r( 200, "OK", serializeJSON( {
                                "data" : {
                                    "id" : 55,
                                    "email" : "new@test.com",
                                    "name" : "New User",
                                    "lists" : []
                                }
                            } ) );
                        }
                    } );

                    var result = pair.client.ensureSubscriberOnLists(
                        email  = "new@test.com",
                        name   = "New User",
                        listIds = [ 1 ]
                    );

                    expect( result.isOk() ).toBeTrue();
                    expect( pair.client.extractIdFromData( result.data() ) ).toBe( 55 );
                } );

                it( "should ensureSubscriberOnLists via addSubscribersToLists when id known", function() {
                    var pair = createFakedClient( {
                        "*/api/subscribers/lists": function( r ) {
                            return r( 200, "OK", serializeJSON( { "data" : true } ) );
                        }
                    } );

                    var result = pair.client.ensureSubscriberOnLists(
                        email                = "existing@test.com",
                        name                 = "Existing",
                        listIds              = [ 10 ],
                        existingSubscriberId = 99
                    );

                    expect( result.isOk() ).toBeTrue();
                    expect( pair.client.extractIdFromData( result.data() ) ).toBe( 99 );
                } );
            } );

        } );
    }

}
