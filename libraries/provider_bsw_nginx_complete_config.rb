require 'tempfile'

class Chef
  class Provider
    class BswNginxCompleteConfig < Chef::Provider::LWRPBase
      include Chef::Mixin::ShellOut
      include BswTech::Nginx::Shared

      use_inline_resources

      def whyrun_supported?
        true
      end

      def action_create_or_update
        validate_configuration(top_level_config_files)
        merged_variables = get_variables @new_resource.base_path
        top_level_config_files.each do |config|
          without_erb = ::File.basename(config, '.erb')
          env_aware_template ::File.join(@new_resource.base_path, without_erb) do
            variables merged_variables
          end
        end
        bsw_nginx_site_config 'site config' do
          variables merged_variables
        end
      end

      private

      def create_temporary_files(template_top_level_files, test_config_path)
        # These are template files but we want the real name
        merged_variables = get_variables test_config_path
        temp = BswTech::ManualTemplate.new run_context
        template_top_level_files.each do |config_file|
          temp.write_with_variables cookbook_name, config_file, merged_variables, test_config_path
        end
        create_site_config_tmp_files test_config_path
      end

      def validate_configuration(top_level_template_files)
        test_config_path = Dir.mktmpdir
        begin
          # These are template files but we want the real name
          unless top_level_template_files.include? 'nginx.conf.erb'
            fail "You must have a top level nginx.conf.erb file in your templates/default/env directory.  You only have #{top_level_template_files}"
          end
          create_temporary_files top_level_template_files, test_config_path
          pidfile = Tempfile.new('nginx_test.pid')
          pidfile.close
          # Our test will leave a PID hanging around with root ownership if we don't sub it in, this causes problems for SELinux machines
          test_main_config = ::File.join(test_config_path, 'nginx.conf')
          replace_pid_in_config_file test_main_config, pidfile.path
          begin
            shell_out! "#{@new_resource.nginx_binary} -c #{test_main_config} -t"
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