def whyrun_supported?
  true
end

use_inline_resources
include BswTech::DelayedApply

action :create_or_update do
  trigger_delayed_apply
end

action :apply do
  svc = service 'nginx' do
    supports :reload => true, :configtest => true
    action :nothing
  end
  deferred_resources.each do |r|
    nginx_base = ::File.join('/','etc','nginx')
    avail = ::File.join(nginx_base,'sites-available',r.name)
    template avail do
      notifies :configtest, svc, :delayed
      notifies :reload, svc, :delayed
    end
    link ::File.join(nginx_base,'sites-enabled',r.name) do
      to avail
      action :create
    end
  end
end