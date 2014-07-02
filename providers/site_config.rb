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
  valid_sites = []
  nginx_base = ::File.join('/', 'etc', 'nginx')
  avail_dir = ::File.join(nginx_base, 'sites-available')
  link_dir = ::File.join(nginx_base, 'sites-enabled')
  resources = []
  get_site_config_files.each do |r|
    template_without_extension = ::File.basename r, '.erb'
    avail = ::File.join(avail_dir, template_without_extension)
    valid_sites << template_without_extension
    t = template avail do
      variables new_resource.variables if new_resource.variables
      source ::File.join(node.chef_environment, 'sites', "#{::File.basename(name)}.erb")
    end
    resources << t
    link_path = ::File.join(link_dir, template_without_extension)
    link link_path do
      to avail
      action :create
    end
  end
  dir_returns_these_but_we_dont_care_about_them = ['.', '..']
  invalid_sites = ::Dir.entries(avail_dir) - dir_returns_these_but_we_dont_care_about_them - valid_sites
  invalid_sites.each do |site|
    lnk = link ::File.join(link_dir, site) do
      action :delete
    end
    resources << lnk

    file_delete = file ::File.join(avail_dir, site) do
      action :delete
    end
    resources << file_delete
  end

  new_resource.updated_by_last_action(resources.any? {|r| r.updated_by_last_action?})
end