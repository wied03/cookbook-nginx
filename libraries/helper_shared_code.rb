module BswTech
  module Nginx
    module Shared
      def create_site_config_tmp_files(tmp_path)
        avail_dir = ::File.join(tmp_path, 'sites-available')
        link_dir = ::File.join(tmp_path, 'sites-enabled')
        directory avail_dir
        directory link_dir

        get_site_config_files.each do |r|
          next if ::File.extname(r) != '.erb'
          template_without_extension = ::File.basename r, '.erb'
          avail = ::File.join(avail_dir, template_without_extension)
          write_temporary_template ::File.join('sites', "#{::File.basename(avail)}"), avail
          link_path = ::File.join(link_dir, template_without_extension)
          shell_out "ln -s #{link_path} #{avail}"
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