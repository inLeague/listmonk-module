/**
 * Build process for the listmonk ColdBox module.
 * Adapt to your needs.
 */
component {

	/**
	 * Constructor
	 */
	function init() {
		variables.cwd          = getCWD().reReplace( "\.$", "" );
		variables.artifactsDir = cwd & "/.artifacts";
		variables.buildDir     = cwd & "/.tmp";
		variables.apidDocsDir  = variables.buildDir & "/apidocs";

		variables.excludes = [
			"build",
			"test-harness",
			"server-.*\.json",
			"^\..*"
		];

		[
			variables.buildDir,
			variables.artifactsDir,
			variables.apidDocsDir
		].each( function( item ) {
			if ( directoryExists( item ) ) {
				directoryDelete( item, true );
			}
			directoryCreate( item, true, true );
		} );

		return this;
	}

	/**
	 * Run the build process: source zip + DocBox API docs
	 *
	 * @projectName The project name used for resources and slugs
	 * @version     The version you are building
	 * @buildID     The build identifier
	 * @branch      The branch you are building
	 */
	function run(
		required projectName,
		version = "1.0.0",
		buildID = createUUID(),
		branch  = "development"
	) {
		fileSystemUtil.createMapping( arguments.projectName, variables.cwd );

		buildSource( argumentCollection = arguments );

		arguments.outputDir = variables.buildDir & "/apidocs";
		docs( argumentCollection = arguments );

		buildChecksums();

		print
			.line()
			.boldMagentaLine( "Build Process is done! Enjoy your build!" )
			.toConsole();
	}

	/**
	 * Build the source zip
	 *
	 * @projectName The project name used for resources and slugs
	 * @version     The version you are building
	 * @buildID     The build identifier
	 * @branch      The branch you are building
	 */
	function buildSource(
		required projectName,
		version = "1.0.0",
		buildID = createUUID(),
		branch  = "development"
	) {
		print
			.line()
			.boldMagentaLine(
				"Building #arguments.projectName# v#arguments.version#+#arguments.buildID# from #cwd# using the #arguments.branch# branch."
			)
			.toConsole();

		ensureExportDir( argumentCollection = arguments );

		variables.projectBuildDir = variables.buildDir & "/#projectName#";
		directoryCreate( variables.projectBuildDir, true, true );

		print.blueLine( "Copying source to build folder..." ).toConsole();
		copy( variables.cwd, variables.projectBuildDir );

		fileWrite(
			"#variables.projectBuildDir#/#projectName#-#version#+#buildID#",
			"Built with love on #dateTimeFormat( now(), "full" )#"
		);

		var destination = "#variables.exportsDir#/#projectName#-#version#.zip";
		print.greenLine( "Zipping code to #destination#" ).toConsole();
		cfzip(
			action    = "zip",
			file      = "#destination#",
			source    = "#variables.projectBuildDir#",
			overwrite = true,
			recurse   = true
		);

		fileCopy( "#variables.projectBuildDir#/box.json", variables.exportsDir );
	}

	/**
	 * Produce the API Docs via DocBox (models folder only)
	 *
	 * @projectName The project name
	 * @version     The version
	 * @outputDir   DocBox output directory
	 */
	function docs(
		required projectName,
		version   = "1.0.0",
		outputDir = ".tmp/apidocs"
	) {
		ensureExportDir( argumentCollection = arguments );
		fileSystemUtil.createMapping( arguments.projectName, variables.cwd );

		print.greenLine( "Generating API Docs, please wait..." ).toConsole();

		command( "docbox generate" )
			.params(
				"source"                 = "models",
				"mapping"                = "models",
				"strategy-projectTitle"  = "#arguments.projectName# v#arguments.version#",
				"strategy-outputDir"     = arguments.outputDir
			)
			.run();

		print.greenLine( "API Docs produced at #arguments.outputDir#" ).toConsole();

		var destination = "#variables.exportsDir#/#projectName#-docs-#version#.zip";
		print.greenLine( "Zipping apidocs to #destination#" ).toConsole();
		cfzip(
			action    = "zip",
			file      = "#destination#",
			source    = "#arguments.outputDir#",
			overwrite = true,
			recurse   = true
		);
	}

	/********************************************* PRIVATE HELPERS *********************************************/

	/**
	 * Build checksums for export zips
	 */
	private function buildChecksums() {
		print.greenLine( "Building checksums" ).toConsole();
		command( "checksum" )
			.params(
				path      = "#variables.exportsDir#/*.zip",
				algorithm = "SHA-512",
				extension = "sha512",
				write     = true
			)
			.run();
		command( "checksum" )
			.params(
				path      = "#variables.exportsDir#/*.zip",
				algorithm = "md5",
				extension = "md5",
				write     = true
			)
			.run();
	}

	/**
	 * Copy sources while honoring excludes
	 */
	private function copy( src, target, recurse = true ) {
		directoryList(
			src,
			false,
			"path",
			function( path ) {
				var isExcluded = false;
				variables.excludes.each( function( item ) {
					if ( path.replaceNoCase( variables.cwd, "", "all" ).reFindNoCase( item ) ) {
						isExcluded = true;
					}
				} );
				return !isExcluded;
			}
		).each( function( item ) {
			if ( fileExists( item ) ) {
				print.blueLine( "Copying #item#" ).toConsole();
				fileCopy( item, target );
			} else {
				print.greenLine( "Copying directory #item#" ).toConsole();
				directoryCopy( item, target & "/" & item.replace( src, "" ), true );
			}
		} );
	}

	/**
	 * Ensure the export directory exists at artifacts/NAME/VERSION/
	 */
	private function ensureExportDir( required projectName, version = "1.0.0" ) {
		if ( structKeyExists( variables, "exportsDir" ) && directoryExists( variables.exportsDir ) ) {
			return;
		}
		variables.exportsDir = variables.artifactsDir & "/#projectName#/#arguments.version#";
		directoryCreate( variables.exportsDir, true, true );
	}

}
