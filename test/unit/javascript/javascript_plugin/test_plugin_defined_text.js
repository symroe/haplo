/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

TEST(function() {

    TEST.assert_exceptions(function() {
        O.text(O.T_TEXT_PLUGIN_DEFINED, "ping");
    }, "O.text(O.T_TEXT_PLUGIN_DEFINED,...) must be passed an Object with properties 'type' and 'value'.");

    TEST.assert_exceptions(function() {
        O.text(O.T_TEXT_PLUGIN_DEFINED, {type:"a:b"});
    }, "O.text(O.T_TEXT_PLUGIN_DEFINED,...) must be passed an Object with properties 'type' and 'value'.");

    TEST.assert_exceptions(function() {
        O.text(O.T_TEXT_PLUGIN_DEFINED, {value:"y"});
    }, "O.text(O.T_TEXT_PLUGIN_DEFINED,...) must be passed an Object with properties 'type' and 'value'.");

    TEST.assert_exceptions(function() {
        O.text(O.T_TEXT_PLUGIN_DEFINED, {type:"x", value:"v"});
    }, "Bad type for plugin defined Text object");

    var t0 = O.text(O.T_TEXT_PLUGIN_DEFINED, {type:"unknown:type", value:{a:2}});
    TEST.assert_equal("", t0.toString());
    TEST.assert_equal("", t0.toHTML());

    var t1 = O.text(O.T_TEXT_PLUGIN_DEFINED, {type:"test:testtype", value:{text:"Hello"}});
    TEST.assert_equal("Hello", t1.toString());
    TEST.assert_equal("<div><p>TEST DATA TYPE</p><p>Hello</p></div>", t1.toHTML());

    var t2 = O.text(O.T_TEXT_PLUGIN_DEFINED, {type:"test:testtype", value:'{"text":"World"}'});
    TEST.assert_equal("World", t2.toString());

    var t2fields = t2.toFields();
    TEST.assert_equal(O.T_TEXT_PLUGIN_DEFINED, t2fields.typecode);
    TEST.assert_equal("test:testtype", t2fields.type);
    TEST.assert_equal("World", t2fields.value.text);

    // Test constructor function generated by the implementTextType() function
    var t3 = test_plugin.constructTestTextType1({text:"XYZ"});
    TEST.assert_equal(O.T_TEXT_PLUGIN_DEFINED, O.typecode(t3));
    var t3fields = t3.toFields();
    TEST.assert_equal("test:testtype", t3fields.type);
    TEST.assert_equal("XYZ", t3fields.value.text);

    TEST.assert_exceptions(function() {
        test_plugin.constructTestTextType1();
    }, "A JSON compatible JavaScript object must be passed to plugin text type constructor functions.");
    TEST.assert_exceptions(function() {
        test_plugin.constructTestTextType1(1);
    }, "A JSON compatible JavaScript object must be passed to plugin text type constructor functions.");
    TEST.assert_exceptions(function() {
        test_plugin.constructTestTextType1("hello");
    }, "A JSON compatible JavaScript object must be passed to plugin text type constructor functions.");
    TEST.assert_exceptions(function() {
        test_plugin.constructTestTextType1(function() {});
    }, "A JSON compatible JavaScript object must be passed to plugin text type constructor functions.");
    // but arrays are allowed
    test_plugin.constructTestTextType1(["x"]);

});