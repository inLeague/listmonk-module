component extends="coldbox.system.testing.BaseTestCase" appMapping="/root" {

	function beforeAll() {
		super.beforeAll();
		variables.wirebox = getController().getWireBox();
	}

}
