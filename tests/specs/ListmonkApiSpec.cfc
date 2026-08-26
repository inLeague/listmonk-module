/**
 * Live Listmonk API coverage. Hits each authenticated (and public) API route
 * exposed by Listmonk v6.2.0 through ListmonkClient.
 *
 * Skips: PUT /api/settings and POST /api/admin/reload (both restart Listmonk),
 * GET /api/events (SSE hang), TOTP, and POST /api/logout.
 */
component extends="tests.ColdboxBase" {

	function beforeAll() {
		super.beforeAll();
		wirebox.clearSingletons();
		variables.lm     = wirebox.getInstance( "ListmonkClient@listmonk" );
		variables.suffix = lCase( left( replace( createUUID(), "-", "", "all" ), 12 ) );
		variables.email  = "spec-#variables.suffix#@example.test";
		variables.created = {
			"lists"       : [],
			"subscribers" : [],
			"campaigns"   : [],
			"templates"   : [],
			"media"       : [],
			"users"       : [],
			"roles"       : []
		};

		var list = expectOk(
			variables.lm.createList( {
				"name"   : "spec-list-#variables.suffix#",
				"type"   : "private",
				"optin"  : "single",
				"tags"   : [ "spec" ]
			} ),
			"createList fixture"
		);
		variables.listId = list.id;
		arrayAppend( variables.created.lists, variables.listId );

		var publicList = expectOk(
			variables.lm.createList( {
				"name"  : "spec-public-#variables.suffix#",
				"type"  : "public",
				"optin" : "single",
				"tags"  : [ "spec" ]
			} ),
			"createList public fixture"
		);
		variables.publicListId   = publicList.id;
		variables.publicListUuid = publicList.uuid ?: "";
		arrayAppend( variables.created.lists, variables.publicListId );

		var templates = expectOk( variables.lm.getTemplates(), "getTemplates fixture" );
		if ( !isArray( templates ) ) {
			templates = templates.results ?: [];
		}
		variables.campaignTemplateId = 0;
		variables.txTemplateId       = 0;
		variables.defaultTemplateId  = 0;
		for ( var t in templates ) {
			if ( ( t.type ?: "" ) == "campaign" && ( t.is_default ?: false ) ) {
				variables.campaignTemplateId = t.id;
				variables.defaultTemplateId  = t.id;
			}
			if ( ( t.type ?: "" ) == "tx" && !variables.txTemplateId ) {
				variables.txTemplateId = t.id;
			}
		}

		var campaignTpl = expectOk(
			variables.lm.createTemplate( {
				"name" : "spec-campaign-tpl-#variables.suffix#",
				"type" : "campaign",
				"body" : '{{ template "content" . }}'
			} ),
			"createTemplate campaign fixture"
		);
		variables.specCampaignTemplateId = entityId( campaignTpl );
		arrayAppend( variables.created.templates, variables.specCampaignTemplateId );
		if ( !variables.campaignTemplateId ) {
			variables.campaignTemplateId = variables.specCampaignTemplateId;
		}

		var txTpl = expectOk(
			variables.lm.createTemplate( {
				"name"    : "spec-tx-tpl-#variables.suffix#",
				"type"    : "tx",
				"subject" : "Spec transactional",
				"body"    : "<p>Hello {{ .Subscriber.Name }}</p>"
			} ),
			"createTemplate tx fixture"
		);
		variables.specTxTemplateId = entityId( txTpl );
		arrayAppend( variables.created.templates, variables.specTxTemplateId );
		if ( !variables.txTemplateId ) {
			variables.txTemplateId = variables.specTxTemplateId;
		}

		var sub = expectOk(
			variables.lm.createSubscriber( {
				"email"                    : variables.email,
				"name"                     : "Spec Subscriber",
				"status"                   : "enabled",
				"lists"                    : [ variables.listId ],
				"preconfirm_subscriptions" : true
			} ),
			"createSubscriber fixture"
		);
		variables.subscriberId = sub.id;
		arrayAppend( variables.created.subscribers, variables.subscriberId );

		var campaign = expectOk(
			variables.lm.createCampaign( {
				"name"         : "spec-campaign-#variables.suffix#",
				"subject"      : "Spec campaign",
				"lists"        : [ variables.listId ],
				"type"         : "regular",
				"content_type" : "html",
				"body"         : "<p>Hello {{ .Subscriber.Name }}</p>",
				"messenger"    : "email",
				"template_id"  : variables.campaignTemplateId,
				"tags"         : [ "spec" ]
			} ),
			"createCampaign fixture"
		);
		variables.campaignId = campaign.id;
		arrayAppend( variables.created.campaigns, variables.campaignId );
	}

	function afterAll() {
		if ( structKeyExists( variables, "created" ) && structKeyExists( variables, "lm" ) ) {
			cleanupEach( variables.created.campaigns, "deleteCampaign" );
			cleanupEach( variables.created.media, "deleteMedia" );
			cleanupEach( variables.created.subscribers, "deleteSubscriber" );
			cleanupEach( variables.created.templates, "deleteTemplate" );
			cleanupEach( variables.created.users, "deleteUser" );
			cleanupEach( variables.created.roles, "deleteRole" );
			cleanupEach( variables.created.lists, "deleteList" );
		}
		super.afterAll();
	}

	function run() {
		describe( "Listmonk API", function() {

			describe( "health and dashboard", function() {
				it( "GET /api/health", function() {
					expectOk( variables.lm.healthCheck(), "healthCheck" );
				} );

				it( "GET /api/dashboard/charts", function() {
					expectOk( variables.lm.getDashboardCharts(), "getDashboardCharts" );
				} );

				it( "GET /api/dashboard/counts", function() {
					expectOk( variables.lm.getDashboardCounts(), "getDashboardCounts" );
				} );
			} );

			describe( "system", function() {
				it( "GET /api/config", function() {
					var data = expectOk( variables.lm.getConfig(), "getConfig" );
					expect( data ).toBeStruct();
				} );

				it( "GET /api/about", function() {
					expectOk( variables.lm.getAbout(), "getAbout" );
				} );

				it( "GET /api/lang/{lang}", function() {
					var data = expectOk( variables.lm.getLang( "en" ), "getLang" );
					expect( data ).toBeStruct();
				} );

				it( "GET /api/logs", function() {
					expectOk( variables.lm.getLogs(), "getLogs" );
				} );
			} );

			describe( "settings", function() {
				it( "GET /api/settings and POST /api/settings/smtp/test", function() {
					var data = expectOk( variables.lm.getSettings(), "getSettings" );
					expect( data ).toBeStruct();
					var smtp = {};
					if ( structKeyExists( data, "smtp" ) && isArray( data.smtp ) && arrayLen( data.smtp ) ) {
						smtp = data.smtp[ 1 ];
					}
					expectHit( variables.lm.testSMTP( smtp ), "testSMTP" );
				} );
			} );

			describe( "lists", function() {
				it( "GET /api/lists", function() {
					var data = expectOk( variables.lm.getLists(), "getLists" );
					expect( data.results ).toBeArray();
				} );

				it( "GET /api/lists/{id}", function() {
					var data = expectOk( variables.lm.getList( variables.listId ), "getList" );
					expect( data.id ).toBe( variables.listId );
				} );

				it( "PUT /api/lists/{id}", function() {
					var data = expectOk(
						variables.lm.updateList( variables.listId, {
							"name"        : "spec-list-#variables.suffix#-updated",
							"type"        : "private",
							"optin"       : "single",
							"description" : "updated by spec"
						} ),
						"updateList"
					);
					expect( data.name ).toInclude( "updated" );
				} );

				it( "DELETE /api/lists/{id}", function() {
					var extra = expectOk(
						variables.lm.createList( {
							"name"  : "spec-del-#variables.suffix#",
							"type"  : "private",
							"optin" : "single"
						} ),
						"createList for delete"
					);
					expectOk( variables.lm.deleteList( extra.id ), "deleteList" );
				} );

				it( "DELETE /api/lists", function() {
					var a = expectOk(
						variables.lm.createList( { "name" : "spec-bulk-a-#variables.suffix#", "type" : "private", "optin" : "single" } ),
						"createList bulk a"
					);
					var b = expectOk(
						variables.lm.createList( { "name" : "spec-bulk-b-#variables.suffix#", "type" : "private", "optin" : "single" } ),
						"createList bulk b"
					);
					expectHit( variables.lm.deleteLists( query = "spec-bulk-#variables.suffix#" ), "deleteLists" );
					expectOk( variables.lm.deleteList( a.id ), "cleanup deleteLists a" );
					expectOk( variables.lm.deleteList( b.id ), "cleanup deleteLists b" );
				} );
			} );

			describe( "subscribers", function() {
				it( "GET /api/subscribers", function() {
					var data = expectOk( variables.lm.getSubscribers(), "getSubscribers" );
					expect( data.results ).toBeArray();
				} );

				it( "GET /api/subscribers/{id}", function() {
					var data = expectOk( variables.lm.getSubscriber( variables.subscriberId ), "getSubscriber" );
					expect( data.id ).toBe( variables.subscriberId );
				} );

				it( "PUT /api/subscribers/{id}", function() {
					var current = expectOk( variables.lm.getSubscriber( variables.subscriberId ), "getSubscriber before put" );
					var data    = expectOk(
						variables.lm.updateSubscriber( variables.subscriberId, {
							"email"  : current.email,
							"name"   : "Spec Subscriber Updated",
							"status" : "enabled",
							"lists"  : [ variables.listId ]
						} ),
						"updateSubscriber"
					);
					expect( data.name ).toInclude( "Updated" );
				} );

				it( "PATCH /api/subscribers/{id}", function() {
					var data = expectOk(
						variables.lm.patchSubscriber( variables.subscriberId, { "name" : "Spec Subscriber Patched" } ),
						"patchSubscriber"
					);
					expect( data.name ).toInclude( "Patched" );
				} );

				it( "GET /api/subscribers/{id}/activity", function() {
					expectOk( variables.lm.getSubscriberActivity( variables.subscriberId ), "getSubscriberActivity" );
				} );

				it( "GET /api/subscribers/{id}/export", function() {
					expectOk( variables.lm.exportSubscriberData( variables.subscriberId ), "exportSubscriberData" );
				} );

				it( "GET /api/subscribers/{id}/bounces", function() {
					expectOk( variables.lm.getSubscriberBounces( variables.subscriberId ), "getSubscriberBounces" );
				} );

				it( "DELETE /api/subscribers/{id}/bounces", function() {
					expectOk( variables.lm.deleteSubscriberBounces( variables.subscriberId ), "deleteSubscriberBounces" );
				} );

				it( "POST /api/subscribers/{id}/optin", function() {
					expectHit( variables.lm.sendOptin( variables.subscriberId ), "sendOptin" );
				} );

				it( "PUT /api/subscribers/lists", function() {
					expectOk(
						variables.lm.manageSubscriberLists( {
							"ids"             : [ variables.subscriberId ],
							"action"          : "add",
							"target_list_ids" : [ variables.publicListId ],
							"status"          : "confirmed"
						} ),
						"manageSubscriberLists"
					);
				} );

				it( "PUT /api/subscribers/lists/{id}", function() {
					expectOk(
						variables.lm.manageSubscriberListsByList(
							variables.subscriberId,
							{
								"ids"             : [ variables.subscriberId ],
								"action"          : "add",
								"target_list_ids" : [ variables.publicListId ],
								"status"          : "confirmed"
							}
						),
						"manageSubscriberListsByList"
					);
				} );

				it( "PUT /api/subscribers/query/lists", function() {
					expectOk(
						variables.lm.manageSubscriberListsByQuery( {
							"query"           : emailQuery( variables.email ),
							"action"          : "add",
							"target_list_ids" : [ variables.publicListId ],
							"status"          : "confirmed"
						} ),
						"manageSubscriberListsByQuery"
					);
				} );

				it( "PUT /api/subscribers/{id}/blocklist", function() {
					var extra = createTempSubscriber( "block-one" );
					expectOk( variables.lm.blocklistSubscriber( extra ), "blocklistSubscriber" );
					expectOk( variables.lm.deleteSubscriber( extra ), "cleanup blocklistSubscriber" );
				} );

				it( "PUT /api/subscribers/blocklist", function() {
					var extra = createTempSubscriber( "block-bulk" );
					expectOk(
						variables.lm.blocklistSubscribers( { "ids" : [ extra ] } ),
						"blocklistSubscribers"
					);
					expectOk( variables.lm.deleteSubscriber( extra ), "cleanup blocklistSubscribers" );
				} );

				it( "PUT /api/subscribers/query/blocklist", function() {
					var extraEmail = "spec-qblock-#variables.suffix#@example.test";
					createTempSubscriber( "qblock", extraEmail );
					expectOk(
						variables.lm.blocklistSubscribersByQuery( {
							"query" : emailQuery( extraEmail )
						} ),
						"blocklistSubscribersByQuery"
					);
					expectOk(
						variables.lm.deleteSubscribersByQuery( {
							"query" : emailQuery( extraEmail )
						} ),
						"cleanup query blocklist"
					);
				} );

				it( "GET /api/subscribers/export", function() {
					var result = variables.lm.exportSubscribers( { "per_page" : "all" } );
					expect( result.isOk() ).toBeTrue( "exportSubscribers HTTP #result.status()# #result.message()#" );
				} );

				it( "DELETE /api/subscribers/{id}", function() {
					var extra = createTempSubscriber( "del-one" );
					var email = "spec-del-one-#variables.suffix#@example.test";

					var before = variables.lm.getSubscriber( extra );
					expect( before.status() ).toBe( 200 );
					expect( before.data().id ).toBe( extra );
					expect( before.data().email ).toBe( email );
					expect( before.data().name ).toBe( "Spec del-one" );
					expect( before.data().status ).toBe( "enabled" );

					var deleted = variables.lm.deleteSubscriber( extra );
					expect( deleted.status() ).toBe( 200 );
					expect( deleted.data() ).toBeTrue();

					var after = variables.lm.getSubscriber( extra );
					expect( after.status() ).toBe( 400 );
					expect( after.message() ).toBe( "Subscriber (#extra#: ) not found" );
				} );

				it( "DELETE /api/subscribers", function() {
					var a = createTempSubscriber( "del-a" );
					var b = createTempSubscriber( "del-b" );
					expectHit( variables.lm.bulkDeleteSubscribers( [ a ] ), "bulkDeleteSubscribers" );
					expectOk( variables.lm.deleteSubscriber( a ), "cleanup bulkDelete a" );
					expectOk( variables.lm.deleteSubscriber( b ), "cleanup bulkDelete b" );
				} );

				it( "POST /api/subscribers/query/delete", function() {
					var extraEmail = "spec-qdel-#variables.suffix#@example.test";
					createTempSubscriber( "qdel", extraEmail );
					expectOk(
						variables.lm.deleteSubscribersByQuery( {
							"query" : emailQuery( extraEmail )
						} ),
						"deleteSubscribersByQuery"
					);
				} );
			} );

			describe( "templates", function() {
				it( "GET /api/templates", function() {
					var data = expectOk( variables.lm.getTemplates(), "getTemplates" );
					expect( isArray( data ) || isStruct( data ) ).toBeTrue();
				} );

				it( "GET /api/templates/{id}", function() {
					var data = expectOk( variables.lm.getTemplate( variables.specCampaignTemplateId ), "getTemplate" );
					expect( entityId( data ) ).toBe( variables.specCampaignTemplateId );
				} );

				it( "PUT /api/templates/{id}", function() {
					expectOk(
						variables.lm.updateTemplate( variables.specCampaignTemplateId, {
							"name" : "spec-campaign-tpl-#variables.suffix#-updated",
							"type" : "campaign",
							"body" : '{{ template "content" . }}'
						} ),
						"updateTemplate"
					);
				} );

				it( "GET /api/templates/{id}/preview", function() {
					var result = variables.lm.previewTemplateById( variables.specCampaignTemplateId );
					expect( result.isOk() ).toBeTrue( "previewTemplateById HTTP #result.status()# #result.message()#" );
				} );

				it( "POST /api/templates/preview", function() {
					var result = variables.lm.previewTemplate( {
						"template_type" : "campaign",
						"body"          : '{{ template "content" . }}'
					} );
					expectHit( result, "previewTemplate" );
				} );

				it( "PUT /api/templates/{id}/default", function() {
					expectOk( variables.lm.setDefaultTemplate( variables.specCampaignTemplateId ), "setDefaultTemplate" );
					if ( variables.defaultTemplateId ) {
						expectOk( variables.lm.setDefaultTemplate( variables.defaultTemplateId ), "restore default template" );
					}
				} );

				it( "DELETE /api/templates/{id}", function() {
					var extra = expectOk(
						variables.lm.createTemplate( {
							"name" : "spec-tpl-del-#variables.suffix#",
							"type" : "campaign",
							"body" : '{{ template "content" . }}'
						} ),
						"createTemplate for delete"
					);
					expectOk( variables.lm.deleteTemplate( entityId( extra ) ), "deleteTemplate" );
				} );
			} );

			describe( "campaigns", function() {
				it( "GET /api/campaigns", function() {
					var data = expectOk( variables.lm.getCampaigns(), "getCampaigns" );
					expect( data.results ).toBeArray();
				} );

				it( "GET /api/campaigns/{id}", function() {
					var data = expectOk( variables.lm.getCampaign( variables.campaignId ), "getCampaign" );
					expect( data.id ).toBe( variables.campaignId );
				} );

				it( "PUT /api/campaigns/{id}", function() {
					var current = expectOk( variables.lm.getCampaign( variables.campaignId ), "getCampaign before put" );
					expectOk(
						variables.lm.updateCampaign( variables.campaignId, {
							"name"         : "spec-campaign-#variables.suffix#-updated",
							"subject"      : current.subject,
							"lists"        : [ variables.listId ],
							"type"         : "regular",
							"content_type" : "html",
							"body"         : current.body ?: "<p>updated</p>",
							"messenger"    : "email",
							"template_id"  : variables.campaignTemplateId,
							"tags"         : [ "spec" ]
						} ),
						"updateCampaign"
					);
				} );

				it( "GET /api/campaigns/{id}/preview", function() {
					var result = variables.lm.previewCampaign( variables.campaignId );
					expect( result.isOk() ).toBeTrue( "previewCampaign HTTP #result.status()# #result.message()#" );
				} );

				it( "POST /api/campaigns/{id}/preview", function() {
					expectHit(
						variables.lm.previewCampaignBody( variables.campaignId, {
							"body"         : "<p>preview body</p>",
							"content_type" : "html",
							"template_id"  : variables.campaignTemplateId
						} ),
						"previewCampaignBody"
					);
				} );

				it( "POST /api/campaigns/{id}/preview/archive", function() {
					expectHit(
						variables.lm.previewCampaignArchive( variables.campaignId, { "archive" : true } ),
						"previewCampaignArchive"
					);
				} );

				it( "POST /api/campaigns/{id}/text", function() {
					expectHit( variables.lm.previewCampaignText( variables.campaignId ), "previewCampaignText" );
				} );

				it( "POST /api/campaigns/{id}/content", function() {
					expectHit(
						variables.lm.setCampaignContent( variables.campaignId, {
							"body"         : "<p>replaced content</p>",
							"content_type" : "html"
						} ),
						"setCampaignContent"
					);
				} );

				it( "PUT /api/campaigns/{id}/archive", function() {
					expectOk(
						variables.lm.updateCampaignArchive( variables.campaignId, {
							"archive"             : true,
							"archive_template_id" : variables.campaignTemplateId,
							"archive_slug"        : "spec-#variables.suffix#"
						} ),
						"updateCampaignArchive"
					);
				} );

				it( "GET /api/campaigns/running/stats", function() {
					expectOk(
						variables.lm.getRunningCampaignStats( { "campaign_id" : variables.campaignId } ),
						"getRunningCampaignStats"
					);
				} );

				it( "GET /api/campaigns/analytics/{type}", function() {
					var from = ymd( dateAdd( "d", -7, now() ) );
					var to   = ymd( now() );
					expectOk(
						variables.lm.getCampaignAnalytics( "views", {
							"id"   : variables.campaignId,
							"from" : from,
							"to"   : to
						} ),
						"getCampaignAnalytics"
					);
				} );

				it( "PUT /api/campaigns/{id}/status", function() {
					expectHit(
						variables.lm.updateCampaignStatus( variables.campaignId, { "status" : "scheduled" } ),
						"updateCampaignStatus"
					);
					variables.lm.updateCampaignStatus( variables.campaignId, { "status" : "draft" } );
				} );

				it( "POST /api/campaigns/{id}/test", function() {
					expectHit(
						variables.lm.testCampaign( variables.campaignId, {
							"subscribers"  : [ variables.email ],
							"template_id"  : variables.campaignTemplateId,
							"content_type" : "html",
							"body"         : "<p>test</p>",
							"subject"      : "test",
							"lists"        : [ variables.listId ],
							"name"         : "spec-test",
							"type"         : "regular"
						} ),
						"testCampaign"
					);
				} );

				it( "DELETE /api/campaigns/{id}", function() {
					var extra = expectOk(
						variables.lm.createCampaign( {
							"name"         : "spec-camp-del-#variables.suffix#",
							"subject"      : "delete me",
							"lists"        : [ variables.listId ],
							"type"         : "regular",
							"content_type" : "html",
							"body"         : "<p>x</p>",
							"messenger"    : "email",
							"template_id"  : variables.campaignTemplateId
						} ),
						"createCampaign for delete"
					);
					expectOk( variables.lm.deleteCampaign( extra.id ), "deleteCampaign" );
				} );

				it( "DELETE /api/campaigns", function() {
					var extra = expectOk(
						variables.lm.createCampaign( {
							"name"         : "spec-camp-bulk-#variables.suffix#",
							"subject"      : "bulk delete me",
							"lists"        : [ variables.listId ],
							"type"         : "regular",
							"content_type" : "html",
							"body"         : "<p>x</p>",
							"messenger"    : "email",
							"template_id"  : variables.campaignTemplateId
						} ),
						"createCampaign for bulk delete"
					);
					expectOk( variables.lm.deleteCampaigns( { "query" : "spec-camp-bulk-#variables.suffix#" } ), "deleteCampaigns" );
				} );
			} );

			describe( "media", function() {
				it( "GET /api/media", function() {
					expectOk( variables.lm.getMedia(), "getMedia" );
				} );

				it( "POST /api/media and GET /api/media/{id} and DELETE /api/media/{id}", function() {
					var png  = getTempDirectory() & "spec-#variables.suffix#.png";
					var b64  = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==";
					fileWrite( png, binaryDecode( b64, "base64" ) );
					var uploaded = variables.lm.uploadMedia( png, "image/png" );
					if ( fileExists( png ) ) {
						fileDelete( png );
					}
					var data = expectOk( uploaded, "uploadMedia" );
					var id   = entityId( data );
					expect( id ).toBeGT( 0 );
					arrayAppend( variables.created.media, id );
					expectOk( variables.lm.getMediaById( id ), "getMediaById" );
					expectOk( variables.lm.deleteMedia( id ), "deleteMedia" );
					arrayDelete( variables.created.media, id );
				} );
			} );

			describe( "bounces", function() {
				it( "GET /api/bounces", function() {
					var data = expectOk( variables.lm.getBounces(), "getBounces" );
					expect( isStruct( data ) || isArray( data ) ).toBeTrue();
				} );

				it( "GET /api/bounces/{id} (404 when empty)", function() {
					var listed = expectOk( variables.lm.getBounces( { "per_page" : 1 } ), "getBounces for id" );
					var id     = 0;
					if ( isStruct( listed ) && structKeyExists( listed, "results" ) && isArray( listed.results ) && arrayLen( listed.results ) ) {
						id = listed.results[ 1 ].id;
					}
					if ( id ) {
						expectOk( variables.lm.getBounce( id ), "getBounce" );
						expectOk( variables.lm.deleteBounce( id ), "deleteBounce" );
					} else {
						var missing = variables.lm.getBounce( 999999 );
						expect( missing.isError() ).toBeTrue();
					}
				} );

				it( "PUT /api/bounces/blocklist", function() {
					expectHit( variables.lm.blocklistBouncedSubscribers(), "blocklistBouncedSubscribers" );
				} );

				it( "DELETE /api/bounces", function() {
					expectOk( variables.lm.deleteBounces( { "all" : true } ), "deleteBounces" );
				} );
			} );

			describe( "import", function() {
				it( "GET /api/import/subscribers", function() {
					expectOk( variables.lm.getImportSubscribers(), "getImportSubscribers" );
				} );

				it( "GET /api/import/subscribers/logs", function() {
					expectHit( variables.lm.getImportSubscriberLogs(), "getImportSubscriberLogs" );
				} );

				it( "POST /api/import/subscribers and DELETE /api/import/subscribers", function() {
					var csvPath = getTempDirectory() & "spec-import-#variables.suffix#.csv";
					var importEmail = "spec-import-#variables.suffix#@example.test";
					fileWrite( csvPath, "email,name#chr( 10 )##importEmail#,Import User#chr( 10 )#" );
					var started = variables.lm.importSubscribers(
						{
							"mode"                : "subscribe",
							"delim"               : ",",
							"lists"               : [ variables.listId ],
							"overwrite"           : false,
							"subscription_status" : "unconfirmed"
						},
						csvPath
					);
					if ( fileExists( csvPath ) ) {
						fileDelete( csvPath );
					}
					expectHit( started, "importSubscribers" );
					expectHit( variables.lm.stopImportSubscribers(), "stopImportSubscribers" );
					variables.lm.deleteSubscribersByQuery( {
						"query" : emailQuery( importEmail )
					} );
				} );
			} );

			describe( "transactional", function() {
				it( "POST /api/tx", function() {
					expectHit(
						variables.lm.sendTransactional( {
							"subscriber_email" : variables.email,
							"template_id"      : variables.txTemplateId,
							"data"             : { "name" : "Spec" },
							"content_type"     : "html"
						} ),
						"sendTransactional"
					);
				} );
			} );

			describe( "maintenance", function() {
				it( "DELETE /api/maintenance/subscribers/{type}", function() {
					expectHit( variables.lm.gcSubscribers( "orphans" ), "gcSubscribers" );
				} );

				it( "DELETE /api/maintenance/analytics/{type}", function() {
					expectHit( variables.lm.gcCampaignAnalytics( "views" ), "gcCampaignAnalytics" );
				} );

				it( "GET /api/maintenance/analytics/{type}/export", function() {
					expectHit( variables.lm.exportCampaignAnalytics( "views" ), "exportCampaignAnalytics" );
				} );

				it( "DELETE /api/maintenance/subscriptions/unconfirmed", function() {
					expectHit( variables.lm.gcUnconfirmedSubscriptions(), "gcUnconfirmedSubscriptions" );
				} );
			} );

			describe( "public", function() {
				it( "GET /api/public/lists", function() {
					expectOk( variables.lm.getPublicLists(), "getPublicLists" );
				} );

				it( "POST /api/public/subscription", function() {
					expectHit(
						variables.lm.publicSubscription( {
							"email" : "spec-pub-#variables.suffix#@example.test",
							"name"  : "Public Spec",
							"list_uuids" : [ variables.publicListUuid ]
						} ),
						"publicSubscription"
					);
				} );

				it( "GET /api/public/captcha/altcha", function() {
					expectOptional( variables.lm.getAltchaChallenge(), "getAltchaChallenge" );
				} );

				it( "GET /api/public/archive", function() {
					expectOptional( variables.lm.getCampaignArchives(), "getCampaignArchives" );
				} );
			} );

			describe( "users and roles", function() {
				it( "GET /api/profile", function() {
					expectOk( variables.lm.getProfile(), "getProfile" );
				} );

				it( "GET /api/users and GET /api/users/{id}", function() {
					var data = expectOk( variables.lm.getUsers(), "getUsers" );
					var id   = firstUserId( data );
					expect( id ).toBeGT( 0, "expected at least one user" );
					expectOk( variables.lm.getUser( id ), "getUser" );
				} );

				it( "POST /api/users, PUT /api/users/{id}, DELETE /api/users/{id}", function() {
					var created = variables.lm.createUser( {
						"username"       : "specapi#variables.suffix#",
						"name"           : "Spec API User",
						"email"          : "spec-api-#variables.suffix#@example.test",
						"type"           : "api",
						"status"         : "enabled",
						"password_login" : false,
						"user_role_id"   : 1
					} );
					var data = expectOk( created, "createUser" );
					var id   = entityId( data );
					arrayAppend( variables.created.users, id );
					expectOk(
						variables.lm.updateUser( id, {
							"username"       : "specapi#variables.suffix#",
							"name"           : "Spec API User Updated",
							"email"          : "spec-api-#variables.suffix#@example.test",
							"type"           : "api",
							"status"         : "disabled",
							"password_login" : false,
							"user_role_id"   : 1
						} ),
						"updateUser"
					);
					expectOk( variables.lm.deleteUser( id ), "deleteUser" );
					arrayDelete( variables.created.users, id );
				} );

				it( "GET /api/roles/users", function() {
					expectOk( variables.lm.getUserRoles(), "getUserRoles" );
				} );

				it( "GET /api/roles/lists", function() {
					expectOk( variables.lm.getListRoles(), "getListRoles" );
				} );

				it( "POST/PUT/DELETE user roles", function() {
					var created = variables.lm.createUserRole( {
						"name"        : "spec-role-#variables.suffix#",
						"permissions" : [ "subscribers:get_all" ]
					} );
					var data = expectOk( created, "createUserRole" );
					var id   = entityId( data );
					arrayAppend( variables.created.roles, id );
					expectOk(
						variables.lm.updateUserRole( id, {
							"name"        : "spec-role-#variables.suffix#-updated",
							"permissions" : [ "subscribers:get_all", "lists:get_all" ]
						} ),
						"updateUserRole"
					);
					expectOk( variables.lm.deleteRole( id ), "deleteRole" );
					arrayDelete( variables.created.roles, id );
				} );
			} );

			describe( "webhooks", function() {
				it( "POST /webhooks/bounce", function() {
					expectOptional(
						variables.lm.handleBounceWebhook( {
							"email"  : variables.email,
							"type"   : "hard",
							"source" : "spec"
						} ),
						"handleBounceWebhook"
					);
				} );

				it( "POST /webhooks/service/{service}", function() {
					expectOptional(
						variables.lm.handleServiceWebhook( "ses", { "Type" : "Notification" } ),
						"handleServiceWebhook"
					);
				} );
			} );

		} );
	}

	private any function expectOk( required result, string label = "" ) {
		expect( arguments.result.isOk() ).toBeTrue(
			"#arguments.label# HTTP #arguments.result.status()# #arguments.result.message()#"
		);
		return arguments.result.data();
	}

	private void function expectHit( required result, string label = "" ) {
		expect( arguments.result.status() ).toBeGT( 0, "#arguments.label# made no HTTP call" );
		expect( arguments.result.status() ).notToBe( 404, "#arguments.label# 404 #arguments.result.message()#" );
	}

	private void function expectOptional( required result, string label = "" ) {
		expect( arguments.result.status() ).toBeGT( 0, "#arguments.label# made no HTTP call" );
		expect( listFind( "200,201,202,204,400,401,403,404,405,422", arguments.result.status() ) ).toBeGT(
			0,
			"#arguments.label# unexpected HTTP #arguments.result.status()# #arguments.result.message()#"
		);
	}

	private string function emailQuery( required string email ) {
		return "subscribers.email = '#arguments.email#'";
	}

	private string function ymd( required date d ) {
		return year( arguments.d ) & "-" & numberFormat( month( arguments.d ), "00" ) & "-" & numberFormat( day( arguments.d ), "00" );
	}

	private numeric function entityId( required any data ) {
		if ( isArray( arguments.data ) && arrayLen( arguments.data ) ) {
			return val( arguments.data[ 1 ].id ?: 0 );
		}
		return variables.lm.extractIdFromData( arguments.data );
	}

	private numeric function createTempSubscriber( required string slug, string email = "" ) {
		var addr = len( arguments.email ) ? arguments.email : "spec-#arguments.slug#-#variables.suffix#@example.test";
		var data = expectOk(
			variables.lm.createSubscriber( {
				"email"                    : addr,
				"name"                     : "Spec #arguments.slug#",
				"status"                   : "enabled",
				"lists"                    : [ variables.listId ],
				"preconfirm_subscriptions" : true
			} ),
			"createTempSubscriber #arguments.slug#"
		);
		return val( data.id );
	}

	private numeric function firstUserId( required any data ) {
		if ( isArray( arguments.data ) && arrayLen( arguments.data ) ) {
			return val( arguments.data[ 1 ].id ?: 0 );
		}
		if ( isStruct( arguments.data ) && structKeyExists( arguments.data, "results" ) && isArray( arguments.data.results ) && arrayLen( arguments.data.results ) ) {
			return val( arguments.data.results[ 1 ].id ?: 0 );
		}
		return 0;
	}

	private void function cleanupEach( required array ids, required string method ) {
		for ( var id in arguments.ids ) {
			try {
				invoke( variables.lm, arguments.method, [ id ] );
			} catch ( any e ) {
			}
		}
	}

}
