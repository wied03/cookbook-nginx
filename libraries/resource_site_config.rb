class Chef
  class Resource
    class BswNginxSiteConfig < Chef::Resource::LWRPBase
      actions [:create_or_update, :nothing]
      attribute :base_path, :kind_of => String, :default => '/etc/nginx'
      attribute :variables, :kind_of => Hash, :default => {}
      attribute :suppress_output, :kind_of => [TrueClass, FalseClass], :default => false

      self.resource_name = :bsw_nginx_site_config
      self.default_action :create_or_update
    end
  end
end