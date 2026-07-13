/**
 * Tests for ListmonkClient — stubs throw ListmonkNotImplemented.
 *
 * Tier 1 and Tier 2 methods are NOT tested here because they require
 * a live Listmonk instance or HTTP faking (Hyper fakes). These tests
 * verify that Tier 3 stubs throw correctly and that the client
 * instantiates without error.
 */
component extends="testbox.system.BaseSpec" {

    function run() {
        describe( "ListmonkClient", function() {
            it( "should instantiate via WireBox", function() {
                var client = getInstance( "ListmonkClient" );
                expect( client ).toBeDefined();
            } );

            describe( "Tier 3 stubs", function() {
                it( "should throw ListmonkNotImplemented for getCampaigns", function() {
                    var client = getInstance( "ListmonkClient" );
                    expect( function() {
                        client.getCampaigns();
                    } ).toThrow( "ListmonkNotImplemented" );
                } );

                it( "should throw ListmonkNotImplemented for getCampaign", function() {
                    var client = getInstance( "ListmonkClient" );
                    expect( function() {
                        client.getCampaign( 1 );
                    } ).toThrow( "ListmonkNotImplemented" );
                } );

                it( "should throw ListmonkNotImplemented for createCampaign", function() {
                    var client = getInstance( "ListmonkClient" );
                    expect( function() {
                        client.createCampaign( { name : "Test" } );
                    } ).toThrow( "ListmonkNotImplemented" );
                } );

                it( "should throw ListmonkNotImplemented for getBounces", function() {
                    var client = getInstance( "ListmonkClient" );
                    expect( function() {
                        client.getBounces();
                    } ).toThrow( "ListmonkNotImplemented" );
                } );

                it( "should throw ListmonkNotImplemented for getMedia", function() {
                    var client = getInstance( "ListmonkClient" );
                    expect( function() {
                        client.getMedia();
                    } ).toThrow( "ListmonkNotImplemented" );
                } );

                it( "should throw ListmonkNotImplemented for importSubscribers", function() {
                    var client = getInstance( "ListmonkClient" );
                    expect( function() {
                        client.importSubscribers( {} );
                    } ).toThrow( "ListmonkNotImplemented" );
                } );

                it( "should throw ListmonkNotImplemented for getSettings", function() {
                    var client = getInstance( "ListmonkClient" );
                    expect( function() {
                        client.getSettings();
                    } ).toThrow( "ListmonkNotImplemented" );
                } );

                it( "should throw ListmonkNotImplemented for getUsers", function() {
                    var client = getInstance( "ListmonkClient" );
                    expect( function() {
                        client.getUsers();
                    } ).toThrow( "ListmonkNotImplemented" );
                } );

                it( "should throw ListmonkNotImplemented for getUserRoles", function() {
                    var client = getInstance( "ListmonkClient" );
                    expect( function() {
                        client.getUserRoles();
                    } ).toThrow( "ListmonkNotImplemented" );
                } );

                it( "should throw ListmonkNotImplemented for getDashboardCharts", function() {
                    var client = getInstance( "ListmonkClient" );
                    expect( function() {
                        client.getDashboardCharts();
                    } ).toThrow( "ListmonkNotImplemented" );
                } );

                it( "should throw ListmonkNotImplemented for getConfig", function() {
                    var client = getInstance( "ListmonkClient" );
                    expect( function() {
                        client.getConfig();
                    } ).toThrow( "ListmonkNotImplemented" );
                } );

                it( "should throw ListmonkNotImplemented for getPublicLists", function() {
                    var client = getInstance( "ListmonkClient" );
                    expect( function() {
                        client.getPublicLists();
                    } ).toThrow( "ListmonkNotImplemented" );
                } );
            } );
        } );
    }

}
