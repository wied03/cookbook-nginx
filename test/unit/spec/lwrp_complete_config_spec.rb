# Encoding: utf-8

require_relative 'spec_helper'

describe 'bsw_nginx::lwrp:complete_config' do
  def setup_mock_sites(sites, create_main_config=true)
    template_dir = File.join cookbook_path, 'templates', 'default', environment_name
    FileUtils.mkdir_p template_dir
    [*sites].each do |site_name|
      site_dir = File.join template_dir, 'sites'
      FileUtils.mkdir_p site_dir
      site_filename = File.join site_dir, "#{site_name}.erb"
      FileUtils.touch site_filename
    end
    if create_main_config
      config_path = File.join template_dir, 'nginx.conf.erb'
      FileUtils.touch config_path
    end
  end

  include BswTech::ChefSpec::LwrpTestHelper

  before {
    stub_resources
    @stub_setup = nil
    original_new = Mixlib::ShellOut.method(:new)
    Mixlib::ShellOut.stub!(:new) do |*args|
      cmd = original_new.call(*args)
      cmd.stub!(:run_command)
      @stub_setup.call(cmd) if @stub_setup
      cmd
    end
    @open_tempfiles = []
    @written_to_files = {}
    Dir::Tmpname.stub!(:create) do
      name = "temp_file_#{@open_tempfiles.length}"
      @open_tempfiles << name
      name
    end
    Tempfile.stub!(:new) do |prefix|
      temp_file_stub = double()
      name = "temp_file_#{@open_tempfiles.length}"
      @open_tempfiles << name
      temp_file_stub.stub!(:path).and_return "/path/to/#{name}"
      temp_file_stub.stub!(:close)
      temp_file_stub.stub!(:unlink)
      temp_file_stub.stub!(:'<<') do |text|
        @written_to_files[name] = text
      end
      temp_file_stub
    end
    ::File.stub!(:exist?).and_call_original
    ::File.stub!(:exist?).with('temp_file_0').and_return(true)
  }

  after(:each) {
    cleanup
  }

  def cookbook_under_test
    'bsw_nginx'
  end

  def lwrps_under_test
    'complete_config'
  end

  def setup_recipe(sites, contents)
    setup_mock_sites sites
    temp_lwrp_recipe contents
  end

  def stub_existing_sites(sites)
    # dir will always include this
    complete = ['.', '..'] + sites
    Dir.stub(:entries).and_call_original
    Dir.stub(:entries).with('/etc/nginx/sites-enabled').and_return complete
    Dir.stub(:entries).with('/etc/nginx/sites-available').and_return complete
  end

  it 'works properly with no variables and 1 site and a valid config' do
    # arrange
    executed = []
    @stub_setup = lambda do |shell_out|
      case shell_out.command
        when '/usr/sbin/nginx -c /tmp/temp_file_0/nginx.conf -t'
          shell_out.stub(:error!)
        else
          shell_out.stub(:error!).and_raise "Unexpected command #{shell_out.command}"
      end
    end
    stub_existing_sites []
    setup_recipe 'site1', <<-EOF
        include_recipe 'bsw_nginx::default'
        bsw_nginx_site_config 'site config'
    EOF

    # act + assert
    # 1 real, 1 testing
    expect(@chef_run.find_resources('template')).to have(2).items
    resources_to_check = [@chef_run.find_resource('template', '/tmp/temp_file_0//sites-available/site1'),
                          @chef_run.find_resource('template', '/etc/nginx/sites-available/site1')]
    resources_to_check.each do |resource|
      expect(resource.variables).to eq({})
      expect(resource.source).to eq 'thestagingenv/sites/site1.erb'
    end
    resource = @chef_run.find_resource('link', '/etc/nginx/sites-enabled/site1')
    expect(resource.to).to eq('/etc/nginx/sites-available/site1')
    resource = @chef_run.find_resource 'bsw_nginx_site_config', 'site config'
    expect(resource.updated_by_last_action?).to be_true
  end

  it 'works properly with variables and 1 site and a valid config' do
    # arrange
    stub_existing_sites []
    setup_recipe 'site1', <<-EOF
      include_recipe 'bsw_nginx::default'
      bsw_nginx_site_config 'site config' do
        variables({:stuff => 'foobar'})
      end
    EOF

    # act + assert
    expect(@chef_run.find_resources('template')).to have(1).items
    resource = @chef_run.find_resource('template', '/etc/nginx/sites-available/site1')
    expect(resource.variables).to eq(:stuff => 'foobar')
    expect(resource.source).to eq 'thestagingenv/sites/site1.erb'
    expect(resource).to notify('bash[nginx config test]').to(:run).delayed
    expect(resource).to notify('service[nginx config reload]').to(:reload).delayed
    resource = @chef_run.find_resource('link', '/etc/nginx/sites-enabled/site1')
    expect(resource.to).to eq('/etc/nginx/sites-available/site1')
  end

  it 'works properly with multiple sites and a valid config' do
    # arrange
    stub_existing_sites []
    setup_recipe ['site1', 'site2'], <<-EOF
      include_recipe 'bsw_nginx::default'
      bsw_nginx_site_config 'site config'
    EOF

    # act + assert
    expect(@chef_run.find_resources('template')).to have(2).items
    resource = @chef_run.find_resource('template', '/etc/nginx/sites-available/site1')
    expect(resource.variables).to eq({})
    expect(resource.source).to eq 'thestagingenv/sites/site1.erb'
    expect(resource).to notify('bash[nginx config test]').to(:run).delayed
    expect(resource).to notify('service[nginx config reload]').to(:reload).delayed
    resource = @chef_run.find_resource('link', '/etc/nginx/sites-enabled/site1')
    expect(resource.to).to eq('/etc/nginx/sites-available/site1')
    resource = @chef_run.find_resource('template', '/etc/nginx/sites-available/site2')
    expect(resource.variables).to eq({})
    expect(resource).to notify('bash[nginx config test]').to(:run).delayed
    expect(resource).to notify('service[nginx config reload]').to(:reload).delayed
    resource = @chef_run.find_resource('link', '/etc/nginx/sites-enabled/site2')
    expect(resource.to).to eq('/etc/nginx/sites-available/site2')
  end

  it 'replaces sites that exist already and a valid config' do
    # arrange
    stub_existing_sites ['site1', 'site2']
    setup_recipe ['site1', 'site2'], <<-EOF
      include_recipe 'bsw_nginx::default'
      bsw_nginx_site_config 'site config'
    EOF

    # act + assert
    expect(@chef_run.find_resources('template')).to have(2).items
    # Only the template will be used, we're only using file to delete sites we don't need anymore
    expect(@chef_run.find_resources('file')).to have(0).items
    # Only the create links should be used
    expect(@chef_run.find_resources('link')).to have(2).items
    resource = @chef_run.find_resource('template', '/etc/nginx/sites-available/site1')
    expect(resource.variables).to eq({})
    expect(resource.source).to eq 'thestagingenv/sites/site1.erb'
    expect(resource).to notify('bash[nginx config test]').to(:run).delayed
    expect(resource).to notify('service[nginx config reload]').to(:reload).delayed
    resource = @chef_run.find_resource('link', '/etc/nginx/sites-enabled/site1')
    expect(resource.to).to eq('/etc/nginx/sites-available/site1')
    resource = @chef_run.find_resource('template', '/etc/nginx/sites-available/site2')
    expect(resource.variables).to eq({})
    expect(resource).to notify('bash[nginx config test]').to(:run).delayed
    expect(resource).to notify('service[nginx config reload]').to(:reload).delayed
    resource = @chef_run.find_resource('link', '/etc/nginx/sites-enabled/site2')
    expect(resource.to).to eq('/etc/nginx/sites-available/site2')
  end

  it 'removes sites that are no longer configured and a valid config' do
    # arrange
    stub_existing_sites ['site3', 'site4']
    setup_recipe ['site1', 'site2'], <<-EOF
      include_recipe 'bsw_nginx::default'
      bsw_nginx_site_config 'site config'
    EOF

    # act + assert
    expect(@chef_run.find_resources('template')).to have(2).items
    # Should have 1 file delete per each removed site
    expect(@chef_run.find_resources('file')).to have(2).items
    # should have 2 creates and 2 deletes
    expect(@chef_run.find_resources('link')).to have(4).items
    resource = @chef_run.find_resource('template', '/etc/nginx/sites-available/site1')
    expect(resource.variables).to eq({})
    expect(resource.source).to eq 'thestagingenv/sites/site1.erb'
    expect(resource).to notify('bash[nginx config test]').to(:run).delayed
    expect(resource).to notify('service[nginx config reload]').to(:reload).delayed
    resource = @chef_run.find_resource('link', '/etc/nginx/sites-enabled/site1')
    expect(resource.to).to eq('/etc/nginx/sites-available/site1')
    resource = @chef_run.find_resource('template', '/etc/nginx/sites-available/site2')
    expect(resource.variables).to eq({})
    expect(resource).to notify('bash[nginx config test]').to(:run).delayed
    expect(resource).to notify('service[nginx config reload]').to(:reload).delayed
    resource = @chef_run.find_resource('link', '/etc/nginx/sites-enabled/site2')
    expect(resource.to).to eq('/etc/nginx/sites-available/site2')
    resource = @chef_run.find_resource('file', '/etc/nginx/sites-available/site3')
    expect(resource.action).to eq [:delete]
    resource = @chef_run.find_resource('link', '/etc/nginx/sites-enabled/site3')
    expect(resource.action).to eq [:delete]
    resource = @chef_run.find_resource('file', '/etc/nginx/sites-available/site4')
    expect(resource.action).to eq [:delete]
    resource = @chef_run.find_resource('link', '/etc/nginx/sites-enabled/site4')
    expect(resource.action).to eq [:delete]
  end

  it 'complains without a main nginx config file in the templates directory' do
    # arrange

    # act

    # assert
    pending 'Write this test'
  end

  it 'does not change anything if the config is not valid' do
    # arrange
    stub_existing_sites []
    setup_recipe 'site1', <<-EOF
            include_recipe 'bsw_nginx::default'
            bsw_nginx_site_config 'site config'
    EOF

    # act + assert
    expect(@chef_run.find_resources('template')).to have(1).items
    resource = @chef_run.find_resource('template', '/etc/nginx/sites-available/site1')
    expect(resource.variables).to eq({})
    expect(resource.source).to eq 'thestagingenv/sites/site1.erb'
    expect(resource).to notify('bash[nginx config test]').to(:run).delayed
    expect(resource).to notify('service[nginx config reload]').to(:reload).delayed
    resource = @chef_run.find_resource('link', '/etc/nginx/sites-enabled/site1')
    expect(resource.to).to eq('/etc/nginx/sites-available/site1')

    # act

    # assert
    pending 'Write this test'
  end
end
