# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KJSPluginRuntime
  RUNTIME_CACHE = KApp.cache_register(KJSPluginRuntime, "JavaScript runtimes")
  Runtime = Java::ComOneisJavascript::Runtime

  JS_PLUGIN_RUNTIME_HEALTH_REPORTER = KFramework::HealthEventReporter.new("JS_PLUGIN_RUNTIME")

  # Listen for notifications which require invalidation of the runtime.
  # Use buffering so that when something requiring an invalidation happens when the runtime is in use,
  # the notification is delayed until the nested stack of runtime invocations has exited.
  @@invalidate_notification_buffer = KNotificationCentre.when_each([
    [:jspluginruntime_internal, :label_mapping_changed],
    [:jspluginruntime_internal, :invalidation_requested],
    [:os_schema_change],
    [:plugin,            :install],
    [:plugin,            :uninstall],
    [:user_modified,     :group]
  ], {:deduplicate => true, :max_arguments => 0}) do # max arguments set to zero so every notification counts the same
    KApp.cache_invalidate(RUNTIME_CACHE)
  end
  KNotificationCentre.when(:os_object_change) do |name, operation, previous_obj, modified_obj, is_schema|
    # TODO: When SCHEMA mapping implemented, remove this (and corresponding notification listener line above)
    if KConstants::O_TYPE_LABEL == modified_obj.first_attr(KConstants::A_TYPE)
      # Trigger a runtime invalidation (via buffered notifications) so SCHEMA.O_LABEL_* constants will be updated
      KNotificationCentre.notify(:jspluginruntime_internal, :label_mapping_changed)
    end
  end

  def self.invalidate_all_runtimes
    # Delay the invalidation until the runtime has exited -- this is called from the JS API
    KNotificationCentre.notify(:jspluginruntime_internal, :invalidation_requested)
  end

  def self.current
    KApp.cache(RUNTIME_CACHE)
  end

  def self.current_if_active
    KApp.cache_if_already_checked_out(RUNTIME_CACHE)
  end

  def initialize
    # This is repeated in the rescue for kapp_cache_checkout to recover
    @runtime = Runtime.new
  end

  def runtime
    @runtime
  end

  # Keep track of nested calls into the JavaScript runtime, using the notification buffer to track the depth
  # Preserve the last_used_plugin_name over the call.
  # Returns the value of the yielded block.
  def using_runtime
    previous_last_used_plugin_name = @support_root.last_used_plugin_name
    value_from_block = nil
    begin
      @@invalidate_notification_buffer.while_buffering do
        value_from_block = yield
      end
    end
    if @@invalidate_notification_buffer.buffering_depth > 0
      # Note that if the runtime has been invalidated on exiting the buffering block, then @support_root will be nil
      if previous_last_used_plugin_name != nil && @support_root != nil
        # Only restore last_used_plugin_name if there wasn't an exception, to avoid lying about responsibility
        @support_root.setLastUsedPluginName(previous_last_used_plugin_name)
      end
    end
    # Return the value returned from the yield
    value_from_block
  end

  # For plugin test scripts support
  def _test_get_support_root
    @support_root
  end

  def last_used_plugin_name
    (@support_root == nil) ? nil : @support_root.last_used_plugin_name
  end
  def last_used_plugin_name=(plugin_name)
    @support_root.setLastUsedPluginName(plugin_name) if @support_root != nil
  end

  def make_json_parser
    @runtime.makeJsonParser()
  end

  def kapp_cache_checkout
    raise "Bad state for KJSPluginRuntime" if @support_root != nil
    # Set the SYSTEM user as active during code loading (which could do things like making queries),
    # and when the the onLoad() function is called. Otherwise it's not predictable which user is active,
    # and the plugin may not have sufficient permissions, or schema loading may not be able to see
    # all the objects it needs.
    AuthContext.with_system_user do
      AuthContext.lock_current_state
      # JSSupportRoot implementation requires that a new object is created every time the runtime is checked out
      @support_root = JSSupportRoot.new
      @runtime.useOnThisThread(@support_root) # will evaluate code to load schema
      begin
        # The first time this runtime is checked out, load all the plugins in strict order.
        # This ensures there's a consistent ordering of the plugins inside the runtime, so chaining works as expected.
        unless @plugins_loaded
          ms = Benchmark.ms do
            # Quick check that nothing has been loaded into this runtime yet
            unless 0 == @runtime.host.getNumberOfPluginsRegistered()
              raise "Runtime in bad state - already has plugins registered."
            end
            # Go through each plugin factory, and ask it to load the JavaScript code
            KPlugin.get_plugins_for_current_app.plugin_factories.each do |factory|
              if factory.is_javascript_factory?
                database_namespace = nil
                # Does the plugin require a database?
                if factory.js_info.uses_database
                  # Yes - retrieve/generate a namespace name
                  namespaces = KApp.global(:plugin_db_namespaces) || ''
                  namespaces = YAML::load(namespaces) || {}
                  database_namespace = namespaces[factory.name]
                  if database_namespace == nil
                    # Namespace not set yet - choose a random namespace name
                    safety = 256
                    while true
                      safety -= 1
                      raise "Couldn't allocate database namespace" if safety <= 0
                      database_namespace = KRandom.random_hex(3)
                      break unless namespaces.has_value?(database_namespace)
                    end
                    namespaces[factory.name] = database_namespace
                    KApp.set_global(:plugin_db_namespaces, YAML::dump(namespaces))
                  end
                end
                # Tell the host object to expect a plugin registration.
                # This check prevents unexpected registrations by plugin code, and sets the database namespace for the plugin.
                @runtime.host.setNextPluginToBeRegistered(factory.name, database_namespace)
                KJavaScriptPlugin.reporting_errors(factory.name) do
                  using_runtime do
                    @support_root.setLastUsedPluginName(factory.name) # for blaming plugins
                    factory.javascript_load(@runtime)
                  end
                end
              end
            end
            # Call the plugin's onLoad() functions
            using_runtime do
              @runtime.host.callAllPluginOnLoad()
            end
            # Don't load anything again
            @plugins_loaded = true
          end
          KApp.logger.info("Initialised application JavaScript runtime, took #{ms.to_i}ms\n")
        end
      rescue
        # If there's an exception when loading, reset the state of the runtime so the Java side doesn't think there's a Runtime on this thread
        clear_runtime_run_state
        # and then replace the runtime itself so everything is nice and clean for the next run
        @runtime = Runtime.new
        # then re-raise the error
        raise
      end
    end
  end

  def clear_runtime_run_state
    use_depth = @@invalidate_notification_buffer.buffering_depth
    if use_depth != 0
      JS_PLUGIN_RUNTIME_HEALTH_REPORTER.log_and_report_exception(nil, "Probable logic error: Clearing JavaScript runtime state when use depth = #{use_depth}")
      if KFRAMEWORK_ENV != 'production'
        raise "Invalid use depth when clearing JS runtime state"
      end
    end
    @runtime.stopUsingOnThisThread()
    @support_root.clear
    @support_root = nil
  end

  def kapp_cache_checkin
    clear_runtime_run_state
  end
  alias kapp_cache_invalidated kapp_cache_checkin

  def call_all_hooks(args)
    using_runtime do
      @runtime.host.callHookInAllPlugins(args)
    end
  end

  def make_response(ruby_response, runner)
    js_response = Java::ComOneisJsinterface::KPluginResponse.make(runner.class.instance_variable_get(:@_RESPONSE_FIELDS))
    runner.response_r_to_j(ruby_response, js_response)
    js_response.prepareForUse()
    js_response
  end

  def retrieve_response(ruby_response, js_response, runner)
    runner.response_j_to_r(ruby_response, js_response)
  end

  def get_file_upload_instructions(plugin_name, path)
    using_runtime do
      @runtime.host.getFileUploadInstructions(plugin_name, path)
    end
  end

  def call_request_handler(plugin_name, method, path)
    using_runtime do
      @support_root.setLastUsedPluginName(plugin_name)
      @runtime.host.callRequestHandler(plugin_name, method, path)
    end
  end

  def call_search_result_render(object)
    host = @runtime.host
    return nil unless host.doesAnyPluginRenderSearchResults()
    using_runtime { host.callRenderSearchResult(object) }
  end

  def call_fast_work_unit_render(work_unit, context)
    using_runtime do
      Java::ComOneisJsinterface::KWorkUnit.fastWorkUnitRender(work_unit, context)
    end
  end
  def call_work_unit_render_for_event(event_name, work_unit)
    using_runtime do
      Java::ComOneisJsinterface::KWorkUnit.workUnitRenderForEvent(event_name, work_unit)
    end
  end

end

