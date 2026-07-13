/**
 * Listmonk API Client.
 *
 * Provides typed methods for all Listmonk API endpoints.
 * Injects the pre-configured "ListmonkHyperClient" Hyper builder
 * registered by ModuleConfig.cfc.
 *
 * Tier 1 — Immediate inLeague use (fully implemented):
 *   Health, Transactional, Subscribers, Lists, Templates
 *
 * Tier 2 — Likely use soon (fully implemented):
 *   Subscriber list management, opt-in, blocklist, export
 *
 * Tier 3 — Stubs for completeness (throw "ListmonkNotImplemented"):
 *   Campaigns, Bounces, Media, Import, Settings, Users, Roles, Dashboard, etc.
 */
component {

    property name="hyper" inject="ListmonkHyperClient";
    property name="ListmonkResponse" inject="ListmonkResponse";

    // =========================================================================
    // PRIVATE HELPERS
    // =========================================================================

    /**
     * Execute an HTTP request and return a wrapped ListmonkResponse.
     *
     * @method   HTTP method (GET, POST, PUT, PATCH, DELETE).
     * @path     API path (e.g., "/api/subscribers").
     * @body     Optional request body struct.
     * @params   Optional query parameter struct.
     * @return   ListmonkResponse
     */
    private function _request(
        required string method,
        required string path,
        struct body = {},
        struct params = {}
    ) {
        var req = variables.hyper.new()
            .withUrl( arguments.path )
            .withMethod( arguments.method );

        if ( !structIsEmpty( arguments.params ) ) {
            req.withQueryParams( arguments.params );
        }

        if ( !structIsEmpty( arguments.body ) ) {
            req.withBody( arguments.body );
        }

        var rawResponse = req.send();

        return getInstance( "ListmonkResponse" ).init( rawResponse );
    }

    // =========================================================================
    // TIER 1 — IMMEDIATE INLEAGUE USE
    // =========================================================================

    // --- Health ----------------------------------------------------------------

    /**
     * Health check.
     *
     * @return ListmonkResponse with data=true on success.
     */
    function healthCheck() {
        return _request( "GET", "/api/health" );
    }

    // --- Transactional Email ---------------------------------------------------

    /**
     * Send a transactional email.
     *
     * @payload Struct with keys: subscriber_emails, subscriber_mode,
     *           template_id, data, content_type, etc.
     *           See Listmonk /api/tx documentation.
     * @return ListmonkResponse.
     */
    function sendTransactional( required struct payload ) {
        return _request( "POST", "/api/tx", body = arguments.payload );
    }

    // --- Subscribers -----------------------------------------------------------

    /**
     * Query subscribers with optional filters.
     *
     * @params Query parameters: query, page, limit, order_by, list_id, etc.
     * @return ListmonkResponse with data = { query: "...", results: [...], total: N, per_page: N, page: N }.
     */
    function getSubscribers( struct params = {} ) {
        return _request( "GET", "/api/subscribers", params = arguments.params );
    }

    /**
     * Get a subscriber by ID.
     *
     * @id Subscriber ID.
     * @return ListmonkResponse with data = subscriber struct.
     */
    function getSubscriber( required numeric id ) {
        return _request( "GET", "/api/subscribers/#arguments.id#" );
    }

    /**
     * Create a new subscriber.
     *
     * @data Subscriber data: email, name, status, lists, etc.
     * @return ListmonkResponse with data = created subscriber struct.
     */
    function createSubscriber( required struct data ) {
        return _request( "POST", "/api/subscribers", body = arguments.data );
    }

    /**
     * Fully update a subscriber (PUT — all fields required).
     *
     * @id   Subscriber ID.
     * @data Complete subscriber data.
     * @return ListmonkResponse.
     */
    function updateSubscriber( required numeric id, required struct data ) {
        return _request( "PUT", "/api/subscribers/#arguments.id#", body = arguments.data );
    }

    /**
     * Partially update a subscriber (PATCH — only provided fields).
     *
     * @id   Subscriber ID.
     * @data Fields to update.
     * @return ListmonkResponse.
     */
    function patchSubscriber( required numeric id, required struct data ) {
        return _request( "PATCH", "/api/subscribers/#arguments.id#", body = arguments.data );
    }

    /**
     * Delete a subscriber by ID.
     *
     * @id Subscriber ID.
     * @return ListmonkResponse.
     */
    function deleteSubscriber( required numeric id ) {
        return _request( "DELETE", "/api/subscribers/#arguments.id#" );
    }

    // --- Lists -----------------------------------------------------------------

    /**
     * Get all mailing lists.
     *
     * @params Optional query parameters: query, page, limit.
     * @return ListmonkResponse with data = array of list objects.
     */
    function getLists( struct params = {} ) {
        return _request( "GET", "/api/lists", params = arguments.params );
    }

    /**
     * Get a list by ID.
     *
     * @id List ID.
     * @return ListmonkResponse with data = list struct.
     */
    function getList( required numeric id ) {
        return _request( "GET", "/api/lists/#arguments.id#" );
    }

    /**
     * Create a new mailing list.
     *
     * @data List data: name, type, optin, etc.
     * @return ListmonkResponse with data = created list struct.
     */
    function createList( required struct data ) {
        return _request( "POST", "/api/lists", body = arguments.data );
    }

    /**
     * Update a mailing list.
     *
     * @id   List ID.
     * @data List fields to update.
     * @return ListmonkResponse.
     */
    function updateList( required numeric id, required struct data ) {
        return _request( "PUT", "/api/lists/#arguments.id#", body = arguments.data );
    }

    /**
     * Delete a mailing list by ID.
     *
     * @id List ID.
     * @return ListmonkResponse.
     */
    function deleteList( required numeric id ) {
        return _request( "DELETE", "/api/lists/#arguments.id#" );
    }

    /**
     * Bulk delete mailing lists.
     *
     * @ids Array of list IDs to delete.
     * @return ListmonkResponse.
     */
    function deleteLists( required array ids ) {
        return _request( "DELETE", "/api/lists", body = { ids: arguments.ids } );
    }

    // --- Templates -------------------------------------------------------------

    /**
     * Get all templates.
     *
     * @params Optional query parameters.
     * @return ListmonkResponse with data = array of template objects.
     */
    function getTemplates( struct params = {} ) {
        return _request( "GET", "/api/templates", params = arguments.params );
    }

    /**
     * Get a template by ID.
     *
     * @id Template ID.
     * @return ListmonkResponse with data = template struct.
     */
    function getTemplate( required numeric id ) {
        return _request( "GET", "/api/templates/#arguments.id#" );
    }

    /**
     * Create a new template.
     *
     * @data Template data: name, subject, body, type, etc.
     * @return ListmonkResponse with data = created template struct.
     */
    function createTemplate( required struct data ) {
        return _request( "POST", "/api/templates", body = arguments.data );
    }

    /**
     * Update a template.
     *
     * @id   Template ID.
     * @data Template fields to update.
     * @return ListmonkResponse.
     */
    function updateTemplate( required numeric id, required struct data ) {
        return _request( "PUT", "/api/templates/#arguments.id#", body = arguments.data );
    }

    /**
     * Set a template as the default.
     *
     * @id Template ID.
     * @return ListmonkResponse.
     */
    function setDefaultTemplate( required numeric id ) {
        return _request( "PUT", "/api/templates/#arguments.id#/default" );
    }

    /**
     * Delete a template by ID.
     *
     * @id Template ID.
     * @return ListmonkResponse.
     */
    function deleteTemplate( required numeric id ) {
        return _request( "DELETE", "/api/templates/#arguments.id#" );
    }

    // =========================================================================
    // TIER 2 — LIKELY USE SOON
    // =========================================================================

    // --- Subscriber List Management --------------------------------------------

    /**
     * Manage list membership for subscribers (bulk).
     *
     * @payload Struct: { query: "...", list_ids: [...], action: "add"|"remove" }
     * @return ListmonkResponse.
     */
    function manageSubscriberLists( required struct payload ) {
        return _request( "PUT", "/api/subscribers/lists", body = arguments.payload );
    }

    /**
     * Manage list membership for a specific list.
     *
     * @listId  List ID.
     * @payload Struct: { query: "...", action: "add"|"remove" }
     * @return ListmonkResponse.
     */
    function manageSubscriberListsByList( required numeric listId, required struct payload ) {
        return _request( "PUT", "/api/subscribers/lists/#arguments.listId#", body = arguments.payload );
    }

    /**
     * Send an opt-in email to a subscriber.
     *
     * @id Subscriber ID.
     * @return ListmonkResponse.
     */
    function sendOptin( required numeric id ) {
        return _request( "POST", "/api/subscribers/#arguments.id#/optin" );
    }

    // --- Blocklist --------------------------------------------------------------

    /**
     * Blocklist subscribers (bulk) by query.
     *
     * @payload Struct: { query: "..." }
     * @return ListmonkResponse.
     */
    function blocklistSubscribers( required struct payload ) {
        return _request( "PUT", "/api/subscribers/blocklist", body = arguments.payload );
    }

    /**
     * Blocklist a single subscriber.
     *
     * @id Subscriber ID.
     * @return ListmonkResponse.
     */
    function blocklistSubscriber( required numeric id ) {
        return _request( "PUT", "/api/subscribers/#arguments.id#/blocklist" );
    }

    // --- Bulk Subscriber Operations --------------------------------------------

    /**
     * Bulk delete subscribers.
     *
     * @ids Array of subscriber IDs.
     * @return ListmonkResponse.
     */
    function bulkDeleteSubscribers( required array ids ) {
        return _request( "DELETE", "/api/subscribers", body = { ids: arguments.ids } );
    }

    /**
     * Bulk delete subscribers by query.
     *
     * @payload Struct: { query: "..." }
     * @return ListmonkResponse.
     */
    function deleteSubscribersByQuery( required struct payload ) {
        return _request( "POST", "/api/subscribers/query/delete", body = arguments.payload );
    }

    /**
     * Bulk blocklist subscribers by query.
     *
     * @payload Struct: { query: "..." }
     * @return ListmonkResponse.
     */
    function blocklistSubscribersByQuery( required struct payload ) {
        return _request( "PUT", "/api/subscribers/query/blocklist", body = arguments.payload );
    }

    /**
     * Export all subscribers (gzipped CSV).
     *
     * @params Optional query parameters: list_id, query.
     * @return ListmonkResponse.
     */
    function exportSubscribers( struct params = {} ) {
        return _request( "GET", "/api/subscribers/export", params = arguments.params );
    }

    /**
     * Get subscriber activity.
     *
     * @id Subscriber ID.
     * @return ListmonkResponse.
     */
    function getSubscriberActivity( required numeric id ) {
        return _request( "GET", "/api/subscribers/#arguments.id#/activity" );
    }

    /**
     * Export subscriber data (JSON).
     *
     * @id Subscriber ID.
     * @return ListmonkResponse.
     */
    function exportSubscriberData( required numeric id ) {
        return _request( "GET", "/api/subscribers/#arguments.id#/export" );
    }

    /**
     * Get bounces for a subscriber.
     *
     * @id Subscriber ID.
     * @return ListmonkResponse.
     */
    function getSubscriberBounces( required numeric id ) {
        return _request( "GET", "/api/subscribers/#arguments.id#/bounces" );
    }

    /**
     * Delete bounces for a subscriber.
     *
     * @id Subscriber ID.
     * @return ListmonkResponse.
     */
    function deleteSubscriberBounces( required numeric id ) {
        return _request( "DELETE", "/api/subscribers/#arguments.id#/bounces" );
    }

    // =========================================================================
    // TIER 3 — STUBS (all throw ListmonkNotImplemented)
    // =========================================================================

    // --- Campaigns -------------------------------------------------------------

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

    // --- Bounces ---------------------------------------------------------------

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

    // --- Media -----------------------------------------------------------------

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

    // --- Import ----------------------------------------------------------------

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

    // --- Settings --------------------------------------------------------------

    /**
     * Get all Listmonk settings.
     *
     * @return ListmonkResponse with data = full settings struct.
     */
    function getSettings() {
        return _request( "GET", "/api/settings" );
    }

    /**
     * Update all Listmonk settings.
     *
     * @data Complete settings struct to replace current settings.
     * @return ListmonkResponse.
     */
    function updateSettings( required struct data ) {
        return _request( "PUT", "/api/settings", body = arguments.data );
    }

    /**
     * Update a specific setting by key.
     *
 * @key     Setting key (e.g., "app.site_name", "smtp").
     * @data    Setting value (struct for complex settings, string/numeric for simple).
     * @return  ListmonkResponse.
     */
    function updateSettingsByKey( required string key, required struct data ) {
        return _request( "PUT", "/api/settings/#arguments.key#", body = arguments.data );
    }

    /**
     * Send a test email via the configured SMTP settings.
     *
     * @data Struct with "to" email address to send the test to.
     * @return ListmonkResponse.
     */
    function testSMTP( required struct data ) {
        return _request( "POST", "/api/settings/smtp/test", body = arguments.data );
    }

    /**
     * Reload the Listmonk application (picks up config changes).
     *
     * @return ListmonkResponse.
     */
    function reloadApp() {
        return _request( "POST", "/api/admin/reload" );
    }

    /**
     * Get application logs.
     *
     * @params Optional query parameters: page, limit.
     * @return ListmonkResponse with data = log entries.
     */
    function getLogs( struct params = {} ) {
        return _request( "GET", "/api/logs", params = arguments.params );
    }

    // --- Users -----------------------------------------------------------------

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

    // --- Roles -----------------------------------------------------------------

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

    // --- Maintenance -----------------------------------------------------------

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

    // --- Dashboard -------------------------------------------------------------

    function getDashboardCharts() {
        throw( type = "ListmonkNotImplemented", message = "getDashboardCharts is not yet implemented" );
    }

    function getDashboardCounts() {
        throw( type = "ListmonkNotImplemented", message = "getDashboardCounts is not yet implemented" );
    }

    // --- System ----------------------------------------------------------------

    /**
     * Get the Listmonk server configuration (non-sensitive).
     *
     * @return ListmonkResponse with data = config struct (version, app_url, etc.).
     */
    function getConfig() {
        return _request( "GET", "/api/config" );
    }

    /**
     * Get Listmonk version and build info.
     *
     * @return ListmonkResponse with data = { version, build_date, ... }.
     */
    function getAbout() {
        return _request( "GET", "/api/about" );
    }

    /**
     * Get i18n language strings for the given locale.
     *
     * @lang Language code (e.g., "en", "fr").
     * @return ListmonkResponse with data = language string map.
     */
    function getLang( required string lang ) {
        return _request( "GET", "/api/lang/#arguments.lang#" );
    }

    /**
     * Get the server-sent events stream for live updates.
     *
     * NOTE: This endpoint returns an SSE stream, not JSON.
     * The Hyper response will contain the raw text stream.
     * Most callers should use polling instead of this method.
     *
     * @return ListmonkResponse with raw SSE data.
     */
    function getEvents() {
        return _request( "GET", "/api/events" );
    }

    // --- Webhooks --------------------------------------------------------------

    /**
     * Post a bounce webhook (e.g., from SES).
     *
     * This is the authenticated bounce endpoint used by internal systems.
     * For public-facing service webhooks (SES, Postmark, etc.), use the
     * public /webhooks/service/:service endpoint instead.
     *
     * @data Webhook payload (service-specific format).
     * @return ListmonkResponse.
     */
    function handleBounceWebhook( required struct data ) {
        return _request( "POST", "/webhooks/bounce", body = arguments.data );
    }

    /**
     * Post a bounce webhook for a specific service (public, unauthenticated).
     *
     * @service Service name (e.g., "ses", "postmark", "mailgun").
     * @data    Webhook payload (service-specific format).
     * @return  ListmonkResponse.
     */
    function handleServiceWebhook( required string service, required struct data ) {
        return _request( "POST", "/webhooks/service/#arguments.service#", body = arguments.data );
    }

    // --- Public API ------------------------------------------------------------

    function getPublicLists() {
        throw( type = "ListmonkNotImplemented", message = "getPublicLists is not yet implemented" );
    }

    function publicSubscription( required struct data ) {
        throw( type = "ListmonkNotImplemented", message = "publicSubscription is not yet implemented" );
    }

}
