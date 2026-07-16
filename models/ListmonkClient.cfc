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
	 * Pre-configured HyperBuilder for Listmonk requests.
	 * Not WireBox-injected: required=false still fails hard when the alias is unmapped
	 * (interceptor boot before module mappings). Lazily built in getHyper() from moduleSettings,
	 * or set via init()/setHyper() / optional DI mapping in the host WireBox binder.
	 */
	property name="hyperBuilder";

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
				"subscriberMode" : "fallback",
				"contentType"    : "html",
				"defaultTemplateId" : 0
			};
		}
		return this;
	}

	/**
	 * Get the underlying HyperBuilder instance.
	 * Lazily constructs one from moduleSettings when the named WireBox client is unavailable.
	 *
	 * @return HyperBuilder
	 */
	function getHyper() {
		if ( !isNull( variables.hyperBuilder ) ) {
			return variables.hyperBuilder;
		}

		var settings = isNull( variables.moduleSettings ) ? {} : variables.moduleSettings;
		variables.hyperBuilder = new hyper.models.HyperBuilder(
			baseUrl    = settings.baseUrl ?: "",
			timeout    = settings.timeout ?: 30,
			bodyFormat = "json",
			headers    = {
				"Authorization" : "Token #( settings.apiToken ?: '' )#",
				"Content-Type"  : "application/json",
				"Accept"        : "application/json"
			}
		);


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




	// =========================================================================
	// Webhook Management
	// =========================================================================

	/**
	 * List configured webhooks.
	 *
	 * @return ListmonkResponse
	 */
	function getWebhooks() {
		return makeRequest( method = "GET", path = "/api/webhooks" );
	}

	/**
	 * Get a webhook by ID.
	 *
	 * @id Webhook ID
	 *
	 * @return ListmonkResponse
	 */
	function getWebhook( required numeric id ) {
		return makeRequest( method = "GET", path = "/api/webhooks/#arguments.id#" );
	}

	/**
	 * Create a webhook.
	 *
	 * @data Webhook body: { url, events, method, headers, enabled }
	 *
	 * Example:
	 *   { url: "https://api.inleague.io/webhooks/listmonk",
	 *     events: ["subscriber.unsubscribed", "subscriber.optimed"],
	 *     method: "POST",
	 *     enabled: true }
	 *
	 * @return ListmonkResponse
	 */
	function createWebhook( required struct data ) {
		return makeRequest( method = "POST", path = "/api/webhooks", body = arguments.data );
	}

	/**
	 * Update a webhook.
	 *
	 * @id   Webhook ID
	 * @data Webhook body
	 *
	 * @return ListmonkResponse
	 */
	function updateWebhook( required numeric id, required struct data ) {
		return makeRequest( method = "PUT", path = "/api/webhooks/#arguments.id#", body = arguments.data );
	}

	/**
	 * Delete a webhook.
	 *
	 * @id Webhook ID
	 *
	 * @return ListmonkResponse
	 */
	function deleteWebhook( required numeric id ) {
		return makeRequest( method = "DELETE", path = "/api/webhooks/#arguments.id#" );
	}


	// =========================================================================
	// Webhook Validation
	// =========================================================================

	/**
	 * Validate a webhook request signature using HMAC-SHA256.
	 *
	 * Listmonk signs webhook payloads with:
	 *   X-Listmonk-Signature: sha256=<hex-digest>
	 *   X-Listmonk-Timestamp: <unix-timestamp>
	 *
	 * The signature is computed as: HMAC-SHA256(secret, timestamp + "." + body)
	 *
	 * @secret       The webhook secret configured in Listmonk
	 * @body         The raw request body (JSON string)
	 * @signature    The X-Listmonk-Signature header value
	 * @timestamp    The X-Listmonk-Timestamp header value
	 * @maxAgeSeconds Maximum age in seconds to accept (default: 300 = 5 min)
	 *
	 * @return boolean true if signature is valid
	 */
	function validateWebhookSignature(
		required string secret,
		required string body,
		required string signature,
		required string timestamp,
		numeric maxAgeSeconds = 300
	) {
		// Check timestamp freshness to prevent replay attacks
		var now = getUnixTimestamp();
		var webhookTime = val( arguments.timestamp );
		if ( ( now - webhookTime ) > arguments.maxAgeSeconds ) {
			return false;
		}

		// Compute expected signature using Java HMAC
		var payload = arguments.timestamp & "." & arguments.body;
		var mac = createObject( "java", "javax.crypto.Mac" ).getInstance( "HmacSHA256" );
		var secretKey = createObject( "java", "javax.crypto.spec.SecretKeySpec" )
			.init( arguments.secret.getBytes( "UTF-8" ), "HmacSHA256" );
		mac.init( secretKey );
		var rawHmac = mac.doFinal( payload.getBytes( "UTF-8" ) );
		// Convert bytes to hex string
		var hex = createObject( "java", "java.util.HexFormat" ).of().formatHex( rawHmac );
		var expected = "sha256=" & hex;

		// Direct comparison (constant-time in production)
		return expected == arguments.signature;
	}

	/**
	 * Extract the event type from a webhook payload.
	 *
	 * @data The parsed webhook body struct
	 *
	 * @return string Event type (e.g., "subscriber.unsubscribed")
	 */
	function getWebhookEvent( required struct data ) {
		return data.keyExists( "event" ) ? data.event : "";
	}

	/**
	 * Get the current Unix timestamp.
	 *
	 * @return numeric
	 */
	private function getUnixTimestamp() {
		return dateDiff( "s", createObject( "java", "java.time.Instant" ).EPOCH, now() );
	}



	// =========================================================================
	// Subscriber Sync Convenience Methods
	// =========================================================================

	/**
	 * Find a subscriber by email within a list.
	 *
	 * Uses the subscriber query API with a SQL expression to locate a subscriber
	 * by email. Returns the first matching subscriber or a not-found response.
	 *
	 * @email    Subscriber email address
	 * @listId   Optional list ID to scope the search
	 *
	 * @return ListmonkResponse — data contains the subscriber or null
	 */
	function findSubscriberByEmail( required string email, numeric listId ) {
		var query = "subscribers.email = ''#arguments.email#''";
		var params = { "query" : query, "per_page" : 1 };
		if ( !isNull( arguments.listId ) ) {
			params.list_id = arguments.listId;
		}
		return makeRequest( method = "GET", path = "/api/subscribers", params = params );
	}

	/**
	 * Extract a numeric Listmonk entity id from an API data payload.
	 * Accepts `{ id }` or nested `{ data: { id } }`.
	 *
	 * @data Response data() payload (or similar struct)
	 *
	 * @return numeric id or 0
	 */
	function extractIdFromData( any data ) {
		if ( isNull( arguments.data ) || !isStruct( arguments.data ) ) {
			return 0;
		}
		if ( structKeyExists( arguments.data, "id" ) ) {
			return val( arguments.data.id );
		}
		if ( structKeyExists( arguments.data, "data" ) && isStruct( arguments.data.data ) ) {
			return val( arguments.data.data.id ?: 0 );
		}
		return 0;
	}

	/**
	 * Upsert a subscriber: find by email, create or update as needed.
	 *
	 * If a subscriber with the given email exists, patches their name, attributes,
	 * and list memberships. If not, creates a new subscriber. Returns the
	 * subscriber object (with ID) so callers can store the Listmonk subscriber ID.
	 *
	 * Prefer ensureSubscriberOnLists() when the caller may already know the subscriber ID.
	 *
	 * @email               Subscriber email
	 * @name                Subscriber name
	 * @listIds             Array of list IDs to subscribe to
	 * @attribs             Custom attributes (e.g., { unsub_token, roles, seasons })
	 * @preconfirmSubscriptions If true, subscriptions are confirmed immediately
	 *
	 * @return ListmonkResponse — data contains { id, email, name, attribs, lists }
	 */
	function upsertSubscriber(
		required string email,
		required string name,
		required array listIds,
		struct attribs              = {},
		boolean preconfirmSubscriptions = true
	) {
		// Search for existing subscriber by email
		var search = findSubscriberByEmail( arguments.email );
		var existingId = 0;

		if ( search.isOk() ) {
			var results = search.data();
			if ( isStruct( results ) && structKeyExists( results, "results" ) && arrayLen( results.results ) ) {
				existingId = results.results[ 1 ].id;
			}
		}

		var payload = {
			"email"                    : arguments.email,
			"name"                     : arguments.name,
			"lists"                    : arguments.listIds,
			"attribs"                  : arguments.attribs,
			"preconfirm_subscriptions" : arguments.preconfirmSubscriptions
		};

		if ( existingId ) {
			// PATCH preserves existing list subscriptions; PUT clears them
			return patchSubscriber( id = existingId, data = payload );
		} else {
			return createSubscriber( data = payload );
		}
	}

	/**
	 * Ensure an email is a Listmonk subscriber on the given lists.
	 *
	 * Preferred multi-list sync helper for host apps:
	 * - If existingSubscriberId is known, add that subscriber to listIds (1 HTTP).
	 * - Otherwise upsert by email (find + create/PATCH; PATCH preserves other lists).
	 *
	 * On the existing-id path, returns a hydrated ok response whose data() includes `{ id }`
	 * so callers can always use extractIdFromData().
	 *
	 * @email                 Subscriber email
	 * @name                  Subscriber name
	 * @listIds               Array of list IDs to ensure membership on
	 * @attribs               Custom attributes (used on upsert path)
	 * @existingSubscriberId  Known Listmonk subscriber id (0 = look up / create)
	 * @preconfirmSubscriptions If true, new subscriptions are confirmed immediately
	 *
	 * @return ListmonkResponse
	 */
	function ensureSubscriberOnLists(
		required string email,
		required string name,
		required array listIds,
		struct attribs                 = {},
		numeric existingSubscriberId   = 0,
		boolean preconfirmSubscriptions = true
	) {
		if ( val( arguments.existingSubscriberId ) > 0 ) {
			var addResult = addSubscribersToLists(
				subscriberIds = [ val( arguments.existingSubscriberId ) ],
				listIds       = arguments.listIds,
				status        = "confirmed"
			);
			if ( !addResult.isOk() ) {
				return addResult;
			}
			return new listmonk.models.ListmonkResponse().hydrate(
				data = { "id" : val( arguments.existingSubscriberId ) }
			);
		}

		return upsertSubscriber(
			email                   = arguments.email,
			name                    = arguments.name,
			listIds                 = arguments.listIds,
			attribs                 = arguments.attribs,
			preconfirmSubscriptions = arguments.preconfirmSubscriptions
		);
	}

	/**
	 * Add subscribers to lists.
	 *
	 * @subscriberIds Array of subscriber IDs
	 * @listIds       Array of list IDs to add them to
	 * @status        Subscription status: "confirmed", "unconfirmed", or "unsubscribed"
	 *
	 * @return ListmonkResponse
	 */
	function addSubscribersToLists(
		required array subscriberIds,
		required array listIds,
		string status = "confirmed"
	) {
		return manageSubscriberLists( payload = {
			"ids"              : arguments.subscriberIds,
			"action"           : "add",
			"target_list_ids"  : arguments.listIds,
			"status"           : arguments.status
		} );
	}

	/**
	 * Remove subscribers from lists.
	 *
	 * @subscriberIds Array of subscriber IDs
	 * @listIds       Array of list IDs to remove them from
	 *
	 * @return ListmonkResponse
	 */
	function removeSubscribersFromLists(
		required array subscriberIds,
		required array listIds
	) {
		return manageSubscriberLists( payload = {
			"ids"              : arguments.subscriberIds,
			"action"           : "remove",
			"target_list_ids"  : arguments.listIds
		} );
	}

}
