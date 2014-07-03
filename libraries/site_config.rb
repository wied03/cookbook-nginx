class Chef
  class Resource
    class BswNginxSiteConfig < Chef::Resource
      def initialize(name, run_context=nil)
        super
        @resource_name = 'bsw_nginx_site_config'
        @provider = Chef::Provider::BswNginxSiteConfig
        @action = :create_or_update
        @allowed_actions = [:create_or_update, :nothing]
        @name = name
        @base_path = '/etc/nginx'
        @suppress_output = false
        @variables = {}
        @temporary_resource = false
      end

      def name(arg=nil)
        set_or_return(:name, arg, :kind_of => String)
      end

      def base_path(arg=nil)
        set_or_return(:base_path, arg, :kind_of => String)
      end

      def variables(arg=nil)
        set_or_return(:variables, arg, :kind_of => Hash)
      end

      def suppress_output(arg=nil)
        set_or_return(:suppress_output, arg, :kind_of => [TrueClass, FalseClass])
      end

      def temporary_resource(arg=nil)
        set_or_return(:temporary_resource, arg, :kind_of => [TrueClass, FalseClass])
      end

      # We don't want to indicate as an updated resource if we're just being used for temporary purposes
      def updated_by_last_action?
        temporary_resource ? false : super
      end

      # Influencing lwrp_base's check for inline resources
      def updated?
        updated_by_last_action?
      end
    end
  end
end