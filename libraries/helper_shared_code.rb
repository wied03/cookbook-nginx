module BswTech
  module Nginx
    module Shared
      def create_site_config_tmp_files(tmp_path)
        available_link = ::File.join(tmp_path, 'sites-available')
        link_dir = ::File.join(tmp_path, 'sites-enabled')
        directory available_link
        directory link_dir

        get_site_config_files.each do |config_file|
          next if ::File.extname(config_file) != '.erb'
          config_file_without_template_extension = ::File.basename config_file, '.erb'
          write_temporary_template ::File.join('sites', "#{::File.basename(config_file)}"), available_link
          link_path = ::File.join(link_dir, config_file_without_template_extension)
          available_link_path = ::File.join(available_link, config_file_without_template_extension)
          shell_out "ln -s #{link_path} #{available_link_path}"
        end
      end

      private

      def write_temporary_template(source_file, destination)
        temp = BswTech::ManualTemplate.new run_context
        temp.write_with_variables cookbook_name, source_file, @new_resource.variables, destination
      end

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
    end
  end
end