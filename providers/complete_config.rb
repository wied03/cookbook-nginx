def whyrun_supported?
  true
end

use_inline_resources

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

def create_temporary_files(template_top_level_files, test_config_path)
  # These are template files but we want the real name
  template_top_level_files.each do |config|
    tmp_main_config_path = ::File.join(test_config_path, config)
    env_aware_template tmp_main_config_path do
      variables new_resource.variables if new_resource.variables
    end
  end

  bsw_nginx_site_config 'test site config' do
    base_path test_config_path
    variables new_resource.variables if new_resource.variables
  end
end

action :create_or_update do
  test_config_path = Dir.mktmpdir
  # These are template files but we want the real name
  top_level = top_level_config_files.map { |f| ::File.basename(f, '.erb') }
  unless top_level.include? 'nginx.conf'
    fail "You must have a top level nginx.conf file in your templates/default/env directory.  You only have #{top_level}"
  end
  test_main_config = ::File.join(test_config_path, 'nginx.conf')
  create_temporary_files top_level, test_config_path
  validation_command = "/usr/sbin/nginx -c #{test_main_config} -t"
  resources_that_trigger_update = []
  top_level.each do |config|
    resource = env_aware_template ::File.join('/etc/nginx', config) do
      only_if validation_command
      variables new_resource.variables if new_resource.variables
    end
    resources_that_trigger_update << resource
  end

  resource = bsw_nginx_site_config 'real site config' do
    only_if validation_command
    variables new_resource.variables if new_resource.variables
  end

  resources_that_trigger_update << resource

  # Easier to test
  checker = BswTech::ComplexUpdateChecker.new
  new_resource.updated_by_last_action(resources_that_trigger_update.any? { |r| checker.updated_by_last_action?(r) })
end