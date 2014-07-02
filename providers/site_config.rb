def whyrun_supported?
  true
end

use_inline_resources

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

action :create_or_update do
  valid_sites = []
  avail_dir = ::File.join(@new_resource.base_path, 'sites-available')
  link_dir = ::File.join(@new_resource.base_path, 'sites-enabled')
  directory avail_dir
  directory link_dir

  resources = []
  get_site_config_files.each do |r|
    template_without_extension = ::File.basename r, '.erb'
    avail = ::File.join(avail_dir, template_without_extension)
    valid_sites << template_without_extension
    resource = template avail do
      variables new_resource.variables if new_resource.variables
      source ::File.join(node.chef_environment, 'sites', "#{::File.basename(name)}.erb")
    end
    resources << resource
    link_path = ::File.join(link_dir, template_without_extension)
    resource = link link_path do
      to avail
      action :create
    end
    resources << resource
  end
  dir_returns_these_but_we_dont_care_about_them = ['.', '..']
  # Can't have any invalid ones if directory isn't there to start with
  # TODO: Unit test this
  #invalid_sites = ::Dir.exists?(avail_dir) ? ::Dir.entries(avail_dir) - dir_returns_these_but_we_dont_care_about_them - valid_sites : []
  invalid_sites = ::Dir.entries(avail_dir) - dir_returns_these_but_we_dont_care_about_them - valid_sites
  invalid_sites.each do |site|
    resource = link ::File.join(link_dir, site) do
      action :delete
    end
    resources << resource

    resource = file ::File.join(avail_dir, site) do
      action :delete
    end
    resources << resource
  end

  new_resource.updated_by_last_action(resources.any? {|r| r.updated_by_last_action?})
end