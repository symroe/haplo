# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class PermissionsTest < IntegrationTest
  include KConstants
  include KFileUrls

  ALL_PERMS = KPermissionRegistry.entries.map { |e| e.symbol }

  def setup
    restore_store_snapshot("basic")
    db_reset_test_data
    FileCacheEntry.destroy_all()
    StoredFile.destroy_all()
  end

  def test_permissions_and_policies
    # Create a couple of users
    @user_joe = make_user('joe.bloggs@example.com')
    @user_joan = make_user('joan.ping@example.com')
    common_group = User.new(:name => "common group")
    common_group.kind = User::KIND_GROUP
    common_group.save!
    common_group.update_members! [@user_joe.id, @user_joan.id]
    # Apply permissions

    book_type = KObjectStore.read(O_TYPE_BOOK).dup
    book_type.add_attr(KObjRef.from_desc(A_PROJECT), A_TYPE_LABELLING_ATTR)
    KObjectStore.update book_type

    project1 = KObject.new
    project1.add_attr(O_TYPE_PROJECT, A_TYPE)
    KObjectStore.create project1

    project2 = KObject.new
    project2.add_attr(O_TYPE_PROJECT, A_TYPE)
    KObjectStore.create project2

    # Allow Joe all permissions on project 1 (and only project 1)
    PermissionRule.new_rule! :reset, common_group, O_LABEL_COMMON, *KPermissionRegistry.lookup.keys
    PermissionRule.new_rule! :allow, @user_joe, project1.objref, *KPermissionRegistry.lookup.keys
    PermissionRule.new_rule! :allow, @user_joan, project1.objref, :update
    PermissionRule.new_rule! :allow, @user_joan, project2.objref, *KPermissionRegistry.lookup.keys

    # Create some objects
    @objs = Hash.new
    @files = Hash.new
    @objinfo = [
      [:p1, project1, "example8_utf16bom.txt",   "ping"],
      [:p2, project2, "example8_utf8bom.txt",    "pong"],
      [:o1, project1, "example8_utf8nobom.txt",  "hello", :p2],
      [:o2, project2, "example5.png",            "pants", :p1]
    ]
    @objinfo.each do |name, project, attached_filename, title, link_to|
      o = KObject.new()
      o.add_attr(O_TYPE_BOOK, A_TYPE)
      o.add_attr(project.objref, A_PROJECT)
      o.add_attr("#{title}-#{_TEST_APP_ID}-x",A_TITLE)
      o.add_attr("findkey", A_NOTES)
      if link_to != nil
        o.add_attr(@objs[link_to], A_CLIENT)
      end
      # Attach a file for testing file permission tests
      file = StoredFile.from_upload(fixture_file_upload(
        'files/'+attached_filename,
        (attached_filename =~ /\.png\z/) ? 'image/png' : 'text/plain'))
      o.add_attr(KIdentifierFile.new(file), A_FILE)
      @files[name] = [file, attached_filename]
      # Create object
      KObjectStore.create(o)
      @objs[name] = o
    end
    run_outstanding_text_indexing :expected_work => true
    run_all_jobs({}) # for the new files

    # Now let's login!
    joe = login(@user_joe)
    joan = login(@user_joan)

    # Read some objects, and check the response is correct
    joe.get obj_path(:o1)
    joe.assert_select '#z__page_name h1', obj_title(:o1)
    assert ! joe.response.body.include?('/test2/') # check hiding of linked object
    assert joe.response.body.include?('/do/authentication/hidden_object')
    joe.get file_path(:o1)
    check_file_download(joe, :o1)

    joan.get_403 obj_path(:o1)
    joan.get_403 file_path(:o1)

    joe.get_403 obj_path(:o2)
    joe.get_403 file_path(:o2)
    joe.get_403 thumbnail_path(:o2)

    joan.get obj_path(:o2)
    joan.assert_select '#z__page_name h1', obj_title(:o2)
    assert ! joan.response.body.include?('/test1/') # check hiding of linked object
    assert joan.response.body.include?('/do/authentication/hidden_object')
    joan.get file_path(:o2)
    check_file_download(joan, :o2)
    joan.get thumbnail_path(:o2)
    assert joan.response.body =~ /IHDR/ # PNG header

    # Generate a signature to download a file, overriding the permissions system
    joe.get_403 file_path(:o2)
    joe_o2_signature = get_file_signature(:o2, nil, joe.session)
    joe_o2_signature_thumbnail = get_file_signature(:o2, :thumbnail, joe.session)
    joe.get file_path(:o2)+"?s="+joe_o2_signature
    check_file_download(joe, :o2)
    joe.get_403 file_path(:o2)+"?s="+joe_o2_signature_thumbnail
    # Check a new signature is needed for transformed files
    joe.get_403 file_path(:o2, 'w100')+"?s="+joe_o2_signature
    joe_o2_signature_w100 = get_file_signature(:o2, 'w100', joe.session)
    joe.get file_path(:o2, 'w100')+"?s="+joe_o2_signature_w100
    assert joe.response.body =~ /IHDR/ # PNG header
    assert File.open("test/fixtures/files/example5.png") { |f| f.read } != joe.response.body
    # Check thumbnail requests
    joe.get_403 thumbnail_path(:o2)
    joe.get_403 thumbnail_path(:o2)+"?s="+joe_o2_signature
    joe.get thumbnail_path(:o2)+"?s="+joe_o2_signature_thumbnail
    assert joe.response.body =~ /IHDR/ # PNG header

    # Can't use that file signature for another file
    joe.get_403 file_path(:p2)
    joe.get_403 file_path(:p2)+"?s="+joe_o2_signature
    joe.get_403 file_path(:p2)+"?s="+joe_o2_signature_thumbnail

    # Can't use a file signature in another session
    joe_o1_signature = get_file_signature(:o1, nil, joe.session)
    joe_o1_signature_thumbnail = get_file_signature(:o1, :thumbnail, joe.session)
    joan.get_403 file_path(:o1)
    joan.get_403 file_path(:o1)+"?s="+joe_o1_signature
    joan.get_403 file_path(:o1)+"?s="+joe_o1_signature_thumbnail

    # Do some searching
    joe.get "/search?q=findkey"
    joan.get "/search?q=findkey"
    @objinfo.each do |name, project, title|
      will_have, wont_have = ((project == project1) ? [joe, joan] : [joan, joe])
      assert will_have.response.body.include?(obj_title(name))
      assert ! wont_have.response.body.include?(obj_title(name))
    end

    # Now change the permissions!
    PermissionRule.destroy_all(user_id: @user_joe.id)

    # Read some objects, and check the response is correct
    joe.get_403 obj_path(:o1)
    joe.get_403 file_path(:o1)

    joan.get_403 obj_path(:o1)
    joan.get_403 file_path(:o1)

    joe.get_403 obj_path(:o2)
    joe.get_403 file_path(:o2)

    joan.get obj_path(:o2)
    joan.assert_select '#z__page_name h1', obj_title(:o2)
    joan.get file_path(:o2)
    check_file_download(joan, :o2)

    # Do some searching
    joe.get "/search?q=findkey"
    joan.get "/search?q=findkey"
    @objinfo.each do |name, project, title|
      will_have, wont_have = ((project == project1) ? [joe, joan] : [joan, joe])
      assert ! joe.response.body.include?(obj_title(name))
      joan_inc = joan.response.body.include?(obj_title(name))
      assert (project == project1) ? (! joan_inc) : joan_inc
    end

    # Check the support user includes the everyone group
    support_user = User.find(User::USER_SUPPORT)
    assert support_user.id == 3
    assert support_user.groups_ids.include?(User::GROUP_EVERYONE)

    # Check the home page doesn't redirect to login for non-anonymous users, even if they don't have read permissions for anything
    assert joe.current_user.permissions.something_allowed?(:read)
    joe.get '/'
    assert joe.response.kind_of? Net::HTTPOK # not redirected

    # Set permissions so Joe can't read anything
    PermissionRule.destroy_all

    assert !(joe.current_user.permissions.something_allowed?(:read))
    joe.get '/'
    assert joe.response.kind_of? Net::HTTPOK # not redirected

    # Give the ANONYMOUS user access to something, check home page doesn't redirect
    PermissionRule.new_rule! :allow, User::USER_ANONYMOUS, project1.objref, :read
    assert session == "No session" || session[:uid] == nil
    get '/'
    assert response.kind_of? Net::HTTPOK # not redirected

  end

  def make_user(email)
    raise "Bad email" unless email =~ /\A(\w+)\.(\w+)@/
    u = User.new(:name_first => $1, :name_last => $2, :email => email)
    u.kind = User::KIND_USER
    u.password = 'pass1234'
    u.save!
    u
  end

  def login(user)
    open_session do |s|
      s.extend(IntegrationTestUtils)
      s.assert_login_as(user, 'pass1234')
    end
  end

  def obj_path(name)
    objref = @objs[name].objref
    "/#{objref.to_presentation}/slug-glug"
  end

  def obj_title(name)
    @objs[name].first_attr(A_TITLE).to_s
  end

  def file_path(name, transforms = nil)
    file, filename = @files[name]
    file_url_path(file, transforms)
  end

  def get_file_signature(name, transforms, session)
    raise "bad signature" unless file_url_path(@files[name].first, transforms, {:sign_with => session}) =~ /\?s=([a-f0-9]{64,64})\z/
    $1
  end

  def thumbnail_path(name)
    file, filename = @files[name]
    "/_t/#{file.digest}/#{file.size}"
  end

  def check_file_download(test_session, name)
    file, filename = @files[name]
    assert_equal File.open("test/fixtures/files/#{filename}", "r:binary") { |f| f.read }, test_session.response.body
  end

end
