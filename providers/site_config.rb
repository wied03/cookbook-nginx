def whyrun_supported?
  true
end

use_inline_resources

def get_site_config_files
  cookbook = run_context.cookbook_collection[@new_resource.cookbook_name]
  sub_dir = ::File.join(node.environment, 'sites')
  cookbook.relative_filenames_in_preferred_directory(node, :templates, sub_dir)
end

action :create_or_update do
  svc_reload = service 'nginx config reload' do
    service_name 'nginx'
    supports :reload => true, :configtest => true
    action :nothing
    only_if 'service nginx status'
  end
  configtest = bash 'nginx config test' do
    code 'service nginx configtest'
    action :nothing
  end
  valid_sites = []
  nginx_base = ::File.join('/', 'etc', 'nginx')
  avail_dir = ::File.join(nginx_base, 'sites-available')
  link_dir = ::File.join(nginx_base, 'sites-enabled')
  get_site_config_files.each do |r|
    template_without_extension = ::File.basename r, '.erb'
    avail = ::File.join(avail_dir, template_without_extension)
    valid_sites << template_without_extension
    template avail do
      variables new_resource.variables if new_resource.variables
      notifies :run, configtest, :delayed
      notifies :reload, svc_reload, :delayed
      source ::File.join(node.chef_environment, 'sites', "#{::File.basename(name)}.erb")
    end
    link_path = ::File.join(link_dir, template_without_extension)
    link link_path do
      to avail
      action :create
    end
  end
  dir_returns_these_but_we_dont_care_about_them = ['.', '..']
  invalid_sites = ::Dir.entries(avail_dir) - dir_returns_these_but_we_dont_care_about_them - valid_sites
  invalid_sites.each do |site|
    link ::File.join(link_dir, site) do
      action :delete
    end

    file ::File.join(avail_dir, site) do
      action :delete
    end
  end
end