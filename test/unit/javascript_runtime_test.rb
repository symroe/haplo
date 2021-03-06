# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class JavascriptRuntimeTest < Test::Unit::TestCase
  include JavaScriptTestHelper

  # ===============================================================================================

  def test_handlebars_js_has_been_modified_for_oneis
    File.open("#{KFRAMEWORK_ROOT}/lib/javascript/thirdparty/handlebars.js") do |f|
      source = f.read
      # Got the topping and tailing?
      assert source =~ /BEGIN ONEIS MODIFICATION/
      # Is it the forked version which does sealing?
      assert source.include?('Handlebars.HbParser')
      # Is it the forked version which allowes : in IDs?
      assert source.include?('[a-zA-Z0-9_$:-]+')
      # Is it the forked version which moves the context for partials?
      assert source.include?('If there exists a property matching the name of the partial')
    end
  end

  # ===============================================================================================

  def test_underscore_string
    # Make sure the underscore.string.js file has modifications to work in the sealed runtime
    File.open("#{KFRAMEWORK_ROOT}/lib/javascript/thirdparty/underscore.string.js") do |f|
      mustache = f.read
      assert mustache =~ /BEGIN ONEIS MODIFICATION/
    end
    # Make sure the underscore.string.js library is loaded and part of underscore
    run_javascript_test(:file, 'unit/javascript/javascript_runtime/test_underscore_string.js')
  end

  # ===============================================================================================

  def test_o_ref
    run_javascript_test(:file, 'unit/javascript/javascript_runtime/test_o_ref.js')
  end

  # ===============================================================================================

  def test_permissions
    restore_store_snapshot("basic")
    db_reset_test_data
    PermissionRule.delete_all

    # Make books self-labelling
    book_type = KObjectStore.read(O_TYPE_BOOK).dup
    book_type.add_attr(O_TYPE_BEHAVIOUR_SELF_LABELLING, A_TYPE_BEHAVIOUR)
    KObjectStore.update book_type

    run_javascript_test(:file, 'unit/javascript/javascript_runtime/test_permissions.js') do |runtime|
      support_root = runtime.host.getSupportRoot
      runtime.host.setTestCallback(proc { |string|
        case string
          when /check delete audit (.*)/
            ae = AuditEntry.order("id desc").first
            assert_equal 42, ae.user_id
            assert_equal KObjRef.from_presentation($1), ae.objref
          when /([^ ]+) ([^ ]+) (.*)/
            PermissionRule.new_rule! $1.to_sym, User.cache[42], KObjRef.from_presentation($3).to_i, $2.to_sym
          when 'reset'
            PermissionRule.destroy_all
          else
            raise "No javascript callback #{string}"
        end
        ""
      })
    end
  end

  # ===============================================================================================

  def test_object_retrieval
    restore_store_snapshot("basic")
    db_reset_test_data
    AuthContext.set_user(User.cache[42], User.cache[42])
    obj = KObject.new()
    obj.add_attr(O_TYPE_BOOK, A_TYPE)
    obj.add_attr("Hello there", A_TITLE)
    obj.add_attr("Alt title", A_TITLE, Q_ALTERNATIVE)
    obj.add_attr("Ping something", 20348)
    obj.add_attr(KTextParagraph.new("something\nelse"), 3948)
    obj.add_attr(6, 34)
    obj.add_attr(true, 235)
    obj.add_attr(DateTime.civil(2011, 9, 26, 12, 10), 2389)
    obj.add_attr(DateTime.civil(1880, 12, 2, 9, 55), 2390) # before 1970
    obj.add_attr(DateTime.civil(3012, 2, 18, 23, 1), 2391) # after 2038
    obj.add_attr(KIdentifierPostalAddress.new(["Main Street",nil,"London",nil,"A11 2BB","GB"]), 3002)
    obj.add_attr(KIdentifierFile.new(StoredFile.from_upload(fixture_file_upload('files/example3.pdf', 'application/pdf'))), 3070)
    obj.add_attr("With qual", 4059, 1029)
    obj.add_attr("Qual notes", A_NOTES, 2948)
    obj = KObjectStore.create(obj).dup
    AuthContext.set_user(User.cache[43], User.cache[43])
    obj = KObjectStore.update(obj).dup

    # Add a descriptive attribute to book for testing descriptiveTitle
    book_defn = KObjectStore.read(O_TYPE_BOOK).dup
    book_defn.add_attr(KObjRef.from_desc(A_CLIENT), A_ATTR_DESCRIPTIVE)
    KObjectStore.update(book_defn)

    todel1 = KObject.new()
    todel1.add_attr("to del1", A_TITLE)
    todel2 = KObject.new()
    todel2.add_attr("to del2", A_TITLE)

    KObjectStore.with_superuser_permissions do
      KObjectStore.create(todel1)
      KObjectStore.create(todel2)
    end

    jsdefines = {
      'TODEL1_OBJID' => todel1.objref.obj_id,
      'TODEL2_OBJID' => todel2.objref.obj_id,
      'OBJ_OBJID' => obj.objref.obj_id,
      'O_TYPE_BOOK_OBJID' => O_TYPE_BOOK.obj_id,
      'O_TYPE_BOOK_AS_STR' => O_TYPE_BOOK.to_presentation
    }
    run_javascript_test(:file, 'unit/javascript/javascript_runtime/test_object_retrieval.js', jsdefines)
    run_outstanding_text_indexing

    obj_mod = KObjectStore.read(obj.objref)
    assert_equal 'Hello!', obj_mod.first_attr(A_AUTHOR).to_s

    findnew = KObjectStore.query_and.free_text('SomethingXYZ', A_TITLE).execute(:all, :any)
    assert_equal 1, findnew.length
    created = findnew.first
    assert_equal "SomethingXYZ", created.first_attr(A_TITLE).to_s
    assert_equal 4, created.first_attr(45, Q_ALTERNATIVE)
    assert_equal 56, created.first_attr(563)
    created_notes = created.first_attr(A_NOTES)
    assert created_notes.class == KTextParagraph
    assert_equal "Ping\ncarrots", created_notes.to_s

    findnew2 = KObjectStore.query_and.free_text('T1', A_TITLE).execute(:all, :any)
    assert_equal 1, findnew2.length
    created_w_remove = findnew2.first
    titles = []
    created_w_remove.each(A_TITLE) { |v,d,q| titles << v.to_s }
    assert_equal ['T1','T3','T5'], titles

    # Check objects deleted
    assert KObjectStore.read(todel1.objref).deleted?
    assert KObjectStore.read(todel2.objref).deleted?

    # Check the text values
    findtv = KObjectStore.query_and.free_text('TextTypeValues', A_TITLE).execute(:all, :any)
    assert_equal 1, findtv.length
    v = findtv.first.first_attr(876)
    assert v.kind_of?(KTextPersonName)
    assert_equal 't f m l s', v.to_s
    v = findtv.first.first_attr(877)
    assert v.kind_of?(KTextPersonName)
    assert_equal 'F L', v.to_s
    v = findtv.first.first_attr(886)
    assert v.kind_of?(KIdentifierPostalAddress)
    assert_equal "s1\ns2\nci\nco\npc\nUnited Kingdom", v.to_s
    v = findtv.first.first_attr(887)
    assert v.kind_of?(KIdentifierPostalAddress)
    assert_equal "s2\nUnited States", v.to_s
    v = findtv.first.first_attr(998)
    assert v.kind_of?(KIdentifierTelephoneNumber)
    assert_equal "(United Kingdom) +44 7047 1111", v.to_s
  end

  # ===============================================================================================

  def test_queries
    restore_store_snapshot("basic")
    db_reset_test_data

    # Generate some objects for the JavaScript to find
    [["Flutes","Banana"],["ABC","DEF"],["Ping","Hello"],["Carrots","Ping"]].each do |title,notes|
      obj = KObject.new()
      obj.add_attr(O_TYPE_BOOK, A_TYPE)
      obj.add_attr(title, A_TITLE)
      obj.add_attr(notes, A_NOTES)
      KObjectStore.create(obj)
    end
    run_outstanding_text_indexing

    # Run the JavaScript test
    runtime = run_javascript_test(:file, 'unit/javascript/javascript_runtime/test_queries.js')
    queries = runtime.host.getDebugCollection()

    # Test the queries generated by the JavaScript
    tqg_query(queries, KObjectStore.query_and.free_text('Hello there'))
    tqg_query(queries, KObjectStore.query_and.free_text('Hello there', A_TITLE))
    tqg_query(queries, KObjectStore.query_and.free_text('Hello there', A_TITLE, Q_ALTERNATIVE))
    tqg_query(queries, KObjectStore.query_and.free_text('Hello there', A_TITLE, Q_ALTERNATIVE).link(O_TYPE_BOOK))
    tqg_query(queries, KObjectStore.query_and.free_text('Hello there', A_TITLE, Q_ALTERNATIVE).link(O_TYPE_BOOK, A_TYPE))
    tqg_query(queries, KObjectStore.query_and.free_text('Hello there', A_TITLE, Q_ALTERNATIVE).link(O_TYPE_BOOK, A_TYPE, Q_MOBILE))

    q1 = KObjectStore.query_and
    q1or = q1.or
    q1or.free_text("Ping").free_text("Pong")
    q1.link(O_TYPE_NEWS)
    tqg_query(queries, q1); tqg_query(queries, q1)  # formed in two different ways

    q2 = KObjectStore.query_and
    q2and = q2.and
    q2and.free_text("Ping").free_text("Pong")
    q2.link(O_TYPE_NEWS)
    tqg_query(queries, q2)

    q3 = KObjectStore.query_and
    q3not = q3.not
    q3not.free_text("Ping").free_text("Pong")
    q3.link(O_TYPE_PERSON)
    tqg_query(queries, q3)

    # Exact links
    tqg_query(queries, KObjectStore.query_and.link_exact(O_TYPE_BOOK, A_TYPE))

    # Linked to subquery queries
    [
      [:hierarchical, nil, nil],
      [:hierarchical, A_TITLE, nil],
      [:hierarchical, A_TITLE, Q_MOBILE],
      [:exact, A_TITLE, Q_MOBILE],
      [:exact, nil, nil],
      [:hierarchical, nil, nil],
      [:hierarchical, nil, nil],
      [:hierarchical, A_TITLE, nil],
      [:hierarchical, A_TITLE, Q_MOBILE],
      [:exact, A_TITLE, Q_MOBILE],
      [:exact, A_TITLE, nil],
      [:exact, nil, nil]
    ].each do |link_type,desc,qual|
      lq = KObjectStore.query_and
      subquery = lq.add_linked_to_subquery(link_type, desc, qual)
      subquery.subquery_container.free_text('Carrots')
      lq.free_text('X')
      tqg_query(queries, lq)
    end

    # Linked from subquery queries
    [
      [nil, nil],
      [A_TITLE, nil],
      [A_TITLE, Q_MOBILE],
      [A_TITLE, nil],
      [nil, nil],
      [nil, nil],
      [A_TITLE, nil],
      [A_TITLE, Q_MOBILE],
      [A_TITLE, nil],
      [nil, nil]
    ].each do |desc,qual|
      lq = KObjectStore.query_and
      subquery = lq.add_linked_from_subquery(desc, qual)
      subquery.subquery_container.free_text('Carrots')
      lq.free_text('X')
      tqg_query(queries, lq)
    end

    # Created by user query
    tqg_query(queries, KObjectStore.query_and.created_by_user_id(42).free_text("hello"))
    tqg_query(queries, KObjectStore.query_and.created_by_user_id(41).free_text("there"))

    # Query string parser
    tqg_query(queries, 'Carrots')
    tqg_query(queries, 'Carrots or pants and type:book')
    tqg_query(queries, 'Carrots or pants and type:book or title:fish')

    # Date ranges
    tqg_query(queries, KObjectStore.query_and.date_range(DateTime.new(2011,10,2), DateTime.new(2012,12,4)))
    tqg_query(queries, KObjectStore.query_and.date_range(DateTime.new(2011,10,2), DateTime.new(2012,12,4), A_DATE))
    tqg_query(queries, KObjectStore.query_and.date_range(DateTime.new(2011,10,2), DateTime.new(2012,12,4), 12, 345))
    tqg_query(queries, KObjectStore.query_and.date_range(nil, DateTime.new(2015,8,23)))
    tqg_query(queries, KObjectStore.query_and.date_range(DateTime.new(2015,2,23), nil, 36))

    # Link to any
    tqg_query(queries, KObjectStore.query_and.link_to_any(A_WORKS_FOR))
    tqg_query(queries, KObjectStore.query_and.link_to_any(A_CLIENT, Q_ALTERNATIVE))

    tqg_query(queries, KObjectStore.query_and.identifier(KIdentifierEmailAddress.new('test1@example.com')))
    tqg_query(queries, KObjectStore.query_and.identifier(KIdentifierEmailAddress.new('test2@example.com'), A_EMAIL_ADDRESS))
    tqg_query(queries, KObjectStore.query_and.identifier(KIdentifierEmailAddress.new('test3@example.com'), A_EMAIL_ADDRESS, Q_ALTERNATIVE))

    # Limits
    limit_query = KObjectStore.query_and.link_to_any(A_WORKS_FOR)
    limit_query.maximum_results(10)
    tqg_query(queries, limit_query)

    # Deleted objects
    tqg_query(queries, KObjectStore.query_and.free_text("a").include_deleted_objects(:deleted_only))

    # Make sure all the queries from the JavaScript have been used
    assert queries.isEmpty()
  end

  def tqg_query(queries, expected)
    unless expected.kind_of?(KObjectStore::Clause)
      q = KObjectStore.query_and
      KQuery.new(expected).add_query_to(q, [])
      expected = q
    end
    given = (queries.java_send(:remove, [Java::int], 0)).toRubyObject() # use java_send to disambiguate
    assert_equal expected.create_sql(:all, :date, {}), given.create_sql(:all, :date, {})
  end

  # ===============================================================================================

  def test_javascript_schema
    restore_store_snapshot("basic")
    db_reset_test_data
    run_javascript_test(:inline, <<-__E)
      TEST(function() {
        TEST.assert_equal(#{KConstants::A_PARENT},        ATTR["std:attribute:parent"]);
        TEST.assert_equal(#{KConstants::A_TYPE},          ATTR["dc:attribute:type"]);
        TEST.assert_equal(#{KConstants::A_TITLE},         ATTR["dc:attribute:title"]);
        TEST.assert_equal(#{KConstants::A_PARENT},        ATTR.Parent); // special
        TEST.assert_equal(#{KConstants::A_TYPE},          ATTR.Type); // special
        TEST.assert_equal(#{KConstants::A_TITLE},         ATTR.Title); // special
        TEST.assert_equal(#{KConstants::Q_ALTERNATIVE},   QUAL["dc:qualifier:alternative"]);
        TEST.assert_equal(#{KConstants::AA_NAME},         ALIASED_ATTR["std:aliased-attribute:name"]);
        TEST.assert_equal(#{User::GROUP_ADMINISTRATORS},  GROUP["std:group:administrators"]);
        TEST.assert_equal(#{KConstants::O_TYPE_BOOK.obj_id}, TYPE["std:type:book"].objId);
        TEST.assert_equal(#{KConstants::O_TYPE_LABEL.obj_id}, TYPE["std:type:label"].objId);
        TEST.assert_equal(#{KConstants::O_LABEL_COMMON.obj_id}, LABEL["std:label:common"].objId);
      });
    __E
    # And some tests in a .js file
    run_javascript_test(:file, 'unit/javascript/javascript_runtime/test_schema.js')
  end

  def test_javascript_user
    restore_store_snapshot("basic")
    db_reset_test_data
    # Delete some users
    user44 = User.find(44)
    user44.kind = User::KIND_USER_BLOCKED
    user44.save!
    disabled_group = User.new(:name => 'Test disabled group')
    disabled_group.kind = User::KIND_GROUP_DISABLED
    disabled_group.save!
    # Set a notification address on a group
    group21 = User.find(21)
    group21.email = 'notification@example.com'
    group21.save!
    # Create an object which is then set as the representative object for a user
    obj = KObject.new()
    obj.add_attr("User 1", KConstants::A_TITLE)
    obj.add_attr(KIdentifierEmailAddress.new("user1.not.same@example.com"), KConstants::A_EMAIL_ADDRESS)
    KObjectStore.create(obj)
    user41 = User.find(41)
    user41.objref = obj.objref
    user41.save!
    run_outstanding_text_indexing
    run_javascript_test(:file, 'unit/javascript/javascript_runtime/test_user.js', {
      'USER1_REF_OBJID' => obj.objref.obj_id, 'DISABLED_GROUP_ID' => disabled_group.id
    });
    db_reset_test_data
    # Check all permissions reflected in User JS API
    kuser = Java::ComOneisJsinterface::KUser.new
    allowedOps = Java::ComOneisJsinterface::KLabelStatements.getAllowedOperations()
    assert_equal KPermissionRegistry.entries.length, allowedOps.length();
    KPermissionRegistry.entries.each do |entry|
      assert kuser.respond_to? "jsFunction_can#{entry.symbol.to_s.capitalize}"
      assert allowedOps.contains(entry.symbol.to_s)
    end
  end

  def test_workunit
    db_reset_test_data
    begin
      run_javascript_test(:file, 'unit/javascript/javascript_runtime/test_workunit.js')
    ensure
      WorkUnit.delete_all() # allows cleanup of fixtures
    end
  end

  # ===============================================================================================

  def test_stored_files
    restore_store_snapshot("basic")
    # Create a file with a few versions
    stored_file = StoredFile.from_upload(fixture_file_upload('files/example.doc', 'application/msword'))
    # Make an object so the plugin can find it
    obj = KObject.new()
    obj.add_attr(O_TYPE_FILE, A_TYPE)
    file_identifer = KIdentifierFile.new(stored_file)
    assert file_identifer.tracking_id.kind_of?(String) && file_identifer.tracking_id.length > 10
    file_identifer.tracking_id = "TEST_TRACKING_ID"
    file_identifer.log_message = "Test log message"
    file_identifer.version_string = "3.4"
    obj.add_attr(file_identifer, 1000)
    KObjectStore.create(obj)
    # Text file
    test_stored_file = StoredFile.from_upload(fixture_file_upload('files/example8_utf8nobom.txt','text/plain'))
    # Run test
    run_javascript_test(:file, 'unit/javascript/javascript_runtime/test_stored_files.js', {
      "OBJ_WITH_FILE" => obj.objref.to_presentation,
      "STORED_FILE_ID" => stored_file.id,
      "TEXT_STORED_FILE_DIGEST" => test_stored_file.digest
    })
    # Check identifier in object created by JavaScript
    obj = KObjectStore.read(obj.objref)
    js_identifier = obj.first_attr(1004)
    assert js_identifier.kind_of?(KIdentifierFile)
    assert_equal "ff1003f5f8ba5c667415503669896c2940814fd64a846f08e879891864e06a06", js_identifier.digest
    assert_equal 19456, js_identifier.size
    assert_equal "js_filename.doc", js_identifier.presentation_filename
    assert_equal "TRACKING_FROM_JS", js_identifier.tracking_id
    assert_equal "JS log message", js_identifier.log_message
    assert_equal "2.6", js_identifier.version_string
  end

  # ===============================================================================================

  def test_label_primitives
    restore_store_snapshot("basic")
    run_javascript_test(:file, 'unit/javascript/javascript_runtime/test_label_primitives.js') do |runtime|
      # While the runtime is active, check round-tripping
      list0 = KLabelList.new([1,4,6])
      list1 = Java::ComOneisJsinterface::KLabelList.fromAppLabelList(list0).toRubyObject()
      assert ! list0.equal?(list1) # not same object
      assert list0 == list1

      changes0 = KLabelChanges.new([1,2], [4,5])
      changes1 = Java::ComOneisJsinterface::KLabelChanges.fromAppLabelChanges(changes0).toRubyObject()
      assert ! changes0.equal?(changes1)
      assert changes0._add_internal == changes1._add_internal
      assert changes0._remove_internal == changes1._remove_internal
    end
  end

  # ===============================================================================================

  def test_relabel
    restore_store_snapshot("basic")
    db_reset_test_data
    PermissionRule.new_rule!(:deny, 42, 8888, :create)
    PermissionRule.new_rule!(:deny, 42, 7777, :read)
    PermissionRule.new_rule!(:deny, 42, 4444, :relabel)
    AuthContext.with_user(User.cache[42]) do
      run_javascript_test(:file, 'unit/javascript/javascript_runtime/test_relabel.js')
    end

    # Just check that the underlying utility doesn't relabel unnecessarily
    o = KObject.new([1234])
    o.add_attr(O_TYPE_BOOK, A_TYPE)
    o.add_attr("Ping", A_TITLE)
    KObjectStore.create(o)

    about_to_create_an_audit_entry
    JSKObjectSupport.relabelObject(o, KLabelChanges.new([123499],[]))
    assert_audit_entry(:kind => "RELABEL")
    o = KObjectStore.read(o.objref) # reload to get new labels
    JSKObjectSupport.relabelObject(o, KLabelChanges.new([123499],[]))
    assert_no_more_audit_entries_written  # second time it doesn't do anything.

    # Still does something if you pass in a ref, though
    o = KObjectStore.read(o.objref)
    JSKObjectSupport.relabelObject(o.objref, KLabelChanges.new([123499],[]))
    assert_audit_entry(:kind => "RELABEL")
  end

  # ===============================================================================================

  def test_store_object_labels
    restore_store_snapshot("basic")

    # Book labelled by BOOK type:
    book_type = KObjectStore.read(O_TYPE_BOOK).dup
    book_type.add_attr(O_TYPE_BOOK, A_TYPE_BASE_LABEL)
    KObjectStore.update book_type

    # Laptop labelled by custom label, and self-labelled
    label = KObject.new()
    label.add_attr(O_TYPE_LABEL, A_TYPE)
    label.add_attr(KIdentifierConfigurationName.new("test:label:mine"), A_CODE)
    label.add_attr("Mine", A_TITLE)
    KObjectStore.create label

    equipment = KObjectStore.read(O_TYPE_EQUIPMENT).dup
    equipment.add_attr(label.objref, A_TYPE_BASE_LABEL)
    equipment.add_attr(O_TYPE_BEHAVIOUR_SELF_LABELLING, A_TYPE_BEHAVIOUR)
    KObjectStore.update equipment

    run_javascript_test(:file, 'unit/javascript/javascript_runtime/test_store_object_labels.js')
  end

  # ===============================================================================================

  def test_app_info
    run_javascript_test(:file, 'unit/javascript/javascript_runtime/test_app_info.js', {
      "_TEST_APP_ID" => _TEST_APP_ID,
      "SERVER_PORT_EXTERNAL_CLEAR_IN_URL" => KApp::SERVER_PORT_EXTERNAL_CLEAR_IN_URL
    })
  end

  # ===============================================================================================

  def test_text
    run_javascript_test(:file, 'unit/javascript/javascript_runtime/test_text.js')
  end

  # ===============================================================================================

  def test_typecode
    run_javascript_test(:file, 'unit/javascript/javascript_runtime/test_typecode.js')
  end

  # ===============================================================================================

  def test_datetime
    run_javascript_test(:file, 'unit/javascript/javascript_runtime/test_datetime.js')
  end

  # ===============================================================================================

  def test_dbtime
    run_javascript_test(:file, 'unit/javascript/javascript_runtime/test_dbtime.js')
  end

  # ===============================================================================================

  def test_json
    run_javascript_test(:file, 'unit/javascript/javascript_runtime/test_json.js')
  end

  # ===============================================================================================

  def test_refkeydictionary
    restore_store_snapshot("basic") # for testing hierarchy
    run_javascript_test(:file, 'unit/javascript/javascript_runtime/test_refkeydictionary.js')
  end

  # ===============================================================================================

  def test_security_functions
    if java.lang.Integer::MAX_VALUE != javax.crypto.Cipher.getMaxAllowedKeyLength("AES")
      puts "Java Cryptography Extension (JCE) Unlimited Strength Jurisdiction Policy not installed, SHA256 test will fail" if _TEST_APP_ID == FIRST_TEST_APP_ID
    end
    run_javascript_test(:file, 'unit/javascript/javascript_runtime/test_security.js')
  end

  # ===============================================================================================

  def test_services
    run_javascript_test(:file, 'unit/javascript/javascript_runtime/test_services.js')
  end

  # ===============================================================================================

  def test_client_side_editor_support
    restore_store_snapshot("basic")
    run_javascript_test(:file, 'unit/javascript/javascript_runtime/test_client_side_editor_support.js')
  end

  # ===============================================================================================

  def run_audit_test(filename)
    restore_store_snapshot("basic")
    AuditEntry.delete_all
    about_to_create_an_audit_entry
    run_javascript_test(:file, "unit/javascript/javascript_runtime/#{filename}.js") do |runtime|
      runtime.host.setTestCallback(proc { |string|
        case string
        when "ONE"
          assert_audit_entry(:kind => 'test:kind0', :displayable => true)
        when "TWO"
          assert_audit_entry(:kind => 'test:ping4', :displayable => false,
            :obj_id => 89, :objref => KObjRef.new(89), # two ways of reading the same thing
            :entity_id => 997)
        when "resetAudit"
          AuditEntry.delete_all
        when "loadFixture"
          AuditEntry.delete_all
          db_load_table_fixtures :audit_entries
        end
        ''
      })
      assert_no_more_audit_entries_written
    end
  end

  def test_audit_entry
    run_audit_test 'test_audit_entry'
  end

  def test_audit_entry_querying
    if ENV['KHOST_OPERATING_SYSTEM'] == "Darwin"
      puts "Mac OS X has a humorously different case ordering, will fail sorting test (see http://stackoverflow.com/questions/13370051/ordering-differences-between-postgres-instances-on-different-machines-same-loca )" if _TEST_APP_ID == FIRST_TEST_APP_ID
    end
    run_audit_test 'test_audit_entry_querying'
  end

  def test_audit_query_misuse
    run_audit_test 'test_audit_entry_misuse'
  end

  def test_audit_entry_permissions
    db_reset_test_data

    user1 = 41 # group1
    user2 = 42 # group2
    user3 = 43 # group3 > group1, group2.  ADMINISTRATORS
    group1 = 21
    group2 = 22
    group3 = 23

    [O_TYPE_BOOK, O_TYPE_LAPTOP].each do |type|
      type_object = KObjectStore.read(KObjRef.new(type)).dup
      type_object.add_attr type_object.objref, A_TYPE_BASE_LABEL
      KObjectStore.update type_object
    end

    PermissionRule.new_rule!(:allow, user1, KConstants::O_TYPE_BOOK, :create)
    PermissionRule.new_rule!(:deny, user1, KConstants::O_TYPE_BOOK, :read)

    PermissionRule.new_rule!(:allow, group2, KConstants::O_LABEL_COMMON, :create, :read, :update)
    PermissionRule.new_rule!(:deny, group3, KConstants::O_LABEL_COMMON, :create, :read, :update)

    PermissionRule.new_rule!(:deny, User::GROUP_EVERYONE, KConstants::O_TYPE_LAPTOP, :read, :update)
    PermissionRule.new_rule!(:allow, group2, KConstants::O_TYPE_LAPTOP, :read)
    PermissionRule.new_rule!(:allow, user1, KConstants::O_TYPE_LAPTOP, :read)

    AuditEntry.delete_all
    begin
      run_javascript_test(:file, "unit/javascript/javascript_runtime/test_audit_entry_permissions.js") do |runtime|
        runtime.host.setTestCallback(proc { |email|
          start_test_request(nil, User.find_first_by_email(email))
          ""
        })
      end
    ensure
      end_test_request
    end

    PermissionRule.delete_all
  end

  # ===============================================================================================

  def test_create_and_update_user
    db_reset_test_data
    u43 = User.find(43);
    u43.objref = KObjRef.new(876543);
    u43.save!
    install_grant_privileges_plugin_with_privileges('pCreateUser', 'pUserActivation', 'pUserPasswordRecovery', 'pUserSetRef', 'pUserSetDetails')
    begin
      assert_equal nil, User.find_first_by_email('js@example.com')
      assert User.find(43).objref
      run_javascript_test(:file, 'unit/javascript/javascript_runtime/test_create_and_update_user.js')
      jsuser = User.find_first_by_email('js@example.com')
      assert nil != jsuser
      assert_equal 'Java', jsuser.name_first
      assert_equal 'Script', jsuser.name_last
      assert_equal 'Java Script', jsuser.name
      assert_equal 'js@example.com', jsuser.email
      assert_equal [4,21,22], jsuser.groups_ids.sort
      assert_equal 987654, jsuser.objref.obj_id
      assert_equal User::KIND_USER_BLOCKED, User.find(44).kind
      assert_equal User::KIND_GROUP_DISABLED, User.find(23).kind
      ['without-ref@example.com', 'without-ref2@example.com', 'without-ref3@example.com'].each do |email|
        without_ref = User.find_first_by_email(email)
        assert_equal nil, without_ref.objref
      end
      with_ref = User.find_first_by_email('with-ref@example.com')
      assert_equal KObjRef.new(88332), with_ref.objref
      assert !(User.find(43).objref)
      user44 = User.find(44) # has been updated by test
      assert_equal "JSfirst", user44.name_first
      assert_equal "JSlast", user44.name_last
      assert_equal "js-email-44@example.com", user44.email
    ensure
      uninstall_grant_privileges_plugin
    end
  end

  # ===============================================================================================

  def test_email_template
    install_grant_privileges_plugin_with_privileges('pSendEmail')
    begin
      d_before = EmailTemplate.test_deliveries.size
      run_javascript_test(:file, 'unit/javascript/javascript_runtime/test_email_template.js', {})
      assert_equal d_before + 1, EmailTemplate.test_deliveries.size
      sent = EmailTemplate.test_deliveries.last
      assert_equal ['Test Person <test@example.com>'], sent.header.to
      assert_equal 'Random Subject', sent.header.subject
      assert sent.multipart?
      sent.body.each do |part|
        assert part.body.include?('XXX-MESSAGE-FROM-JAVASCRIPT-XXX')
      end
    ensure
      uninstall_grant_privileges_plugin
    end
  end


  # ===============================================================================================

  def test_console
    db_reset_test_data
    run_javascript_test(:file, 'unit/javascript/javascript_runtime/test_console.js')
    logged_text = Thread.current[:_frm_logger_buffer]
    ['__L_O_G__',
     '__D_E_B_U_G__',
     '__I_N_F_O__',
     '__W_A_R_N__',
     '__E_R_R_O_R__',
     '__D_I_R__',
     'X1:ping X2:56 X3:[42] LAST',
     '[32] [53] pong',
     '[Ref 9qvwz]',
     'null',
     '[User user1@example.com(41)]',
     '[SCHEMA]',
     'labelList: [LabelList [22v8, 270z]]',
     'labelChanges: [LabelChanges {+[270z] -[22v8]}]',
     '[StoreQuery]',
     '[RefKeyDictionary {"1":{},"2":"Hello","3":"World","zq":false,"zv":{}}]',
     ].each do |expected_message|
      assert logged_text.include?("JS: #{expected_message}\n")
    end
    assert logged_text =~ /__T1__: \d+ms/
    KApp.logger.info("END")
  end

  # ===============================================================================================

  def test_database
    restore_store_snapshot("basic")
    db_reset_test_data
    StoredFile.destroy_all
    # Clean up any old tables
    drop_all_javascript_db_tables
    # Create some test files
    file1 = StoredFile.from_upload(fixture_file_upload('files/example10.tiff', 'image/tiff'))
    file2 = StoredFile.from_upload(fixture_file_upload('files/example7.html', 'text/html'))
    # Run test which defines tables
    runtime = run_javascript_test(:file, 'unit/javascript/javascript_runtime/test_database.js', {}) do |runtime|
      # Before running tests, tell the namespace the name to use, via the host
      runtime.host.setNextPluginToBeRegistered("dummy_plugin_name!", "dbtest")
      # The test callback is called in the middle of the tests, after the tables have been defined
      runtime.host.setTestCallback(Proc.new {
        # Set up the storage
        js = runtime.getJavaScriptScope()
        db = js.get("db", js)
        db.setupStorage()
        db.setupStorage() # And again, to make sure it's happy to be called twice
        # Check the expected tables were created
        ['j_dbtest_employee','j_dbtest_department','j_dbtest_numbers'].each do |table|
          sql = "SELECT table_name FROM information_schema.tables WHERE table_schema='a#{KApp.current_application}' AND table_name='#{table}'"
          r = KApp.get_pg_database.exec(sql)
          assert_equal 1, r.length
          r.each { |n| assert_equal table, n.first }
          r.clear
        end
        # Check that the index on the case insensitive field uses the lower() function
        r = KApp.get_pg_database.exec("SELECT * FROM pg_catalog.pg_indexes WHERE schemaname='a#{KApp.current_application}' AND tablename='j_dbtest_employee' AND indexdef LIKE '%lower(caseinsensitivevalue)%'");
        assert_equal 1, r.length
        r.clear
        # Callback return must be a string
        ""
      })
    end
    StoredFile.destroy_all
  end

  # ===============================================================================================

  def test_database_allowed_names
    ns = Java::ComOneisJsinterfaceDb::JdNamespace
    [
      ['Hello', false],
      ['thisIsOK2', true],
      ['9pants', false],
      ['df kjdf', false],
      ['camelCase ', false],
      [' camelCase', false],
      # don't allow underscores, because the database schema uses them to ensure generated names don't clash with user specified names
      ['something_underscore2', false],
      ['_pants', false],
      ["something\n", false],
      ["carrots234ABC", true]
    ].each do |name, allowed|
      was_allowed = false
      begin
        ns.checkNameIsAllowed(name)
        was_allowed = true
      rescue
        was_allowed = false
      end
      assert_equal allowed, was_allowed
    end
  end

  # ===============================================================================================

  def test_generate_xls
    restore_store_snapshot("basic")
    db_reset_test_data
    runtime = run_javascript_test(:file, 'unit/javascript/javascript_runtime/test_generate_xls.js', {})
    collection = runtime.getHost().getDebugCollection()
    assert_equal 2, collection.length
    xls = collection.first
    assert_equal "TestFilename.xls", xls.getProposedFilename()
    assert_equal "application/vnd.ms-excel", xls.getMimeType()
    assert_equal true, xls.haveData()
    xls_data = String.from_java_bytes(xls.makeData())
    # File.open("test.xls", "w") { |f| f.write xls_data }
    # TODO: Better test for output from xls JS interface
    [
      'Sheet One', 'TESTOBJ', 'Heading Three', '13:23', 'User 1', '(DELETED)', "ABC_DEF_"
    ].each do |string|
      assert xls_data.include?(string), "#{string} not found in generated spreadsheet"
    end
    # XML version
    xlsx = collection[1]
    assert_equal "XMLspreadsheet.xlsx", xlsx.getProposedFilename()
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", xlsx.getMimeType()
    assert_equal true, xlsx.haveData()
    xlsx_data = String.from_java_bytes(xlsx.makeData())
    # File.open("test.xlsx", "w") { |f| f.write xlsx_data }
  end

  # ===============================================================================================

  def test_locked_runtimes
    runtime = make_javascript_runtime()
    runtime.useOnThisThread(JSSupportRoot.new)
    # use the symbol whitelist to find all the symbols we're interested in, and try and add a property
    symbols = ['$ONEISHost','$Ref']
    File.open(KFRAMEWORK_ROOT+'/lib/javascript/globalswhitelist.txt') do |f|
      f.each do |line|
        symbol = line.chomp
        symbols << symbol unless symbol.empty? || symbol == 'NaN' || symbol == 'undefined' || symbol == 'Infinity'
      end
    end
    checks = 0
    has_no_prototype = {
      'Math'=>true, 'StopIteration'=>true, 'JSON'=>true, 'Handlebars'=>true, 'console'=>true, 'HTTP'=>true,
      'oForms'=>true, 'decodeURI'=>true, 'decodeURIComponent'=>true, 'encodeURI'=>true, 'encodeURIComponent'=>true,
      'escape'=>true, 'eval'=>true, 'isFinite'=>true, 'isNaN'=>true, 'parseFloat'=>true, 'parseInt'=>true,
      'unescape'=>true, 'uneval'=>true
    }
    symbols.each do |symbol|
      checks += 1
      unless has_no_prototype.has_key?(symbol)
        assert_raise Java::OrgMozillaJavascript::EvaluatorException do
          runtime.evaluateString(%Q!#{symbol}.prototype.testing_testing_addition = function() { return true; };!, nil)
        end
      end
      assert_raise Java::OrgMozillaJavascript::EvaluatorException do
        runtime.evaluateString(%Q!#{symbol}.testing_testing_addition = function() { return true; };!, nil)
      end
    end
    assert checks > 20
    # Try and replace a function on an object
    assert_raise Java::OrgMozillaJavascript::EvaluatorException do
      runtime.evaluateString(%Q!Array.prototype.push = function() { return true; };!, nil)
    end
    # Try and make a Java class in various devious ways
    assert_raise Java::OrgMozillaJavascript::EcmaError do
      runtime.evaluateString(%Q!var semaphore = new java.util.concurrent.Semaphore(23);!, nil)
    end
    assert_raise Java::OrgMozillaJavascript::EcmaError do
      runtime.evaluateString(%Q!var semaphore = $ONEISHost.getClass();!, nil)
    end
    assert_raise Java::OrgMozillaJavascript::EcmaError do
      runtime.evaluateString(%Q!var semaphore = $ONEISHost['class'].forName('java.lang.StringBuffer').newInstance();!, nil)
    end
    # Make sure the (lazily loaded) RegExp class works
    runtime.evaluateString(<<-__E, nil)
      var x = 'something 222 or other';
      var reg = new RegExp("\\\\d+");
      var m = reg.exec(x);
      $host._debug_string = m[0];
    __E
    assert_equal '222', runtime.host.jsGet__debug_string()
    # Check that things hidden inside functions get sealed too
    hiddenTests = <<__E
      .x = 0;
      .number = 2;
      .array[0].property = 4;
__E
    # TODO: Improve sealing so that the following are blocked in the sealed runtime (might need some patching of Rhino)
    #.array.push("hello");
    #.string.hello = 3;
    hiddenTests.strip.split(/\s*[\r\n]+\s*/).each do |test|
      execjs = "O.$private.$getHiddenInsideFunction()#{test}";
      assert_raise Java::OrgMozillaJavascript::EvaluatorException do
        runtime.evaluateString(execjs, nil)
      end
    end
    # All done!
    runtime.stopUsingOnThisThread()
  end

  # Test to make sure the hidden data structure for sealing tests exists
  def test_locked_runtimes_test_structure_exists
    run_javascript_test(:file, 'unit/javascript/javascript_runtime/test_has_seal_test.js')
  end

  # ===============================================================================================

  def test_runtime_invalidation_from_javascript
    KJSPluginRuntime.current.runtime.evaluateString("var x = 1;", "TEST")
    runtime1 = KJSPluginRuntime.current.__id__
    KJSPluginRuntime.current.runtime.evaluateString("var x = 2;", "TEST")
    runtime2 = KJSPluginRuntime.current.__id__
    assert_equal runtime1, runtime2
    KJSPluginRuntime.current.runtime.evaluateString("O.reloadJavaScriptRuntimes();", "TEST")
    runtime3 = KJSPluginRuntime.current.__id__
    assert runtime2 != runtime3 # got flushed
    KJSPluginRuntime.current.runtime.evaluateString("var x = 4;", "TEST")
    runtime4 = KJSPluginRuntime.current.__id__
    assert_equal runtime4, runtime3
  end

  # ===============================================================================================

  def test_runtimes_and_threads
    @runtime1 = make_javascript_runtime()
    @runtime2 = make_javascript_runtime()
    # Create an assert function within each runtime
    jsassert = %Q! function js_assert(val) { $host._debug_string = (val) ? 'OK' : 'FAIL'; } !
    [@runtime1,@runtime2].each { |r| r.useOnThisThread(JSSupportRoot.new); r.evaluateString(jsassert, nil); r.stopUsingOnThisThread() }
    # Run the tests
    @barrier = java.util.concurrent.CyclicBarrier.new(2) # number of threads
    [:_test_rat_thread1,:_test_rat_thread2].map do |method|
      Thread.new do
        begin
          self.send(method)
        rescue => e
          puts method
          puts e
          raise
        end
      end
    end .each { |t| t.join }
  end

  def _test_rat_thread1
    @runtime1.useOnThisThread(JSSupportRoot.new)
    @barrier.await # ---------------------- 1
    @barrier.await # ---------------------- 2
    @runtime1.evaluateString(<<-__E, nil)
      var test1 = 34;
      js_assert(this.test1 === 34);
    __E
    assert_from_runtime @runtime1
    @barrier.await # ---------------------- 3
    @barrier.await # ---------------------- 4
    @runtime1.evaluateString(<<-__E, nil)
      TEST.prototype.pants = 32;
      js_assert(TEST.prototype.pants === 32);
    __E
    assert_from_runtime @runtime1
    @barrier.await # ---------------------- 5
    @barrier.await # ---------------------- 6
    @runtime1.stopUsingOnThisThread();
  end

  def _test_rat_thread2
    @barrier.await # ---------------------- 1
    # Check a runtime can't be used in more than one thread
    assert_raise Java::JavaLang::RuntimeException do
      @runtime1.useOnThisThread(JSSupportRoot.new)
    end
    assert_raise Java::JavaLang::RuntimeException do
      @runtime1.evaluateString('1;', nil)
    end
    @runtime2.useOnThisThread(JSSupportRoot.new)
    @barrier.await # ---------------------- 2
    @barrier.await # ---------------------- 3
    @runtime2.evaluateString(<<-__E, nil)
      // This construction avoids Rhino warnings
      var ok = false;
      if(this.test1 == undefined) { ok = true;}
      js_assert(ok);
    __E
    assert_from_runtime @runtime2
    @barrier.await # ---------------------- 4
    @barrier.await # ---------------------- 5
    @runtime2.evaluateString(<<-__E, nil)
      var ok = false;
      if(TEST.prototype.pants == undefined) { ok = true; }
      js_assert(ok);
    __E
    assert_from_runtime @runtime2
    @barrier.await # ---------------------- 6
    @runtime2.stopUsingOnThisThread();
  end

  def assert_from_runtime(runtime)
    assert_equal 'OK', runtime.host.jsGet__debug_string()
  end

end
