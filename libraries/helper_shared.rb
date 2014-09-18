module BswTech
  module Nginx
    module Shared
      def get_site_config_files
        cookbook = run_context.cookbook_collection[@new_resource.cookbook_name]
        sub_dir = ::File.join(node.environment, 'sites')
        begin
          return cookbook.relative_filenames_in_preferred_directory(node, :templates, sub_dir)
        rescue Chef::Exceptions::FileNotFound
          Chef::Log.warn 'No NGINX site config files were found!'
          return []
        end
      end

      def get_merged_variables(site_filename)
        site_name = ::File.basename(site_filename, '.conf')
        @new_resource.variables.merge({:site_name => site_name})
      end
    end
  end
end