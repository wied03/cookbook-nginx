class Chef
  class Provider
    class BswNginxSiteConfig < Chef::Provider::LWRPBase
      include Chef::Mixin::ShellOut

      use_inline_resources

      def whyrun_supported?
        true
      end


    end
  end
end