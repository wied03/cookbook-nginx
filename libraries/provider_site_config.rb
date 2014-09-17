class Chef
  class Provider
    class BswNginxSiteConfig < Chef::Provider::LWRPBase
      include Chef::Mixin::ShellOut
      include BswTech::Nginx::Shared

      use_inline_resources

      def whyrun_supported?
        true
      end

      def action_create_or_update
        directory available_sites_dir
        directory enabled_sites_link_dir

        get_site_config_files.each do |config_file|
          next if ::File.extname(config_file) != '.erb'
          config_file_without_template_extension = ::File.basename config_file, '.erb'
          avail_site_target_file = ::File.join(available_sites_dir, config_file_without_template_extension)
          our_resource = @new_resource
          env_aware_template avail_site_target_file do
            variables our_resource.variables if our_resource.variables
            source ::File.join('sites', ::File.basename(config_file))
            sensitive true if our_resource.suppress_output
          end
          link ::File.join(enabled_sites_link_dir, config_file_without_template_extension) do
            to avail_site_target_file
            action :create
          end
        end
        get_sites_to_remove.each do |site|
          link ::File.join(enabled_sites_link_dir, site) do
            action :delete
          end
          file ::File.join(available_sites_dir, site) do
            action :delete
          end
        end
      end

      private

      def enabled_sites_link_dir
        ::File.join(@new_resource.base_path, 'sites-enabled')
      end

      def available_sites_dir
        ::File.join(@new_resource.base_path, 'sites-available')
      end

      def get_sites_to_remove
        return [] unless ::Dir.exists?(available_sites_dir)
        ::Dir.entries(available_sites_dir) - ['.', '..'] - sites_being_installed
      end

      def sites_being_installed
        get_site_config_files.map { |s| ::File.basename s, '.erb' }
      end
    end
  end
end
