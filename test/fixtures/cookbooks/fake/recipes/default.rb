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

bsw_nginx_complete_config 'the config'

service 'nginx' do
  action [:enable, :start]
end