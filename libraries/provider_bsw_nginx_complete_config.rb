require 'tempfile'

class Chef
  class Provider
    class BswNginxCompleteConfig < Chef::Provider::LWRPBase
      include Chef::Mixin::ShellOut

      use_inline_resources

      def whyrun_supported?
        true
      end

      def action_create_or_update
        merged_variables = get_variables @new_resource.base_path
        top_level_template_files = top_level_config_files.map { |f| ::File.basename(f, '.erb') }
        validate_configuration(top_level_template_files)

        resources_that_trigger_update = []
        top_level_template_files.each do |config|
          resource = env_aware_template ::File.join(@new_resource.base_path, config) do
            variables merged_variables
          end
          resources_that_trigger_update << resource
        end

        resource = bsw_nginx_site_config 'real site config' do
          variables merged_variables
        end

        resources_that_trigger_update << resource
      end

      private

      def create_temporary_files(template_top_level_files, test_config_path)
        # These are template files but we want the real name
        merged_variables = get_variables test_config_path
        template_top_level_files.each do |config|
          tmp_main_config_path = ::File.join(test_config_path, config)
          resource = env_aware_template tmp_main_config_path do
            variables merged_variables
            # Only create the temp files right now, don't run this later
            action :nothing
            sensitive true
            temporary_resource true
          end
          resource.run_action :create
        end

        resource = bsw_nginx_site_config 'test site config' do
          base_path test_config_path
          variables merged_variables
          # Only create the temp files right now, don't run this later
          action :nothing
          suppress_output true
          temporary_resource true
        end
        resource.run_action :create_or_update
      end

      def validate_configuration(top_level_template_files)
        test_config_path = Dir.mktmpdir
        begin
          # These are template files but we want the real name
          unless top_level_template_files.include? 'nginx.conf'
            fail "You must have a top level nginx.conf file in your templates/default/env directory.  You only have #{top_level_template_files}"
          end
          test_main_config = ::File.join(test_config_path, 'nginx.conf')
          create_temporary_files top_level_template_files, test_config_path
          pidfile = Tempfile.new('nginx_test.pid')
          pidfile.close
          # Our test will leave a PID hanging around with root ownership if we don't sub it in, this causes problems for SELinux machines
          replace_pid_in_config_file test_main_config, pidfile.path
          begin
            shell_out "/usr/sbin/nginx -c #{test_main_config} -t"
          ensure
            pidfile.unlink
          end
        ensure
          ::FileUtils.rm_rf test_config_path
        end
      end

      def replace_pid_in_config_file(config_file, pid_file_to_use)
        config_bits = ::File.read(config_file)
        config_bits.gsub!(/pid\s+\S+\s*;/, "pid #{pid_file_to_use};")
        ::File.open config_file, 'w' do |file|
          file << config_bits
        end
      end

      def get_variables(base_nginx_path)
        {:nginx_config_path => base_nginx_path}.merge(@new_resource.variables || {})
      end

      def top_level_config_files
        cookbook = run_context.cookbook_collection[@new_resource.cookbook_name]
        begin
          all_files = cookbook.relative_filenames_in_preferred_directory(node, :templates, node.environment)
          return all_files.reject do |file|
            is_site_file = false
            ::Pathname.new(file).descend { |d|
              is_site_file = true if d.to_path == 'sites'
            }
            is_site_file
          end
        rescue Chef::Exceptions::FileNotFound
          Chef::Log.warn 'No NGINX site config files were found!'
          return []
        end
      end
    end
  end
end