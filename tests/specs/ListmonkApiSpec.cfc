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
					var data = expectOk( variables.lm.healthCheck(), "healthCheck" );
					expect( data ).toBeTrue();
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
					var tested = variables.lm.testSMTP( smtp );
					expect( tested.status() ).toBeGT( 0, "testSMTP made no HTTP call" );
					expect( listFind( "200,400", tested.status() ) ).toBeGT(
						0,
						"testSMTP HTTP #tested.status()# #tested.message()#"
					);
				} );
			} );

			describe( "lists", function() {
				it( "GET /api/lists", function() {
					var data = expectOk(
						variables.lm.getLists( { "query" : "spec-list-#variables.suffix#" } ),
						"getLists"
					);
					expect( data.results ).toBeArray();
					expect( hasId( idsOf( data.results ), variables.listId ) ).toBeTrue(
						"fixture list #variables.listId# missing from GET /api/lists"
					);
				} );

				it( "GET /api/lists/{id}", function() {
					var data = expectOk( variables.lm.getList( variables.listId ), "getList" );
					expect( data.id ).toBe( variables.listId );
					expect( data.name ).toBe( "spec-list-#variables.suffix#" );
				} );

				it( "PUT /api/lists/{id}", function() {
					var name = "spec-list-#variables.suffix#-updated";
					var before = variables.lm.getList( variables.listId );
					expect( before.status() ).toBe( 200 );
					expect( before.data().id ).toBe( variables.listId );

					var updated = variables.lm.updateList( variables.listId, {
						"name"        : name,
						"type"        : "private",
						"optin"       : "single",
						"description" : "updated by spec"
					} );
					expect( updated.status() ).toBe( 200 );
					expect( updated.data().name ).toBe( name );
					expect( updated.data().description ).toBe( "updated by spec" );

					var after = variables.lm.getList( variables.listId );
					expect( after.status() ).toBe( 200 );
					expect( after.data().name ).toBe( name );
					expect( after.data().description ).toBe( "updated by spec" );
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
					var id = extra.id;

					var before = variables.lm.getList( id );
					expect( before.status() ).toBe( 200 );
					expect( before.data().id ).toBe( id );
					expect( before.data().name ).toBe( "spec-del-#variables.suffix#" );

					var deleted = variables.lm.deleteList( id );
					expect( deleted.status() ).toBe( 200 );
					expect( deleted.data() ).toBeTrue();

					expectGone( variables.lm.getList( id ), "List" );
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
					expect( variables.lm.getList( a.id ).status() ).toBe( 200 );
					expect( variables.lm.getList( b.id ).status() ).toBe( 200 );

					var deleted = variables.lm.deleteLists( ids = [ a.id, b.id ] );
					expect( deleted.status() ).toBe( 200 );
					expect( deleted.data() ).toBeTrue();

					expectGone( variables.lm.getList( a.id ), "List" );
					expectGone( variables.lm.getList( b.id ), "List" );
				} );
			} );

			describe( "subscribers", function() {
				it( "GET /api/subscribers", function() {
					var data = expectOk(
						variables.lm.getSubscribers( { "query" : emailQuery( variables.email ) } ),
						"getSubscribers"
					);
					expect( data.results ).toBeArray();
					expect( hasId( idsOf( data.results ), variables.subscriberId ) ).toBeTrue(
						"fixture subscriber #variables.subscriberId# missing from GET /api/subscribers"
					);
				} );

				it( "GET /api/subscribers/{id}", function() {
					var data = expectOk( variables.lm.getSubscriber( variables.subscriberId ), "getSubscriber" );
					expect( data.id ).toBe( variables.subscriberId );
					expect( data.email ).toBe( variables.email );
					expect( data.status ).toBe( "enabled" );
				} );

				it( "PUT /api/subscribers/{id}", function() {
					var extra = createTempSubscriber( "put" );
					var email = "spec-put-#variables.suffix#@example.test";
					var before = variables.lm.getSubscriber( extra );
					expect( before.status() ).toBe( 200 );
					expect( before.data().name ).toBe( "Spec put" );

					var updated = variables.lm.updateSubscriber( extra, {
						"email"  : email,
						"name"   : "Spec Subscriber Updated",
						"status" : "enabled",
						"lists"  : [ variables.listId ]
					} );
					expect( updated.status() ).toBe( 200 );
					expect( updated.data().name ).toBe( "Spec Subscriber Updated" );

					var after = variables.lm.getSubscriber( extra );
					expect( after.status() ).toBe( 200 );
					expect( after.data().id ).toBe( extra );
					expect( after.data().email ).toBe( email );
					expect( after.data().name ).toBe( "Spec Subscriber Updated" );
				} );

				it( "PATCH /api/subscribers/{id}", function() {
					var extra = createTempSubscriber( "patch" );
					var before = variables.lm.getSubscriber( extra );
					expect( before.status() ).toBe( 200 );
					expect( before.data().name ).toBe( "Spec patch" );

					var patched = variables.lm.patchSubscriber( extra, { "name" : "Spec Subscriber Patched" } );
					expect( patched.status() ).toBe( 200 );
					expect( patched.data().name ).toBe( "Spec Subscriber Patched" );

					var after = variables.lm.getSubscriber( extra );
					expect( after.status() ).toBe( 200 );
					expect( after.data().name ).toBe( "Spec Subscriber Patched" );
				} );

				it( "GET /api/subscribers/{id}/activity", function() {
					expectOk( variables.lm.getSubscriberActivity( variables.subscriberId ), "getSubscriberActivity" );
				} );

				it( "GET /api/subscribers/{id}/export", function() {
					expectOk( variables.lm.exportSubscriberData( variables.subscriberId ), "exportSubscriberData" );
				} );

				it( "GET /api/subscribers/{id}/bounces", function() {
					var data = expectOk( variables.lm.getSubscriberBounces( variables.subscriberId ), "getSubscriberBounces" );
					expect( arrayLen( collectionResults( data ) ) ).toBe( 0 );
				} );

				it( "DELETE /api/subscribers/{id}/bounces", function() {
					var before = expectOk(
						variables.lm.getSubscriberBounces( variables.subscriberId ),
						"getSubscriberBounces before delete"
					);
					expect( arrayLen( collectionResults( before ) ) ).toBe( 0 );

					var deleted = variables.lm.deleteSubscriberBounces( variables.subscriberId );
					expect( deleted.status() ).toBe( 200 );
					expect( deleted.data() ).toBeTrue();

					var after = expectOk(
						variables.lm.getSubscriberBounces( variables.subscriberId ),
						"getSubscriberBounces after delete"
					);
					expect( arrayLen( collectionResults( after ) ) ).toBe( 0 );
				} );

				it( "POST /api/subscribers/{id}/optin", function() {
					expectOk( variables.lm.sendOptin( variables.subscriberId ), "sendOptin" );
				} );

				it( "PUT /api/subscribers/lists", function() {
					var extra = createTempSubscriber( "lists-add" );
					var before = variables.lm.getSubscriber( extra );
					expect( before.status() ).toBe( 200 );
					expect( hasId( subscriberListIds( before.data() ), variables.publicListId ) ).toBeFalse();

					var changed = variables.lm.manageSubscriberLists( {
						"ids"             : [ extra ],
						"action"          : "add",
						"target_list_ids" : [ variables.publicListId ],
						"status"          : "confirmed"
					} );
					expect( changed.status() ).toBe( 200 );
					expect( changed.data() ).toBeTrue();

					var after = variables.lm.getSubscriber( extra );
					expect( after.status() ).toBe( 200 );
					expect( hasId( subscriberListIds( after.data() ), variables.publicListId ) ).toBeTrue();
				} );

				it( "PUT /api/subscribers/lists/{id}", function() {
					var extra = createTempSubscriber( "lists-by-id" );
					var before = variables.lm.getSubscriber( extra );
					expect( before.status() ).toBe( 200 );
					expect( hasId( subscriberListIds( before.data() ), variables.publicListId ) ).toBeFalse();

					var changed = variables.lm.manageSubscriberListsByList(
						extra,
						{
							"ids"             : [ extra ],
							"action"          : "add",
							"target_list_ids" : [ variables.publicListId ],
							"status"          : "confirmed"
						}
					);
					expect( changed.status() ).toBe( 200 );
					expect( changed.data() ).toBeTrue();

					var after = variables.lm.getSubscriber( extra );
					expect( after.status() ).toBe( 200 );
					expect( hasId( subscriberListIds( after.data() ), variables.publicListId ) ).toBeTrue();
				} );

				it( "PUT /api/subscribers/query/lists", function() {
					var extraEmail = "spec-lists-q-#variables.suffix#@example.test";
					var extra = createTempSubscriber( "lists-q", extraEmail );
					var before = variables.lm.getSubscriber( extra );
					expect( before.status() ).toBe( 200 );
					expect( hasId( subscriberListIds( before.data() ), variables.publicListId ) ).toBeFalse();

					var changed = variables.lm.manageSubscriberListsByQuery( {
						"query"           : emailQuery( extraEmail ),
						"action"          : "add",
						"target_list_ids" : [ variables.publicListId ],
						"status"          : "confirmed"
					} );
					expect( changed.status() ).toBe( 200 );
					expect( changed.data() ).toBeTrue();

					var after = variables.lm.getSubscriber( extra );
					expect( after.status() ).toBe( 200 );
					expect( hasId( subscriberListIds( after.data() ), variables.publicListId ) ).toBeTrue();
				} );

				it( "PUT /api/subscribers/{id}/blocklist", function() {
					var extra = createTempSubscriber( "block-one" );
					var before = variables.lm.getSubscriber( extra );
					expect( before.status() ).toBe( 200 );
					expect( before.data().status ).toBe( "enabled" );

					var blocked = variables.lm.blocklistSubscriber( extra );
					expect( blocked.status() ).toBe( 200 );
					expect( blocked.data() ).toBeTrue();

					var after = variables.lm.getSubscriber( extra );
					expect( after.status() ).toBe( 200 );
					expect( after.data().status ).toBe( "blocklisted" );
				} );

				it( "PUT /api/subscribers/blocklist", function() {
					var extra = createTempSubscriber( "block-bulk" );
					var before = variables.lm.getSubscriber( extra );
					expect( before.status() ).toBe( 200 );
					expect( before.data().status ).toBe( "enabled" );

					var blocked = variables.lm.blocklistSubscribers( { "ids" : [ extra ] } );
					expect( blocked.status() ).toBe( 200 );
					expect( blocked.data() ).toBeTrue();

					var after = variables.lm.getSubscriber( extra );
					expect( after.status() ).toBe( 200 );
					expect( after.data().status ).toBe( "blocklisted" );
				} );

				it( "PUT /api/subscribers/query/blocklist", function() {
					var extraEmail = "spec-qblock-#variables.suffix#@example.test";
					var extra = createTempSubscriber( "qblock", extraEmail );
					var before = variables.lm.getSubscriber( extra );
					expect( before.status() ).toBe( 200 );
					expect( before.data().status ).toBe( "enabled" );

					var blocked = variables.lm.blocklistSubscribersByQuery( {
						"query" : emailQuery( extraEmail )
					} );
					expect( blocked.status() ).toBe( 200 );
					expect( blocked.data() ).toBeTrue();

					var after = variables.lm.getSubscriber( extra );
					expect( after.status() ).toBe( 200 );
					expect( after.data().status ).toBe( "blocklisted" );
				} );

				it( "GET /api/subscribers/export", function() {
					var result = variables.lm.exportSubscribers( { "per_page" : "all" } );
					expect( result.status() ).toBe( 200, "exportSubscribers HTTP #result.status()# #result.message()#" );
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

					expectGone( variables.lm.getSubscriber( extra ), "Subscriber", extra );
				} );

				it( "DELETE /api/subscribers", function() {
					var a = createTempSubscriber( "del-a" );
					var b = createTempSubscriber( "del-b" );
					expect( variables.lm.getSubscriber( a ).status() ).toBe( 200 );
					expect( variables.lm.getSubscriber( b ).status() ).toBe( 200 );

					var deleted = variables.lm.bulkDeleteSubscribers( [ a, b ] );
					expect( deleted.status() ).toBe( 200 );
					expect( deleted.data() ).toBeTrue();

					expectGone( variables.lm.getSubscriber( a ), "Subscriber", a );
					expectGone( variables.lm.getSubscriber( b ), "Subscriber", b );
				} );

				it( "POST /api/subscribers/query/delete", function() {
					var extraEmail = "spec-qdel-#variables.suffix#@example.test";
					var extra = createTempSubscriber( "qdel", extraEmail );
					expect( variables.lm.getSubscriber( extra ).status() ).toBe( 200 );
					expect( findSubscriberByEmail( extraEmail ).id ).toBe( extra );

					var deleted = variables.lm.deleteSubscribersByQuery( {
						"query" : emailQuery( extraEmail )
					} );
					expect( deleted.status() ).toBe( 200 );
					expect( deleted.data() ).toBeTrue();

					expectGone( variables.lm.getSubscriber( extra ), "Subscriber", extra );
					expect( structIsEmpty( findSubscriberByEmail( extraEmail ) ) ).toBeTrue();
				} );
			} );

			describe( "templates", function() {
				it( "GET /api/templates", function() {
					var data = expectOk( variables.lm.getTemplates(), "getTemplates" );
					expect( hasId( idsOf( collectionResults( data ) ), variables.specCampaignTemplateId ) ).toBeTrue(
						"fixture template #variables.specCampaignTemplateId# missing from GET /api/templates"
					);
				} );

				it( "GET /api/templates/{id}", function() {
					var data = expectOk( variables.lm.getTemplate( variables.specCampaignTemplateId ), "getTemplate" );
					expect( entityId( data ) ).toBe( variables.specCampaignTemplateId );
				} );

				it( "PUT /api/templates/{id}", function() {
					var name = "spec-campaign-tpl-#variables.suffix#-updated";
					var before = variables.lm.getTemplate( variables.specCampaignTemplateId );
					expect( before.status() ).toBe( 200 );

					var updated = variables.lm.updateTemplate( variables.specCampaignTemplateId, {
						"name" : name,
						"type" : "campaign",
						"body" : '{{ template "content" . }}'
					} );
					expect( updated.status() ).toBe( 200 );
					expect( updated.data().name ).toBe( name );

					var after = variables.lm.getTemplate( variables.specCampaignTemplateId );
					expect( after.status() ).toBe( 200 );
					expect( after.data().name ).toBe( name );
				} );

				it( "GET /api/templates/{id}/preview", function() {
					var result = variables.lm.previewTemplateById( variables.specCampaignTemplateId );
					expect( result.status() ).toBe( 200, "previewTemplateById HTTP #result.status()# #result.message()#" );
				} );

				it( "POST /api/templates/preview", function() {
					var result = variables.lm.previewTemplate( {
						"template_type" : "campaign",
						"body"          : '{{ template "content" . }}'
					} );
					expect( result.status() ).toBe( 400, "previewTemplate HTTP #result.status()# #result.message()#" );
					expect( result.message() ).toBe(
						'The placeholder {{ template "content" . }} should appear exactly once in the template.'
					);
				} );

				it( "PUT /api/templates/{id}/default", function() {
					var setDefault = variables.lm.setDefaultTemplate( variables.specCampaignTemplateId );
					expect( setDefault.status() ).toBe( 200 );
					expect( setDefault.data() ).toBeTrue();

					var after = variables.lm.getTemplate( variables.specCampaignTemplateId );
					expect( after.status() ).toBe( 200 );
					expect( after.data().is_default ).toBeTrue();

					if ( variables.defaultTemplateId && variables.defaultTemplateId != variables.specCampaignTemplateId ) {
						var restored = variables.lm.setDefaultTemplate( variables.defaultTemplateId );
						expect( restored.status() ).toBe( 200 );
						expect( restored.data() ).toBeTrue();

						var original = variables.lm.getTemplate( variables.defaultTemplateId );
						expect( original.status() ).toBe( 200 );
						expect( original.data().is_default ).toBeTrue();

						var specTpl = variables.lm.getTemplate( variables.specCampaignTemplateId );
						expect( specTpl.status() ).toBe( 200 );
						expect( specTpl.data().is_default ).toBeFalse();
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
					var id = entityId( extra );

					var before = variables.lm.getTemplate( id );
					expect( before.status() ).toBe( 200 );
					expect( entityId( before.data() ) ).toBe( id );

					var deleted = variables.lm.deleteTemplate( id );
					expect( deleted.status() ).toBe( 200 );
					expect( deleted.data() ).toBeTrue();

					expectGone( variables.lm.getTemplate( id ), "Template" );
				} );
			} );

			describe( "campaigns", function() {
				it( "GET /api/campaigns", function() {
					var data = expectOk(
						variables.lm.getCampaigns( { "query" : "spec-campaign-#variables.suffix#" } ),
						"getCampaigns"
					);
					expect( data.results ).toBeArray();
					expect( hasId( idsOf( data.results ), variables.campaignId ) ).toBeTrue(
						"fixture campaign #variables.campaignId# missing from GET /api/campaigns"
					);
				} );

				it( "GET /api/campaigns/{id}", function() {
					var data = expectOk( variables.lm.getCampaign( variables.campaignId ), "getCampaign" );
					expect( data.id ).toBe( variables.campaignId );
					expect( data.status ).toBe( "draft" );
				} );

				it( "PUT /api/campaigns/{id}", function() {
					var name = "spec-campaign-#variables.suffix#-updated";
					var current = expectOk( variables.lm.getCampaign( variables.campaignId ), "getCampaign before put" );
					expect( current.id ).toBe( variables.campaignId );

					var updated = variables.lm.updateCampaign( variables.campaignId, {
						"name"         : name,
						"subject"      : current.subject,
						"lists"        : [ variables.listId ],
						"type"         : "regular",
						"content_type" : "html",
						"body"         : current.body ?: "<p>updated</p>",
						"messenger"    : "email",
						"template_id"  : variables.campaignTemplateId,
						"tags"         : [ "spec" ]
					} );
					expect( updated.status() ).toBe( 200 );
					expect( updated.data().name ).toBe( name );

					var after = variables.lm.getCampaign( variables.campaignId );
					expect( after.status() ).toBe( 200 );
					expect( after.data().name ).toBe( name );
				} );

				it( "GET /api/campaigns/{id}/preview", function() {
					var result = variables.lm.previewCampaign( variables.campaignId );
					expect( result.status() ).toBe( 200, "previewCampaign HTTP #result.status()# #result.message()#" );
				} );

				it( "POST /api/campaigns/{id}/preview", function() {
					var result = variables.lm.previewCampaignBody( variables.campaignId, {
						"body"         : "<p>preview body</p>",
						"content_type" : "html",
						"template_id"  : variables.campaignTemplateId
					} );
					expect( result.status() ).toBe( 200, "previewCampaignBody HTTP #result.status()# #result.message()#" );
				} );

				it( "POST /api/campaigns/{id}/preview/archive", function() {
					expectHit(
						variables.lm.previewCampaignArchive( variables.campaignId, { "archive" : true } ),
						"previewCampaignArchive"
					);
				} );

				it( "POST /api/campaigns/{id}/text", function() {
					var result = variables.lm.previewCampaignText( variables.campaignId );
					expect( result.status() ).toBe( 200, "previewCampaignText HTTP #result.status()# #result.message()#" );
				} );

				it( "POST /api/campaigns/{id}/content", function() {
					var converted = variables.lm.setCampaignContent( variables.campaignId, {
						"from" : "markdown",
						"to"   : "html",
						"body" : "**replaced content**"
					} );
					expect( converted.status() ).toBe( 200, "setCampaignContent HTTP #converted.status()# #converted.message()#" );
					expect( converted.data() ).toInclude( "replaced content" );
				} );

				it( "PUT /api/campaigns/{id}/archive", function() {
					var slug = "spec-#variables.suffix#";
					var archived = variables.lm.updateCampaignArchive( variables.campaignId, {
						"archive"             : true,
						"archive_template_id" : variables.campaignTemplateId,
						"archive_slug"        : slug
					} );
					expect( archived.status() ).toBe( 200 );

					var after = variables.lm.getCampaign( variables.campaignId );
					expect( after.status() ).toBe( 200 );
					expect( after.data().archive ).toBeTrue();
					expect( after.data().archive_slug ).toBe( slug );
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
					var extra = expectOk(
						variables.lm.createCampaign( {
							"name"         : "spec-camp-status-#variables.suffix#",
							"subject"      : "status me",
							"lists"        : [ variables.listId ],
							"type"         : "regular",
							"content_type" : "html",
							"body"         : "<p>status</p>",
							"messenger"    : "email",
							"template_id"  : variables.campaignTemplateId,
							"send_at"      : ymd( dateAdd( "d", 1, now() ) ) & "T12:00:00Z"
						} ),
						"createCampaign for status"
					);
					arrayAppend( variables.created.campaigns, extra.id );
					expect( extra.status ).toBe( "draft" );

					var scheduled = variables.lm.updateCampaignStatus( extra.id, { "status" : "scheduled" } );
					expect( scheduled.status() ).toBe( 200, "updateCampaignStatus scheduled HTTP #scheduled.status()# #scheduled.message()#" );

					var afterSched = variables.lm.getCampaign( extra.id );
					expect( afterSched.status() ).toBe( 200 );
					expect( afterSched.data().status ).toBe( "scheduled" );

					var drafted = variables.lm.updateCampaignStatus( extra.id, { "status" : "draft" } );
					expect( drafted.status() ).toBe( 200, "updateCampaignStatus draft HTTP #drafted.status()# #drafted.message()#" );

					var afterDraft = variables.lm.getCampaign( extra.id );
					expect( afterDraft.status() ).toBe( 200 );
					expect( afterDraft.data().status ).toBe( "draft" );
				} );

				it( "POST /api/campaigns/{id}/test", function() {
					var result = variables.lm.testCampaign( variables.campaignId, {
						"subscribers"  : [ variables.email ],
						"template_id"  : variables.campaignTemplateId,
						"content_type" : "html",
						"body"         : "<p>test</p>",
						"subject"      : "test",
						"lists"        : [ variables.listId ],
						"name"         : "spec-test",
						"type"         : "regular",
						"messenger"    : "email"
					} );
					expect( result.status() ).toBe( 200, "testCampaign HTTP #result.status()# #result.message()#" );
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
					var id = extra.id;

					var before = variables.lm.getCampaign( id );
					expect( before.status() ).toBe( 200 );
					expect( before.data().id ).toBe( id );

					var deleted = variables.lm.deleteCampaign( id );
					expect( deleted.status() ).toBe( 200 );
					expect( deleted.data() ).toBeTrue();

					expectGone( variables.lm.getCampaign( id ), "Campaign" );
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
					expect( variables.lm.getCampaign( extra.id ).status() ).toBe( 200 );

					var deleted = variables.lm.deleteCampaigns( { "id" : [ extra.id ] } );
					expect( deleted.status() ).toBe( 200 );
					expect( deleted.data() ).toBeTrue();

					expectGone( variables.lm.getCampaign( extra.id ), "Campaign" );
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
					expect( uploaded.status() ).toBe( 200, "uploadMedia HTTP #uploaded.status()# #uploaded.message()#" );
					var id = entityId( uploaded.data() );
					expect( id ).toBeGT( 0 );
					arrayAppend( variables.created.media, id );

					var got = variables.lm.getMediaById( id );
					expect( got.status() ).toBe( 200 );
					expect( entityId( got.data() ) ).toBe( id );

					var listed = expectOk( variables.lm.getMedia(), "getMedia after upload" );
					expect( hasId( idsOf( collectionResults( listed ) ), id ) ).toBeTrue(
						"uploaded media #id# missing from GET /api/media"
					);

					var deleted = variables.lm.deleteMedia( id );
					expect( deleted.status() ).toBe( 200 );
					expect( deleted.data() ).toBeTrue();
					arrayDelete( variables.created.media, id );

					expectGone( variables.lm.getMediaById( id ), "Media" );
				} );
			} );

			describe( "bounces", function() {
				it( "GET /api/bounces", function() {
					var data = expectOk( variables.lm.getBounces(), "getBounces" );
					expect( isStruct( data ) || isArray( data ) ).toBeTrue();
				} );

				it( "GET /api/bounces/{id} (400 when missing)", function() {
					var listed = expectOk( variables.lm.getBounces( { "per_page" : 1 } ), "getBounces for id" );
					var rows   = collectionResults( listed );
					if ( arrayLen( rows ) ) {
						var id = rows[ 1 ].id;
						var got = variables.lm.getBounce( id );
						expect( got.status() ).toBe( 200 );
						expect( got.data().id ).toBe( id );
					} else {
						expectGone( variables.lm.getBounce( 999999 ), "Bounce" );
					}
				} );

				it( "PUT /api/bounces/blocklist", function() {
					var blocked = variables.lm.blocklistBouncedSubscribers();
					expect( blocked.status() ).toBe( 200, "blocklistBouncedSubscribers HTTP #blocked.status()# #blocked.message()#" );
				} );

				it( "DELETE /api/bounces", function() {
					var deleted = variables.lm.deleteBounces( { "all" : true } );
					expect( deleted.status() ).toBe( 200, "deleteBounces HTTP #deleted.status()# #deleted.message()#" );

					var after = expectOk( variables.lm.getBounces( { "per_page" : "all" } ), "getBounces after delete all" );
					expect( arrayLen( collectionResults( after ) ) ).toBe( 0 );
				} );
			} );

			describe( "import", function() {
				it( "GET /api/import/subscribers", function() {
					expectOk( variables.lm.getImportSubscribers(), "getImportSubscribers" );
				} );

				it( "GET /api/import/subscribers/logs", function() {
					var result = variables.lm.getImportSubscriberLogs();
					expect( result.status() ).toBe( 200, "getImportSubscriberLogs HTTP #result.status()# #result.message()#" );
				} );

				it( "POST /api/import/subscribers", function() {
					var csvPath     = getTempDirectory() & "spec-import-#variables.suffix#.csv";
					var importEmail = "spec-import-#variables.suffix#@example.test";
					fileWrite( csvPath, "email,name#chr( 10 )##importEmail#,Import User#chr( 10 )#" );
					var started = variables.lm.importSubscribers(
						{
							"mode"                : "subscribe",
							"delim"               : ",",
							"lists"               : [ variables.listId ],
							"overwrite"           : false,
							"subscription_status" : "confirmed"
						},
						csvPath
					);
					if ( fileExists( csvPath ) ) {
						fileDelete( csvPath );
					}
					expect( started.status() ).toBe( 200, "importSubscribers HTTP #started.status()# #started.message()#" );

					var found = {};
					for ( var i = 1; i <= 40; i++ ) {
						found = findSubscriberByEmail( importEmail );
						if ( !structIsEmpty( found ) ) {
							break;
						}
						sleep( 250 );
					}
					expect( found.email ?: "" ).toBe( importEmail );
					expect( found.name ).toBe( "Import User" );
					arrayAppend( variables.created.subscribers, val( found.id ) );
				} );
			} );

			describe( "transactional", function() {
				it( "POST /api/tx", function() {
					var sent = variables.lm.sendTransactional( {
						"subscriber_email" : variables.email,
						"template_id"      : variables.txTemplateId,
						"data"             : { "name" : "Spec" },
						"content_type"     : "html"
					} );
					expect( sent.status() ).toBe( 200, "sendTransactional HTTP #sent.status()# #sent.message()#" );
					expect( sent.data() ).toBeTrue();
				} );
			} );

			describe( "maintenance", function() {
				it( "DELETE /api/maintenance/subscribers/{type}", function() {
					var extra = expectOk(
						variables.lm.createSubscriber( {
							"email"                    : "spec-orphan-#variables.suffix#@example.test",
							"name"                     : "Spec orphan",
							"status"                   : "enabled",
							"lists"                    : [],
							"preconfirm_subscriptions" : true
						} ),
						"create orphan subscriber"
					);
					var id = val( extra.id );
					arrayAppend( variables.created.subscribers, id );
					expect( variables.lm.getSubscriber( id ).status() ).toBe( 200 );

					var gc = variables.lm.gcSubscribers( "orphan" );
					expect( gc.status() ).toBe( 200, "gcSubscribers HTTP #gc.status()# #gc.message()#" );

					expectGone( variables.lm.getSubscriber( id ), "Subscriber", id );
				} );

				it( "DELETE /api/maintenance/analytics/{type}", function() {
					var gc = variables.lm.gcCampaignAnalytics( "views", {
						"before_date" : ymd( dateAdd( "d", 1, now() ) ) & "T00:00:00Z"
					} );
					expect( gc.status() ).toBe( 200, "gcCampaignAnalytics HTTP #gc.status()# #gc.message()#" );
				} );

				it( "GET /api/maintenance/analytics/{type}/export", function() {
					var result = variables.lm.exportCampaignAnalytics( "views", {
						"since" : ymd( dateAdd( "d", -30, now() ) ) & "T00:00:00Z"
					} );
					expect( result.status() ).toBe( 200, "exportCampaignAnalytics HTTP #result.status()# #result.message()#" );
				} );

				it( "DELETE /api/maintenance/subscriptions/unconfirmed", function() {
					var dbl = expectOk(
						variables.lm.createList( {
							"name"  : "spec-double-#variables.suffix#",
							"type"  : "private",
							"optin" : "double"
						} ),
						"createList double optin"
					);
					arrayAppend( variables.created.lists, dbl.id );
					var extra = createTempSubscriber( "unconf" );

					var added = variables.lm.manageSubscriberLists( {
						"ids"             : [ extra ],
						"action"          : "add",
						"target_list_ids" : [ dbl.id ],
						"status"          : "unconfirmed"
					} );
					expect( added.status() ).toBe( 200 );

					var before = variables.lm.getSubscriber( extra );
					expect( before.status() ).toBe( 200 );
					expect( hasId( subscriberListIds( before.data() ), dbl.id ) ).toBeTrue();

					var gc = variables.lm.gcUnconfirmedSubscriptions( {
						"before_date" : ymd( dateAdd( "d", 1, now() ) ) & "T00:00:00Z"
					} );
					expect( gc.status() ).toBe( 200, "gcUnconfirmedSubscriptions HTTP #gc.status()# #gc.message()#" );

					var after = variables.lm.getSubscriber( extra );
					expect( after.status() ).toBe( 200 );
					expect( hasId( subscriberListIds( after.data() ), dbl.id ) ).toBeFalse(
						"unconfirmed subscription on list #dbl.id# should have been garbage-collected"
					);
				} );
			} );

			describe( "public", function() {
				it( "GET /api/public/lists", function() {
					var data = expectOk( variables.lm.getPublicLists(), "getPublicLists" );
					var found = false;
					for ( var l in collectionResults( data ) ) {
						if ( ( l.uuid ?: "" ) == variables.publicListUuid ) {
							found = true;
							break;
						}
					}
					expect( found ).toBeTrue(
						"fixture public list uuid #variables.publicListUuid# missing from GET /api/public/lists"
					);
				} );

				it( "POST /api/public/subscription", function() {
					var email = "spec-pub-#variables.suffix#@example.test";
					expect( structIsEmpty( findSubscriberByEmail( email ) ) ).toBeTrue();

					var subscribed = variables.lm.publicSubscription( {
						"email"      : email,
						"name"       : "Public Spec",
						"list_uuids" : [ variables.publicListUuid ]
					} );
					expect( subscribed.status() ).toBe( 200, "publicSubscription HTTP #subscribed.status()# #subscribed.message()#" );

					var found = findSubscriberByEmail( email );
					expect( found.email ?: "" ).toBe( email );
					expect( found.name ).toBe( "Public Spec" );
					expect( hasId( subscriberListIds( found ), variables.publicListId ) ).toBeTrue();
					arrayAppend( variables.created.subscribers, val( found.id ) );
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
					var username = "specapi#variables.suffix#";
					var email    = "spec-api-#variables.suffix#@example.test";
					var created  = variables.lm.createUser( {
						"username"       : username,
						"name"           : "Spec API User",
						"email"          : email,
						"type"           : "api",
						"status"         : "enabled",
						"password_login" : false,
						"user_role_id"   : 1
					} );
					expect( created.status() ).toBe( 200, "createUser HTTP #created.status()# #created.message()#" );
					var id = entityId( created.data() );
					arrayAppend( variables.created.users, id );

					var got = variables.lm.getUser( id );
					expect( got.status() ).toBe( 200 );
					expect( got.data().id ).toBe( id );
					expect( got.data().username ).toBe( username );
					expect( got.data().name ).toBe( "Spec API User" );
					expect( got.data().status ).toBe( "enabled" );

					var updated = variables.lm.updateUser( id, {
						"username"       : username,
						"name"           : "Spec API User Updated",
						"email"          : email,
						"type"           : "api",
						"status"         : "disabled",
						"password_login" : false,
						"user_role_id"   : 1
					} );
					expect( updated.status() ).toBe( 200 );
					expect( updated.data().name ).toBe( "Spec API User Updated" );
					expect( updated.data().status ).toBe( "disabled" );

					var after = variables.lm.getUser( id );
					expect( after.status() ).toBe( 200 );
					expect( after.data().name ).toBe( "Spec API User Updated" );
					expect( after.data().status ).toBe( "disabled" );

					var deleted = variables.lm.deleteUser( id );
					expect( deleted.status() ).toBe( 200 );
					expect( deleted.data() ).toBeTrue();
					arrayDelete( variables.created.users, id );

					expectGone( variables.lm.getUser( id ), "User" );
				} );

				it( "GET /api/roles/users", function() {
					expectOk( variables.lm.getUserRoles(), "getUserRoles" );
				} );

				it( "GET /api/roles/lists", function() {
					expectOk( variables.lm.getListRoles(), "getListRoles" );
				} );

				it( "POST/PUT/DELETE user roles", function() {
					var name = "spec-role-#variables.suffix#";
					var created = variables.lm.createUserRole( {
						"name"        : name,
						"permissions" : [ "subscribers:get_all" ]
					} );
					expect( created.status() ).toBe( 200, "createUserRole HTTP #created.status()# #created.message()#" );
					var id = entityId( created.data() );
					arrayAppend( variables.created.roles, id );

					var listed = expectOk( variables.lm.getUserRoles(), "getUserRoles after create" );
					expect( hasId( idsOf( collectionResults( listed ) ), id ) ).toBeTrue();

					var updatedName = "#name#-updated";
					var updated = variables.lm.updateUserRole( id, {
						"name"        : updatedName,
						"permissions" : [ "subscribers:get_all", "lists:get_all" ]
					} );
					expect( updated.status() ).toBe( 200 );
					expect( updated.data().name ).toBe( updatedName );

					var after = expectOk( variables.lm.getUserRoles(), "getUserRoles after update" );
					var found = {};
					for ( var role in collectionResults( after ) ) {
						if ( val( role.id ) == id ) {
							found = role;
							break;
						}
					}
					expect( found.name ?: "" ).toBe( updatedName );

					var deleted = variables.lm.deleteRole( id );
					expect( deleted.status() ).toBe( 200 );
					expect( deleted.data() ).toBeTrue();
					arrayDelete( variables.created.roles, id );

					var remaining = expectOk( variables.lm.getUserRoles(), "getUserRoles after delete" );
					expect( hasId( idsOf( collectionResults( remaining ) ), id ) ).toBeFalse();
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
		expect( arguments.result.status() ).toBe(
			200,
			"#arguments.label# HTTP #arguments.result.status()# #arguments.result.message()#"
		);
		return arguments.result.data();
	}

	private void function expectGone( required result, required string term, numeric id = 0 ) {
		var code = listFindNoCase( "media,user", arguments.term ) ? 404 : 400;
		var msg  = "";
		if ( lCase( arguments.term ) == "subscriber" ) {
			msg = "Subscriber (#arguments.id#: ) not found";
		} else if ( lCase( arguments.term ) == "media" ) {
			msg = "not found";
		} else {
			msg = "#arguments.term# not found";
		}
		expect( arguments.result.status() ).toBe(
			code,
			"expected #code# for missing #arguments.term#, got #arguments.result.status()# #arguments.result.message()#"
		);
		expect( arguments.result.message() ).toBe( msg );
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

	private array function collectionResults( required any data ) {
		if ( isArray( arguments.data ) ) {
			return arguments.data;
		}
		if ( isStruct( arguments.data ) && structKeyExists( arguments.data, "results" ) && isArray( arguments.data.results ) ) {
			return arguments.data.results;
		}
		return [];
	}

	private array function idsOf( required any items ) {
		var ids  = [];
		var rows = isArray( arguments.items ) ? arguments.items : [];
		for ( var item in rows ) {
			if ( isStruct( item ) && structKeyExists( item, "id" ) ) {
				arrayAppend( ids, val( item.id ) );
			}
		}
		return ids;
	}

	private boolean function hasId( required array ids, required numeric id ) {
		return arrayFind( arguments.ids, arguments.id ) > 0;
	}

	private array function subscriberListIds( required struct sub ) {
		return idsOf( arguments.sub.lists ?: [] );
	}

	private struct function findSubscriberByEmail( required string email ) {
		var data = expectOk(
			variables.lm.getSubscribers( { "query" : emailQuery( arguments.email ) } ),
			"getSubscribers #arguments.email#"
		);
		for ( var row in collectionResults( data ) ) {
			if ( ( row.email ?: "" ) == arguments.email ) {
				return row;
			}
		}
		return {};
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

	private numeric function createTempSubscriber(
		required string slug,
		string email = "",
		array lists  = []
	) {
		var addr = len( arguments.email ) ? arguments.email : "spec-#arguments.slug#-#variables.suffix#@example.test";
		var listIds = arrayLen( arguments.lists ) ? arguments.lists : [ variables.listId ];
		var data = expectOk(
			variables.lm.createSubscriber( {
				"email"                    : addr,
				"name"                     : "Spec #arguments.slug#",
				"status"                   : "enabled",
				"lists"                    : listIds,
				"preconfirm_subscriptions" : true
			} ),
			"createTempSubscriber #arguments.slug#"
		);
		var id = val( data.id );
		arrayAppend( variables.created.subscribers, id );
		return id;
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
