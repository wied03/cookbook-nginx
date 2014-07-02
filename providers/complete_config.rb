def whyrun_supported?
  true
end

use_inline_resources

def top_level_config_files
  cookbook = run_context.cookbook_collection[@new_resource.cookbook_name]
  begin
    return cookbook.relative_filenames_in_preferred_directory(node, :templates, node.environment)
  rescue Chef::Exceptions::FileNotFound
    Chef::Log.warn 'No NGINX site config files were found!'
    return []
  end
end


action :create_or_update do
  test_config_path = Dir.mktmpdir
  validation_command = "/usr/sbin/nginx -c /tmp/temp_file_0/nginx.conf -t"
  top_level_config_files.each do |config|
    # These are template files but we want the real name
    without_erb = ::File.basename(config,'.erb')
    tmp_path = ::File.join(test_config_path, without_erb)
    env_aware_template tmp_path
    env_aware_template ::File.join('/etc/nginx',without_erb) do
      only_if validation_command
    end
  end

  bsw_nginx_site_config 'test site config' do
    base_path test_config_path
  end

  bsw_nginx_site_config 'real site config' do
    only_if validation_command
  end

  new_resource.updated_by_last_action(true)
end