# Test kitchen disables selinux by default but we need to ensure our stuff works properly with it
include_recipe 'selinux::enforcing'

package 'epel-release'
package 'nginx'

directory '/var/www/my_app/current/public' do
  recursive true
end

file '/var/www/my_app/current/public/index.html' do
  content 'hello world from bsw'
end

file '/tmp/notify_test' do
  action :nothing
  content 'we got notified!'
end

bsw_nginx_complete_config 'the config' do
  notifies :create, 'file[/tmp/notify_test]', :delayed
end

service 'nginx' do
  action [:enable, :start]
end