def whyrun_supported?
  true
end

use_inline_resources

action :create_or_update do
  t = template @new_resource.filename do
    variables new_resource.variables if new_resource.variables
    source ::File.join(node.chef_environment, "#{::File.basename(name)}.erb")
  end
  new_resource.updated_by_last_action(t.updated_by_last_action?)
end