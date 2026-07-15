/**
 * Listmonk API Client.
 *
 * Uses Hyper's verb methods (get, post, put, etc.) directly — each call
 * creates a fresh HyperRequest with the builder's defaults applied.
 *
 * In a ColdBox context, the HyperBuilder and module settings are injected via WireBox.
 * In a non-ColdBox context, pass them via setHyper() / init().
 *
 * @author inLeague LLC
 */
component accessors="true" {

	/**
	 * Pre-configured HyperBuilder for Listmonk requests
	 */
	property name="hyperBuilder" inject="ListmonkHyperClient@listmonk" required="false";

	/**
	 * Module settings (baseUrl, apiToken, subscriberMode, contentType, ...)
	 */
	property name="moduleSettings" inject="coldbox:moduleSettings:listmonk" required="false";

	/**
	 * LogBox logger
	 */
	property name="log" inject="logbox:logger:{this}" required="false";

	/**
	 * Initialize with optional HyperBuilder and settings (for testing or non-ColdBox use).
	 *
	 * @hyper Optional HyperBuilder instance
	 * @moduleSettings Optional module settings struct
	 *
	 * @return ListmonkClient
	 */
	function init( hyper, struct moduleSettings ) {
		if ( !isNull( arguments.hyper ) ) {
			variables.hyperBuilder = arguments.hyper;
		}
		if ( !isNull( arguments.moduleSettings ) ) {
			variables.moduleSettings = arguments.moduleSettings;
		}
		if ( isNull( variables.moduleSettings ) ) {
			variables.moduleSettings = {
				"subscriberMode" : "external",
				"contentType"    : "html",
				"defaultTemplateId" : 0
			};
		}
		return this;
	}

	/**
	 * Get the underlying HyperBuilder instance.
	 *
	 * @return HyperBuilder
	 * @throws ListmonkException - When no HyperBuilder has been configured
	 */
	function getHyper() {
		if ( isNull( variables.hyperBuilder ) ) {
			throw(
				type    = "ListmonkException",
				message = "Listmonk HyperBuilder is not configured. Inject ListmonkHyperClient@listmonk or call setHyper()."
			);
		}
		return variables.hyperBuilder;
	}

	/**
	 * Set the HyperBuilder instance (for testing/faking).
	 *
	 * @hyper HyperBuilder instance
	 *
	 * @return ListmonkClient
	 */
	function setHyper( required hyper ) {
		variables.hyperBuilder = arguments.hyper;
		return this;
	}

	/**
	 * Execute an HTTP request and return a wrapped ListmonkResponse.
	 *
	 * @method      HTTP method (GET, POST, PUT, PATCH, DELETE)
	 * @path        API path relative to the configured base URL
	 * @body        Request body struct (for JSON APIs)
	 * @params      Query string parameters
	 * @attachments Array of file attachment structs: [{ name, path, mimeType }]
	 *
	 * @return ListmonkResponse
	 */
	private function makeRequest(
		required string method,
		required string path,
		struct body       = {},
		struct params     = {},
		array attachments = []
	) {
		var hyperInstance = getHyper();
		var req           = hyperInstance.new();

		req.setUrl( arguments.path );
		req.setProperties( { "method" : arguments.method } );

		// Multipart: wrap body as JSON string in "data" field, attach files
		if ( arrayLen( arguments.attachments ) ) {
			req.setProperties( { "body" : { "data" : serializeJSON( arguments.body ) } } );
			for ( var file in arguments.attachments ) {
				req.attach(
					name     = file.name,
					path     = file.path,
					mimeType = file.keyExists( "mimeType" ) ? file.mimeType : ""
				);
			}
		} else if ( !structIsEmpty( arguments.body ) ) {
			req.setProperties( { "body" : arguments.body } );
		}

		if ( !structIsEmpty( arguments.params ) ) {
			req.withQueryParams( arguments.params );
		}

		var rawResponse = "";
		try {
			rawResponse = req.send();
		} catch ( any e ) {
			if ( !isNull( variables.log ) ) {
				variables.log.error(
					"Listmonk #arguments.method# #arguments.path# failed: #e.message#",
					e
				);
			}
			rethrow;
		}

		return new listmonk.models.ListmonkResponse( rawResponse );
	}

	/**
	 * Merge module defaults into a transactional payload when keys are absent.
	 *
	 * @payload Caller-supplied transactional payload
	 *
	 * @return struct
	 */
	private function applyTransactionalDefaults( required struct payload ) {
		var body = duplicate( arguments.payload );
		if ( !structKeyExists( body, "subscriber_mode" ) && structKeyExists( variables.moduleSettings, "subscriberMode" ) ) {
			body.subscriber_mode = variables.moduleSettings.subscriberMode;
		}
		if ( !structKeyExists( body, "content_type" ) && structKeyExists( variables.moduleSettings, "contentType" ) ) {
			body.content_type = variables.moduleSettings.contentType;
		}
		if ( !structKeyExists( body, "template_id" ) && structKeyExists( variables.moduleSettings, "defaultTemplateId" ) && variables.moduleSettings.defaultTemplateId > 0 ) {
			body.template_id = variables.moduleSettings.defaultTemplateId;
		}
		return body;
	}

	// =========================================================================
	// Health & Transactional
	// =========================================================================

	/**
	 * Health check endpoint.
	 *
	 * @return ListmonkResponse
	 */
	function healthCheck() {
		return makeRequest( method = "GET", path = "/api/health" );
	}

	/**
	 * Send a transactional email.
	 *
	 * Applies moduleSettings.subscriberMode, contentType, and defaultTemplateId
	 * when those keys are not present on the payload.
	 *
	 * When attachments are provided, the request switches to multipart/form-data
	 * with the payload as a JSON "data" field and files as "file" fields.
	 *
	 * When perRecipientData is provided, sends individual requests — one per
	 * recipient. Each entry's "data" struct is merged into the base payload
	 * (with per-recipient values winning on conflict). This is the escape hatch
	 * for custom per-recipient variables like encrypted unsubscribe links.
	 *
	 * @payload          Transactional send payload
	 * @attachments      Array of file attachment structs: [{ name, path, mimeType }]
	 * @perRecipientData Array of per-recipient structs: [{ email, data }]
	 *                   When provided, sends one request per recipient.
	 *                   Each entry's "data" is merged into the base payload.
	 *                   The "email" key is used as the recipient for that request.
	 *
	 * @return ListmonkResponse — for batch, single response; for per-recipient,
	 *         returns the last response. Check result.isOk() on each if needed.
	 */
	function sendTransactional(
		required struct payload,
		array attachments       = [],
		array perRecipientData  = []
	) {
		// Per-recipient path: send one request per recipient
		if ( arrayLen( arguments.perRecipientData ) ) {
			var lastResult = "";
			for ( var entry in arguments.perRecipientData ) {
				var recipientPayload = duplicate( arguments.payload );
				// Set this recipient's email (single, not array)
				recipientPayload.delete( "subscriber_emails" );
				recipientPayload.delete( "subscriber_email" );
				recipientPayload.subscriber_email = entry.email;
				// Merge per-recipient data into the base data
				if ( structKeyExists( entry, "data" ) && isStruct( entry.data ) ) {
					var baseData = recipientPayload.keyExists( "data" ) && isStruct( recipientPayload.data )
						? recipientPayload.data
						: {};
					structAppend( baseData, entry.data, true );
					recipientPayload.data = baseData;
				}
				applyTransactionalDefaults( recipientPayload );
				lastResult = makeRequest(
					method      = "POST",
					path        = "/api/tx",
					body        = recipientPayload,
					attachments = arguments.attachments
				);
			}
			return lastResult;
		}

		// Batch path: single request to all recipients
		return makeRequest(
			method      = "POST",
			path        = "/api/tx",
			body        = applyTransactionalDefaults( arguments.payload ),
			attachments = arguments.attachments
		);
	}

	// =========================================================================
	// Subscribers
	// =========================================================================

	/**
	 * List / query subscribers.
	 *
	 * @params Query parameters (page, per_page, query, etc.)
	 *
	 * @return ListmonkResponse
	 */
	function getSubscribers( struct params = {} ) {
		return makeRequest( method = "GET", path = "/api/subscribers", params = arguments.params );
	}

	/**
	 * Get a subscriber by ID.
	 *
	 * @id Subscriber ID
	 *
	 * @return ListmonkResponse
	 */
	function getSubscriber( required numeric id ) {
		return makeRequest( method = "GET", path = "/api/subscribers/#arguments.id#" );
	}

	/**
	 * Create a subscriber.
	 *
	 * @data Subscriber body
	 *
	 * @return ListmonkResponse
	 */
	function createSubscriber( required struct data ) {
		return makeRequest( method = "POST", path = "/api/subscribers", body = arguments.data );
	}

	/**
	 * Update a subscriber (PUT).
	 *
	 * @id   Subscriber ID
	 * @data Subscriber body
	 *
	 * @return ListmonkResponse
	 */
	function updateSubscriber( required numeric id, required struct data ) {
		return makeRequest( method = "PUT", path = "/api/subscribers/#arguments.id#", body = arguments.data );
	}

	/**
	 * Patch a subscriber.
	 *
	 * @id   Subscriber ID
	 * @data Partial subscriber body
	 *
	 * @return ListmonkResponse
	 */
	function patchSubscriber( required numeric id, required struct data ) {
		return makeRequest( method = "PATCH", path = "/api/subscribers/#arguments.id#", body = arguments.data );
	}

	/**
	 * Delete a subscriber.
	 *
	 * @id Subscriber ID
	 *
	 * @return ListmonkResponse
	 */
	function deleteSubscriber( required numeric id ) {
		return makeRequest( method = "DELETE", path = "/api/subscribers/#arguments.id#" );
	}

	/**
	 * Manage subscriber list memberships in bulk.
	 *
	 * @payload Membership payload
	 *
	 * @return ListmonkResponse
	 */
	function manageSubscriberLists( required struct payload ) {
		return makeRequest( method = "PUT", path = "/api/subscribers/lists", body = arguments.payload );
	}

	/**
	 * Manage subscriber list memberships for a specific list.
	 *
	 * @listId  List ID
	 * @payload Membership payload
	 *
	 * @return ListmonkResponse
	 */
	function manageSubscriberListsByList( required numeric listId, required struct payload ) {
		return makeRequest(
			method = "PUT",
			path   = "/api/subscribers/lists/#arguments.listId#",
			body   = arguments.payload
		);
	}

	/**
	 * Send opt-in confirmation to a subscriber.
	 *
	 * @id Subscriber ID
	 *
	 * @return ListmonkResponse
	 */
	function sendOptin( required numeric id ) {
		return makeRequest( method = "POST", path = "/api/subscribers/#arguments.id#/optin" );
	}

	/**
	 * Blocklist subscribers in bulk.
	 *
	 * @payload Blocklist payload
	 *
	 * @return ListmonkResponse
	 */
	function blocklistSubscribers( required struct payload ) {
		return makeRequest( method = "PUT", path = "/api/subscribers/blocklist", body = arguments.payload );
	}

	/**
	 * Blocklist a single subscriber.
	 *
	 * @id Subscriber ID
	 *
	 * @return ListmonkResponse
	 */
	function blocklistSubscriber( required numeric id ) {
		return makeRequest( method = "PUT", path = "/api/subscribers/#arguments.id#/blocklist" );
	}

	/**
	 * Delete subscribers by ID list.
	 *
	 * @ids Array of subscriber IDs
	 *
	 * @return ListmonkResponse
	 */
	function bulkDeleteSubscribers( required array ids ) {
		return makeRequest( method = "DELETE", path = "/api/subscribers", body = { ids : arguments.ids } );
	}

	/**
	 * Delete subscribers matching a query.
	 *
	 * @payload Query delete payload
	 *
	 * @return ListmonkResponse
	 */
	function deleteSubscribersByQuery( required struct payload ) {
		return makeRequest( method = "POST", path = "/api/subscribers/query/delete", body = arguments.payload );
	}

	/**
	 * Blocklist subscribers matching a query.
	 *
	 * @payload Query blocklist payload
	 *
	 * @return ListmonkResponse
	 */
	function blocklistSubscribersByQuery( required struct payload ) {
		return makeRequest( method = "PUT", path = "/api/subscribers/query/blocklist", body = arguments.payload );
	}

	/**
	 * Export subscribers.
	 *
	 * @params Export query parameters
	 *
	 * @return ListmonkResponse
	 */
	function exportSubscribers( struct params = {} ) {
		return makeRequest( method = "GET", path = "/api/subscribers/export", params = arguments.params );
	}

	/**
	 * Get subscriber activity.
	 *
	 * @id Subscriber ID
	 *
	 * @return ListmonkResponse
	 */
	function getSubscriberActivity( required numeric id ) {
		return makeRequest( method = "GET", path = "/api/subscribers/#arguments.id#/activity" );
	}

	/**
	 * Export a single subscriber's data.
	 *
	 * @id Subscriber ID
	 *
	 * @return ListmonkResponse
	 */
	function exportSubscriberData( required numeric id ) {
		return makeRequest( method = "GET", path = "/api/subscribers/#arguments.id#/export" );
	}

	/**
	 * Get bounces for a subscriber.
	 *
	 * @id Subscriber ID
	 *
	 * @return ListmonkResponse
	 */
	function getSubscriberBounces( required numeric id ) {
		return makeRequest( method = "GET", path = "/api/subscribers/#arguments.id#/bounces" );
	}

	/**
	 * Delete bounces for a subscriber.
	 *
	 * @id Subscriber ID
	 *
	 * @return ListmonkResponse
	 */
	function deleteSubscriberBounces( required numeric id ) {
		return makeRequest( method = "DELETE", path = "/api/subscribers/#arguments.id#/bounces" );
	}

	// =========================================================================
	// Lists
	// =========================================================================

	/**
	 * List mailing lists.
	 *
	 * @params Query parameters
	 *
	 * @return ListmonkResponse
	 */
	function getLists( struct params = {} ) {
		return makeRequest( method = "GET", path = "/api/lists", params = arguments.params );
	}

	/**
	 * Get a mailing list by ID.
	 *
	 * @id List ID
	 *
	 * @return ListmonkResponse
	 */
	function getList( required numeric id ) {
		return makeRequest( method = "GET", path = "/api/lists/#arguments.id#" );
	}

	/**
	 * Create a mailing list.
	 *
	 * @data List body
	 *
	 * @return ListmonkResponse
	 */
	function createList( required struct data ) {
		return makeRequest( method = "POST", path = "/api/lists", body = arguments.data );
	}

	/**
	 * Update a mailing list.
	 *
	 * @id   List ID
	 * @data List body
	 *
	 * @return ListmonkResponse
	 */
	function updateList( required numeric id, required struct data ) {
		return makeRequest( method = "PUT", path = "/api/lists/#arguments.id#", body = arguments.data );
	}

	/**
	 * Delete a mailing list.
	 *
	 * @id List ID
	 *
	 * @return ListmonkResponse
	 */
	function deleteList( required numeric id ) {
		return makeRequest( method = "DELETE", path = "/api/lists/#arguments.id#" );
	}

	/**
	 * Delete mailing lists by ID list.
	 *
	 * @ids Array of list IDs
	 *
	 * @return ListmonkResponse
	 */
	function deleteLists( required array ids ) {
		return makeRequest( method = "DELETE", path = "/api/lists", body = { ids : arguments.ids } );
	}

	// =========================================================================
	// Templates
	// =========================================================================

	/**
	 * List templates.
	 *
	 * @params Query parameters
	 *
	 * @return ListmonkResponse
	 */
	function getTemplates( struct params = {} ) {
		return makeRequest( method = "GET", path = "/api/templates", params = arguments.params );
	}

	/**
	 * Get a template by ID.
	 *
	 * @id Template ID
	 *
	 * @return ListmonkResponse
	 */
	function getTemplate( required numeric id ) {
		return makeRequest( method = "GET", path = "/api/templates/#arguments.id#" );
	}

	/**
	 * Create a template.
	 *
	 * @data Template body
	 *
	 * @return ListmonkResponse
	 */
	function createTemplate( required struct data ) {
		return makeRequest( method = "POST", path = "/api/templates", body = arguments.data );
	}

	/**
	 * Update a template.
	 *
	 * @id   Template ID
	 * @data Template body
	 *
	 * @return ListmonkResponse
	 */
	function updateTemplate( required numeric id, required struct data ) {
		return makeRequest( method = "PUT", path = "/api/templates/#arguments.id#", body = arguments.data );
	}

	/**
	 * Set a template as the default.
	 *
	 * @id Template ID
	 *
	 * @return ListmonkResponse
	 */
	function setDefaultTemplate( required numeric id ) {
		return makeRequest( method = "PUT", path = "/api/templates/#arguments.id#/default" );
	}

	/**
	 * Delete a template.
	 *
	 * @id Template ID
	 *
	 * @return ListmonkResponse
	 */
	function deleteTemplate( required numeric id ) {
		return makeRequest( method = "DELETE", path = "/api/templates/#arguments.id#" );
	}

	// =========================================================================
	// Settings & System
	// =========================================================================

	/**
	 * Get Listmonk settings.
	 *
	 * @return ListmonkResponse
	 */
	function getSettings() {
		return makeRequest( method = "GET", path = "/api/settings" );
	}

	/**
	 * Update Listmonk settings.
	 *
	 * @data Settings body
	 *
	 * @return ListmonkResponse
	 */
	function updateSettings( required struct data ) {
		return makeRequest( method = "PUT", path = "/api/settings", body = arguments.data );
	}

	/**
	 * Update a settings key.
	 *
	 * @key  Settings key
	 * @data Settings body
	 *
	 * @return ListmonkResponse
	 */
	function updateSettingsByKey( required string key, required struct data ) {
		return makeRequest( method = "PUT", path = "/api/settings/#arguments.key#", body = arguments.data );
	}

	/**
	 * Test SMTP configuration.
	 *
	 * @data SMTP test payload
	 *
	 * @return ListmonkResponse
	 */
	function testSMTP( required struct data ) {
		return makeRequest( method = "POST", path = "/api/settings/smtp/test", body = arguments.data );
	}

	/**
	 * Reload the Listmonk application.
	 *
	 * @return ListmonkResponse
	 */
	function reloadApp() {
		return makeRequest( method = "POST", path = "/api/admin/reload" );
	}

	/**
	 * Get application logs.
	 *
	 * @params Query parameters
	 *
	 * @return ListmonkResponse
	 */
	function getLogs( struct params = {} ) {
		return makeRequest( method = "GET", path = "/api/logs", params = arguments.params );
	}

	/**
	 * Get server config.
	 *
	 * @return ListmonkResponse
	 */
	function getConfig() {
		return makeRequest( method = "GET", path = "/api/config" );
	}

	/**
	 * Get about / version info.
	 *
	 * @return ListmonkResponse
	 */
	function getAbout() {
		return makeRequest( method = "GET", path = "/api/about" );
	}

	/**
	 * Get language pack.
	 *
	 * @lang Language code
	 *
	 * @return ListmonkResponse
	 */
	function getLang( required string lang ) {
		return makeRequest( method = "GET", path = "/api/lang/#arguments.lang#" );
	}

	/**
	 * Get SSE / events stream endpoint metadata.
	 *
	 * @return ListmonkResponse
	 */
	function getEvents() {
		return makeRequest( method = "GET", path = "/api/events" );
	}

	/**
	 * Forward a bounce webhook payload.
	 *
	 * @data Bounce webhook body
	 *
	 * @return ListmonkResponse
	 */
	function handleBounceWebhook( required struct data ) {
		return makeRequest( method = "POST", path = "/webhooks/bounce", body = arguments.data );
	}

	/**
	 * Forward a service webhook payload.
	 *
	 * @service Service name
	 * @data    Webhook body
	 *
	 * @return ListmonkResponse
	 */
	function handleServiceWebhook( required string service, required struct data ) {
		return makeRequest(
			method = "POST",
			path   = "/webhooks/service/#arguments.service#",
			body   = arguments.data
		);
	}

}
