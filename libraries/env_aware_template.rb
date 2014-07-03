class Chef
  class Resource
    class EnvAwareTemplate < Template
      def initialize(name, run_context=nil)
        super
        @source = get_env_specific_source @source
        @temporary_resource = false
      end

      def get_env_specific_source(source_filename)
        ::File.join(node.chef_environment,source_filename)
      end

      def source(source_filename=nil)
        # This is used both as an accessor and mutator
        args = source_filename ? get_env_specific_source(source_filename) : nil
        super args
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