class Chef
  class Resource
    class EnvAwareTemplate < Template
      def initialize(name, run_context=nil)
        super
        @source = get_env_specific_source @source
      end

      def get_env_specific_source(source_filename)
        ::File.join(node.chef_environment,source_filename)
      end

      def source(source_filename=nil)
        # This is used both as an accessor and mutator
        args = source_filename ? get_env_specific_source(source_filename) : nil
        super args
      end
    end
  end
end