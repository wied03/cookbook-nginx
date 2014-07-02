actions :create_or_update
default_action :create_or_update

attribute :name, :kind_of => String, :name_attribute => true
attribute :variables, :kind_of => Hash
attribute :base_path, :kind_of => String, :default => '/etc/nginx'
