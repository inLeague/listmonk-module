/**
 * Listmonk API Client.
 *
 * Uses Hyper's verb methods (get, post, put, etc.) directly — each call
 * creates a fresh HyperRequest with the builder's defaults applied.
 *
 * In a ColdBox context, the HyperBuilder is injected via WireBox.
 * In a non-ColdBox context, pass it via setHyper() or init().
 */
component {

    /**
     * Initialize with an optional HyperBuilder.
     * If not provided, will attempt to resolve from WireBox at request time.
     *
     * @hyper Optional HyperBuilder instance (for testing or non-ColdBox use).
     */
    function init( hyper ) {
        if ( !isNull( arguments.hyper ) ) {
            variables.hyperBuilder = arguments.hyper;
        }
        return this;
    }

    /**
     * Get the underlying HyperBuilder instance.
     */
    function getHyper() {
        if ( isNull( variables.hyperBuilder ) ) {
            variables.hyperBuilder = wirebox.getInstance( "ListmonkHyperClient" );
        }
        return variables.hyperBuilder;
    }

    /**
     * Set the HyperBuilder instance (for testing/faking).
     */
    function setHyper( required hyper ) {
        variables.hyperBuilder = arguments.hyper;
    }

    /**
     * Execute an HTTP request and return a wrapped ListmonkResponse.
     */
    public function _request(
        required string method,
        required string path,
        struct body = {},
        struct params = {}
    ) {
        // Get a fresh HyperRequest from the builder with defaults + fake config applied.
        // We use new() to get the request, set its properties, then send() directly.
        // This avoids BoxLang issues with onMissingMethod/invoke inside private methods.
        var hyperInstance = getHyper();
        writeLog( text = "_request called | hyperBuilder type=#getMetaData( hyperInstance ).name# | hasFake=#structKeyExists( hyperInstance, 'fakeConfiguration' )#" );
        var req = hyperInstance.new();
        writeLog( text = "req created | type=#getMetaData( req ).name# | hasFakeConfig=#structKeyExists( req, 'fakeConfiguration' )# | fullUrl=#req.getFullUrl()#" );

        // Configure per-request properties
        req.setUrl( arguments.path );
        req.setProperties( { "method": arguments.method } );
        if ( !structIsEmpty( arguments.body ) ) {
            req.setProperties( { "body": arguments.body } );
        }
        if ( !structIsEmpty( arguments.params ) ) {
            req.withQueryParams( arguments.params );
        }

        // Execute the request — send() handles faking internally
        var rawResponse = "";
        try {
            rawResponse = req.send();
        } catch ( any e ) {
            writeLog( text = "send() exception: #e.message# | type=#e.type# | method=#arguments.method# path=#arguments.path#" );
            rethrow;
        }
        // Return the wrapped response
        return new listmonkModule.models.ListmonkResponse( rawResponse );
    }

    // =========================================================================
    // TIER 1 — IMMEDIATE INLEAGUE USE
    // =========================================================================

    function healthCheck() {
        return _request( method = "GET", path = "/api/health" );
    }

    function sendTransactional( required struct payload ) {
        return _request( method = "POST", path = "/api/tx", body = arguments.payload );
    }

    function getSubscribers( struct params = {} ) {
        return _request( method = "GET", path = "/api/subscribers", params = arguments.params );
    }

    function getSubscriber( required numeric id ) {
        return _request( method = "GET", path = "/api/subscribers/#arguments.id#" );
    }

    function createSubscriber( required struct data ) {
        return _request( method = "POST", path = "/api/subscribers", body = arguments.data );
    }

    function updateSubscriber( required numeric id, required struct data ) {
        return _request( method = "PUT", path = "/api/subscribers/#arguments.id#", body = arguments.data );
    }

    function patchSubscriber( required numeric id, required struct data ) {
        return _request( method = "PATCH", path = "/api/subscribers/#arguments.id#", body = arguments.data );
    }

    function deleteSubscriber( required numeric id ) {
        return _request( method = "DELETE", path = "/api/subscribers/#arguments.id#" );
    }

    function getLists( struct params = {} ) {
        return _request( method = "GET", path = "/api/lists", params = arguments.params );
    }

    function getList( required numeric id ) {
        return _request( method = "GET", path = "/api/lists/#arguments.id#" );
    }

    function createList( required struct data ) {
        return _request( method = "POST", path = "/api/lists", body = arguments.data );
    }

    function updateList( required numeric id, required struct data ) {
        return _request( method = "PUT", path = "/api/lists/#arguments.id#", body = arguments.data );
    }

    function deleteList( required numeric id ) {
        return _request( method = "DELETE", path = "/api/lists/#arguments.id#" );
    }

    function deleteLists( required array ids ) {
        return _request( method = "DELETE", path = "/api/lists", body = { ids: arguments.ids } );
    }

    function getTemplates( struct params = {} ) {
        return _request( method = "GET", path = "/api/templates", params = arguments.params );
    }

    function getTemplate( required numeric id ) {
        return _request( method = "GET", path = "/api/templates/#arguments.id#" );
    }

    function createTemplate( required struct data ) {
        return _request( method = "POST", path = "/api/templates", body = arguments.data );
    }

    function updateTemplate( required numeric id, required struct data ) {
        return _request( method = "PUT", path = "/api/templates/#arguments.id#", body = arguments.data );
    }

    function setDefaultTemplate( required numeric id ) {
        return _request( method = "PUT", path = "/api/templates/#arguments.id#/default" );
    }

    function deleteTemplate( required numeric id ) {
        return _request( method = "DELETE", path = "/api/templates/#arguments.id#" );
    }

    // =========================================================================
    // TIER 2 — LIKELY USE SOON
    // =========================================================================

    function manageSubscriberLists( required struct payload ) {
        return _request( method = "PUT", path = "/api/subscribers/lists", body = arguments.payload );
    }

    function manageSubscriberListsByList( required numeric listId, required struct payload ) {
        return _request( method = "PUT", path = "/api/subscribers/lists/#arguments.listId#", body = arguments.payload );
    }

    function sendOptin( required numeric id ) {
        return _request( method = "POST", path = "/api/subscribers/#arguments.id#/optin" );
    }

    function blocklistSubscribers( required struct payload ) {
        return _request( method = "PUT", path = "/api/subscribers/blocklist", body = arguments.payload );
    }

    function blocklistSubscriber( required numeric id ) {
        return _request( method = "PUT", path = "/api/subscribers/#arguments.id#/blocklist" );
    }

    function bulkDeleteSubscribers( required array ids ) {
        return _request( method = "DELETE", path = "/api/subscribers", body = { ids: arguments.ids } );
    }

    function deleteSubscribersByQuery( required struct payload ) {
        return _request( method = "POST", path = "/api/subscribers/query/delete", body = arguments.payload );
    }

    function blocklistSubscribersByQuery( required struct payload ) {
        return _request( method = "PUT", path = "/api/subscribers/query/blocklist", body = arguments.payload );
    }

    function exportSubscribers( struct params = {} ) {
        return _request( method = "GET", path = "/api/subscribers/export", params = arguments.params );
    }

    function getSubscriberActivity( required numeric id ) {
        return _request( method = "GET", path = "/api/subscribers/#arguments.id#/activity" );
    }

    function exportSubscriberData( required numeric id ) {
        return _request( method = "GET", path = "/api/subscribers/#arguments.id#/export" );
    }

    function getSubscriberBounces( required numeric id ) {
        return _request( method = "GET", path = "/api/subscribers/#arguments.id#/bounces" );
    }

    function deleteSubscriberBounces( required numeric id ) {
        return _request( method = "DELETE", path = "/api/subscribers/#arguments.id#/bounces" );
    }

    function getSettings() {
        return _request( method = "GET", path = "/api/settings" );
    }

    function updateSettings( required struct data ) {
        return _request( method = "PUT", path = "/api/settings", body = arguments.data );
    }

    function updateSettingsByKey( required string key, required struct data ) {
        return _request( method = "PUT", path = "/api/settings/#arguments.key#", body = arguments.data );
    }

    function testSMTP( required struct data ) {
        return _request( method = "POST", path = "/api/settings/smtp/test", body = arguments.data );
    }

    function reloadApp() {
        return _request( method = "POST", path = "/api/admin/reload" );
    }

    function getLogs( struct params = {} ) {
        return _request( method = "GET", path = "/api/logs", params = arguments.params );
    }

    function getConfig() {
        return _request( method = "GET", path = "/api/config" );
    }

    function getAbout() {
        return _request( method = "GET", path = "/api/about" );
    }

    function getLang( required string lang ) {
        return _request( method = "GET", path = "/api/lang/#arguments.lang#" );
    }

    function getEvents() {
        return _request( method = "GET", path = "/api/events" );
    }

    function handleBounceWebhook( required struct data ) {
        return _request( method = "POST", path = "/webhooks/bounce", body = arguments.data );
    }

    function handleServiceWebhook( required string service, required struct data ) {
        return _request( method = "POST", path = "/webhooks/service/#arguments.service#", body = arguments.data );
    }

    // =========================================================================
    // TIER 3 — STUBS
    // =========================================================================

    function getSubscribersByQuery( required struct payload ) {
        throw( type = "ListmonkNotImplemented", message = "getSubscribersByQuery is not yet implemented" );
    }
    function getCampaigns( struct params = {} ) {
        throw( type = "ListmonkNotImplemented", message = "getCampaigns is not yet implemented" );
    }
    function getRunningCampaignStats() {
        throw( type = "ListmonkNotImplemented", message = "getRunningCampaignStats is not yet implemented" );
    }
    function getCampaign( required numeric id ) {
        throw( type = "ListmonkNotImplemented", message = "getCampaign is not yet implemented" );
    }
    function getCampaignAnalytics( required string type, struct params = {} ) {
        throw( type = "ListmonkNotImplemented", message = "getCampaignAnalytics is not yet implemented" );
    }
    function previewCampaign( required numeric id ) {
        throw( type = "ListmonkNotImplemented", message = "previewCampaign is not yet implemented" );
    }
    function previewCampaignArchive( required numeric id ) {
        throw( type = "ListmonkNotImplemented", message = "previewCampaignArchive is not yet implemented" );
    }
    function getCampaignContent( required numeric id ) {
        throw( type = "ListmonkNotImplemented", message = "getCampaignContent is not yet implemented" );
    }
    function setCampaignContent( required numeric id, required struct data ) {
        throw( type = "ListmonkNotImplemented", message = "setCampaignContent is not yet implemented" );
    }
    function previewCampaignText( required numeric id ) {
        throw( type = "ListmonkNotImplemented", message = "previewCampaignText is not yet implemented" );
    }
    function testCampaign( required numeric id, required struct data ) {
        throw( type = "ListmonkNotImplemented", message = "testCampaign is not yet implemented" );
    }
    function createCampaign( required struct data ) {
        throw( type = "ListmonkNotImplemented", message = "createCampaign is not yet implemented" );
    }
    function updateCampaign( required numeric id, required struct data ) {
        throw( type = "ListmonkNotImplemented", message = "updateCampaign is not yet implemented" );
    }
    function updateCampaignStatus( required numeric id, required struct data ) {
        throw( type = "ListmonkNotImplemented", message = "updateCampaignStatus is not yet implemented" );
    }
    function updateCampaignArchive( required numeric id, required struct data ) {
        throw( type = "ListmonkNotImplemented", message = "updateCampaignArchive is not yet implemented" );
    }
    function deleteCampaigns( required array ids ) {
        throw( type = "ListmonkNotImplemented", message = "deleteCampaigns is not yet implemented" );
    }
    function deleteCampaign( required numeric id ) {
        throw( type = "ListmonkNotImplemented", message = "deleteCampaign is not yet implemented" );
    }
    function getBounces( struct params = {} ) {
        throw( type = "ListmonkNotImplemented", message = "getBounces is not yet implemented" );
    }
    function getBounce( required numeric id ) {
        throw( type = "ListmonkNotImplemented", message = "getBounce is not yet implemented" );
    }
    function blocklistBouncedSubscribers() {
        throw( type = "ListmonkNotImplemented", message = "blocklistBouncedSubscribers is not yet implemented" );
    }
    function deleteBounces( struct params = {} ) {
        throw( type = "ListmonkNotImplemented", message = "deleteBounces is not yet implemented" );
    }
    function deleteBounce( required numeric id ) {
        throw( type = "ListmonkNotImplemented", message = "deleteBounce is not yet implemented" );
    }
    function getMedia( struct params = {} ) {
        throw( type = "ListmonkNotImplemented", message = "getMedia is not yet implemented" );
    }
    function getMediaItem( required numeric id ) {
        throw( type = "ListmonkNotImplemented", message = "getMediaItem is not yet implemented" );
    }
    function uploadMedia( required struct data ) {
        throw( type = "ListmonkNotImplemented", message = "uploadMedia is not yet implemented" );
    }
    function deleteMedia( required numeric id ) {
        throw( type = "ListmonkNotImplemented", message = "deleteMedia is not yet implemented" );
    }
    function getImportStatus() {
        throw( type = "ListmonkNotImplemented", message = "getImportStatus is not yet implemented" );
    }
    function getImportLogs() {
        throw( type = "ListmonkNotImplemented", message = "getImportLogs is not yet implemented" );
    }
    function importSubscribers( required struct data ) {
        throw( type = "ListmonkNotImplemented", message = "importSubscribers is not yet implemented" );
    }
    function stopImport() {
        throw( type = "ListmonkNotImplemented", message = "stopImport is not yet implemented" );
    }
    function getProfile() {
        throw( type = "ListmonkNotImplemented", message = "getProfile is not yet implemented" );
    }
    function updateProfile( required struct data ) {
        throw( type = "ListmonkNotImplemented", message = "updateProfile is not yet implemented" );
    }
    function getUsers( struct params = {} ) {
        throw( type = "ListmonkNotImplemented", message = "getUsers is not yet implemented" );
    }
    function getUser( required numeric id ) {
        throw( type = "ListmonkNotImplemented", message = "getUser is not yet implemented" );
    }
    function createUser( required struct data ) {
        throw( type = "ListmonkNotImplemented", message = "createUser is not yet implemented" );
    }
    function updateUser( required numeric id, required struct data ) {
        throw( type = "ListmonkNotImplemented", message = "updateUser is not yet implemented" );
    }
    function deleteUser( required numeric id ) {
        throw( type = "ListmonkNotImplemented", message = "deleteUser is not yet implemented" );
    }
    function deleteUserBatch( required array ids ) {
        throw( type = "ListmonkNotImplemented", message = "deleteUserBatch is not yet implemented" );
    }
    function generateTOTP( required numeric id ) {
        throw( type = "ListmonkNotImplemented", message = "generateTOTP is not yet implemented" );
    }
    function enableTOTP( required numeric id, required struct data ) {
        throw( type = "ListmonkNotImplemented", message = "enableTOTP is not yet implemented" );
    }
    function disableTOTP( required numeric id ) {
        throw( type = "ListmonkNotImplemented", message = "disableTOTP is not yet implemented" );
    }
    function getUserRoles() {
        throw( type = "ListmonkNotImplemented", message = "getUserRoles is not yet implemented" );
    }
    function getListRoles() {
        throw( type = "ListmonkNotImplemented", message = "getListRoles is not yet implemented" );
    }
    function createUserRole( required struct data ) {
        throw( type = "ListmonkNotImplemented", message = "createUserRole is not yet implemented" );
    }
    function createListRole( required struct data ) {
        throw( type = "ListmonkNotImplemented", message = "createListRole is not yet implemented" );
    }
    function updateUserRole( required numeric id, required struct data ) {
        throw( type = "ListmonkNotImplemented", message = "updateUserRole is not yet implemented" );
    }
    function updateListRole( required numeric id, required struct data ) {
        throw( type = "ListmonkNotImplemented", message = "updateListRole is not yet implemented" );
    }
    function deleteRole( required numeric id ) {
        throw( type = "ListmonkNotImplemented", message = "deleteRole is not yet implemented" );
    }
    function gcSubscribers( required string type ) {
        throw( type = "ListmonkNotImplemented", message = "gcSubscribers is not yet implemented" );
    }
    function gcCampaignAnalytics( required string type ) {
        throw( type = "ListmonkNotImplemented", message = "gcCampaignAnalytics is not yet implemented" );
    }
    function exportCampaignAnalytics( required string type ) {
        throw( type = "ListmonkNotImplemented", message = "exportCampaignAnalytics is not yet implemented" );
    }
    function gcSubscriptions() {
        throw( type = "ListmonkNotImplemented", message = "gcSubscriptions is not yet implemented" );
    }
    function getDashboardCharts() {
        throw( type = "ListmonkNotImplemented", message = "getDashboardCharts is not yet implemented" );
    }
    function getDashboardCounts() {
        throw( type = "ListmonkNotImplemented", message = "getDashboardCounts is not yet implemented" );
    }
    function getPublicLists() {
        throw( type = "ListmonkNotImplemented", message = "getPublicLists is not yet implemented" );
    }
    function publicSubscription( required struct data ) {
        throw( type = "ListmonkNotImplemented", message = "publicSubscription is not yet implemented" );
    }

}
