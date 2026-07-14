/**
 * Typed response wrapper for Listmonk API responses.
 *
 * Wraps the raw Hyper response to provide a consistent interface:
 *   - isOk() / isError() for status checking
 *   - data() for the parsed response body
 *   - status() for the HTTP status code
 *   - message() for error messages
 *   - raw() for the underlying HyperResponse
 *
 * @author inLeague LLC
 */
component {

	variables._raw     = "";
	variables._data    = "";
	variables._status  = 0;
	variables._message = "";

	/**
	 * Initialize the response wrapper.
	 *
	 * @rawResponse The HyperResponse object from the HTTP call
	 *
	 * @return ListmonkResponse
	 */
	function init( required rawResponse ) {
		variables._raw    = arguments.rawResponse;
		variables._status = arguments.rawResponse.getStatusCode() ?: 0;

		var body = "";
		try {
			body = arguments.rawResponse.json();
		} catch ( any e ) {
			body = "";
		}

		// Listmonk wraps successful responses in { "data": ... }
		// and errors in { "message": "..." }
		if ( isStruct( body ) ) {
			if ( structKeyExists( body, "data" ) ) {
				variables._data = body.data;
			}
			if ( structKeyExists( body, "message" ) ) {
				variables._message = body.message;
			}
		} else {
			variables._data = body;
		}

		return this;
	}

	/**
	 * Returns true if the HTTP status is 2xx.
	 *
	 * @return boolean
	 */
	function isOk() {
		return variables._status >= 200 && variables._status < 300;
	}

	/**
	 * Returns true if the HTTP status is 4xx or 5xx.
	 *
	 * @return boolean
	 */
	function isError() {
		return !isOk();
	}

	/**
	 * Returns the HTTP status code.
	 *
	 * @return numeric
	 */
	function status() {
		return variables._status;
	}

	/**
	 * Returns the parsed response data (the "data" key from Listmonk).
	 * For list responses, this is typically an array.
	 * For single-item responses, this is a struct.
	 *
	 * @return any
	 */
	function data() {
		return variables._data;
	}

	/**
	 * Returns the error message from Listmonk, if any.
	 * Empty string on success.
	 *
	 * @return string
	 */
	function message() {
		return variables._message;
	}

	/**
	 * Returns the raw HyperResponse object.
	 *
	 * @return any
	 */
	function raw() {
		return variables._raw;
	}

}
