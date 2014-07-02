# Encoding: utf-8

require_relative 'spec_helper'

describe 'bsw_nginx::lwrp:complete_config' do
  def setup_mock_config_files(other_files)
    # Chef returns files in subdirectories as well
    files = ['sites/ignore.this']
    files = files + [*other_files]
    template_dir = File.join cookbook_path, 'templates', 'default', environment_name
    FileUtils.mkdir_p template_dir
    files.each do |other_file|
      site_filename = File.join template_dir, "#{other_file}.erb"
      FileUtils.mkdir_p File.dirname(site_filename)
      FileUtils.touch site_filename
    end
  end

  include BswTech::ChefSpec::LwrpTestHelper

  before {
    stub_resources
    @open_tempfiles = []
    @written_to_files = {}
    Dir.stub(:mktmpdir) do
      name = "/tmp/temp_file_#{@open_tempfiles.length}"
      @open_tempfiles << name
      name
    end
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

  def force_validation_to(option)
    stub_command('/usr/sbin/nginx -c /tmp/temp_file_0/nginx.conf -t').and_return(option == :pass)
  end

  it 'creates all resources with a valid config' do
    # arrange
    force_validation_to :pass
    setup_mock_config_files 'nginx.conf'

    # act
    temp_lwrp_recipe <<-EOF
      bsw_nginx_complete_config 'the config'
    EOF

    # assert
    @chef_run.should render_file '/tmp/temp_file_0/nginx.conf'
    @chef_run.should render_file '/etc/nginx/nginx.conf'
    resource = @chef_run.find_resource 'bsw_nginx_site_config', 'real site config'
    resource.should_not be_nil
    resource.base_path.should == '/etc/nginx'
    resource = @chef_run.find_resource 'bsw_nginx_site_config', 'test site config'
    resource.should_not be_nil
    resource.base_path.should == '/tmp/temp_file_0'
  end

  it 'does not execute real config resources if validation fails' do
    # arrange
    force_validation_to :fail
    setup_mock_config_files 'nginx.conf'

    # act
    temp_lwrp_recipe <<-EOF
      bsw_nginx_complete_config 'the config'
    EOF

    # assert
    @chef_run.should render_file '/tmp/temp_file_0/nginx.conf'
    @chef_run.should_not render_file '/etc/nginx/nginx.conf'
    resource = @chef_run.find_resource 'bsw_nginx_site_config', 'real site config'
    resource.performed_actions.should be_empty
    resource = @chef_run.find_resource 'bsw_nginx_site_config', 'test site config'
    resource.should_not be_nil
    resource.base_path.should == '/tmp/temp_file_0'
  end

  it 'works properly with more than 1 top level config file' do
    # arrange
    force_validation_to :pass
    setup_mock_config_files ['nginx.conf', 'some.other.file']

    # act
    temp_lwrp_recipe <<-EOF
      bsw_nginx_complete_config 'the config'
    EOF

    # assert
    @chef_run.should render_file '/tmp/temp_file_0/nginx.conf'
    @chef_run.should render_file '/etc/nginx/nginx.conf'
    @chef_run.should render_file '/tmp/temp_file_0/some.other.file'
    @chef_run.should render_file '/etc/nginx/some.other.file'
  end

  it 'works properly with variables' do
    # arrange
    force_validation_to :pass
    setup_mock_config_files 'nginx.conf'

    # act
    temp_lwrp_recipe <<-EOF
      bsw_nginx_complete_config 'the config' do
        variables({:stuff => 'foobar'})
      end
    EOF

    # assert
    verify_var = lambda do |resource_type,name|
      resource = @chef_run.find_resource resource_type,name
      resource.variables.should == {:stuff => 'foobar'}
    end

    verify_var['template', '/tmp/temp_file_0/nginx.conf']
    verify_var['template', '/etc/nginx/nginx.conf']
    verify_var['bsw_nginx_site_config', 'real site config']
    verify_var['bsw_nginx_site_config', 'test site config']
  end

  it 'complains without a main nginx config file in the templates directory' do
    # arrange

    # act

    # assert
    pending 'Write this test'
  end

  it 'returns updated by last action if the enclosed resources do' do
    # arrange

    # act

    # assert
    pending 'Write this test'
  end

  it 'does not return updated by last action of the enclosed resources are not updated' do
    # arrange

    # act

    # assert
    pending 'Write this test'
  end

  it 'cleans up temporary config files if validation passes' do
    # arrange

    # act

    # assert
    pending 'Write this test'
  end

  it 'cleans up temporary config files if validation fails' do
    # arrange

    # act

    # assert
    pending 'Write this test'
  end
end
