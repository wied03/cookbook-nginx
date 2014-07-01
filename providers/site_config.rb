def whyrun_supported?
  true
end

use_inline_resources

def get_site_config_files
  cookbook = run_context.cookbook_collection[@new_resource.cookbook_name]
  sub_dir = ::File.join(node.environment,'sites')
  cookbook.relative_filenames_in_preferred_directory(node, :templates, sub_dir)
end

action :create_or_update do
  svc = service 'nginx' do
    supports :reload => true, :configtest => true
    action :nothing
  end
  get_site_config_files.each do |r|
    template_without_extension = ::File.basename r, '.erb'
    nginx_base = ::File.join('/','etc','nginx')
    avail = ::File.join(nginx_base,'sites-available',template_without_extension)
    template avail do
      variables new_resource.variables if new_resource.variables
      notifies :configtest, svc, :delayed
      notifies :reload, svc, :delayed
    end
    link ::File.join(nginx_base,'sites-enabled',template_without_extension) do
      to avail
      action :create
    end
  end
end