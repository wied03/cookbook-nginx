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

def run_command(*args)
  cmd = Mixlib::ShellOut.new(*args)
  cmd.run_command
  cmd.error!
  cmd
end

def create_temporary_files(template_top_level_files, test_config_path)
  # These are template files but we want the real name
  template_top_level_files.each do |config|
    tmp_main_config_path = ::File.join(test_config_path, config)
    resource = env_aware_template tmp_main_config_path do
      variables new_resource.variables if new_resource.variables
      # Only create the temp files right now, don't run this later
      action :nothing
      sensitive true
    end
    resource.run_action :create
  end

  resource = bsw_nginx_site_config 'test site config' do
    base_path test_config_path
    variables new_resource.variables if new_resource.variables
    # Only create the temp files right now, don't run this later
    action :nothing
    suppress_output true
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
    run_command "/usr/sbin/nginx -c #{test_main_config} -t"
  ensure
    ::FileUtils.rm_rf test_config_path
  end
end

action :create_or_update do
  top_level_template_files = top_level_config_files.map { |f| ::File.basename(f, '.erb') }
  validate_configuration(top_level_template_files)

  resources_that_trigger_update = []
  top_level_template_files.each do |config|
    resource = env_aware_template ::File.join('/etc/nginx', config) do
      variables new_resource.variables if new_resource.variables
    end
    resources_that_trigger_update << resource
  end

  resource = bsw_nginx_site_config 'real site config' do
    variables new_resource.variables if new_resource.variables
  end

  resources_that_trigger_update << resource

  # Easier to test
  checker = BswTech::ComplexUpdateChecker.new
  new_resource.updated_by_last_action(resources_that_trigger_update.any? { |r| checker.updated_by_last_action?(r) })
end