actions :create_or_update
default_action :create_or_update

attribute :filename, :kind_of => String, :name_attribute => true
attribute :variables, :kind_of => Hash