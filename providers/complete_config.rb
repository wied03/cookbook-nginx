def whyrun_supported?
  true
end

use_inline_resources

action :create_or_update do
  test_config_path = Dir.mktmpdir
  bsw_nginx_site_config 'test site config' do
    base_path test_config_path
  end
  test_main_config = ::File.join(test_config_path, 'nginx.conf')
  validation_command = "/usr/sbin/nginx -c #{test_main_config} -t"
  bsw_nginx_site_config 'real site config' do
    only_if validation_command
  end
  env_aware_template test_main_config
  env_aware_template '/etc/nginx.conf' do
    only_if validation_command
  end

  new_resource.updated_by_last_action(true)
end