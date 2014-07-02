# Encoding: utf-8

require_relative 'spec_helper'
require_relative '../../../libraries/complex_update_checker'

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
    @stub_setup = nil
    original_new = Mixlib::ShellOut.method(:new)
    Mixlib::ShellOut.stub!(:new) do |*args|
      cmd = original_new.call(*args)
      cmd.stub!(:run_command)
      @stub_setup.call(cmd) if @stub_setup
      cmd
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
    @stub_setup = lambda do |shell_out|
      case shell_out.command
        when '/usr/sbin/nginx -c /tmp/temp_file_0/nginx.conf -t'
          stub = shell_out.stub!(:error!)
          stub.and_raise("Expected validation failure") unless option == :pass
        else
          shell_out.stub(:error!).and_raise "Unexpected command #{shell_out.command}"
      end
    end
  end

  def stub_updated_by
    checker = double()
    BswTech::ComplexUpdateChecker.stub(:new).and_return(checker)
    checker.stub(:updated_by_last_action?) do |instance|
      yield instance
    end
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
    @chef_run.should_not render_file '/etc/nginx/ignore.this'
    @chef_run.should_not render_file '/tmp/temp_file_0/ignore.this'
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
    action = lambda {
      temp_lwrp_recipe <<-EOF
        bsw_nginx_complete_config 'the config'
      EOF
    }

    # assert
    action.should raise_exception RuntimeError, 'bsw_nginx_complete_config[the config] (lwrp_gen::default line 1) had an error: RuntimeError: Expected validation failure'
    @chef_run.should_not render_file '/etc/nginx/nginx.conf'
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
    verify_var = lambda do |resource_type, name|
      resource = @chef_run.find_resource resource_type, name
      resource.variables.should == {:stuff => 'foobar'}
    end

    verify_var['template', '/tmp/temp_file_0/nginx.conf']
    verify_var['template', '/etc/nginx/nginx.conf']
    verify_var['bsw_nginx_site_config', 'real site config']
    verify_var['bsw_nginx_site_config', 'test site config']
  end

  it 'complains when there are no files in the templates directory' do
    # arrange
    force_validation_to :pass
    setup_mock_config_files []

    # act
    action = lambda {
      temp_lwrp_recipe <<-EOF
      bsw_nginx_complete_config 'the config' do
        variables({:stuff => 'foobar'})
      end
      EOF
    }

    # assert
    action.should raise_exception RuntimeError, 'bsw_nginx_complete_config[the config] (lwrp_gen::default line 1) had an error: RuntimeError: You must have a top level nginx.conf file in your templates/default/env directory.  You only have []'
  end

  it 'complains when there are files in the templates directory but not the main one' do
    # arrange
    force_validation_to :pass
    setup_mock_config_files ['junk.config']

    # act
    action = lambda {
      temp_lwrp_recipe <<-EOF
        bsw_nginx_complete_config 'the config' do
          variables({:stuff => 'foobar'})
        end
      EOF
    }

    # assert
    action.should raise_exception RuntimeError, 'bsw_nginx_complete_config[the config] (lwrp_gen::default line 1) had an error: RuntimeError: You must have a top level nginx.conf file in your templates/default/env directory.  You only have ["junk.config"]'
  end

  it 'returns updated by last action if the main config resource was updated' do
    # arrange
    force_validation_to :pass
    setup_mock_config_files 'nginx.conf'
    stub_updated_by do |instance|
      case instance.name
        when '/tmp/temp_file_0/nginx.conf'
          true
        when '/etc/nginx/nginx.conf'
          true
      end
    end

    # act
    temp_lwrp_recipe <<-EOF
      bsw_nginx_complete_config 'the config'
    EOF

    # assert
    resource = @chef_run.find_resource 'bsw_nginx_complete_config', 'the config'
    resource.updated_by_last_action?.should == true
  end

  it 'does not return updated by last action if the main config resource was not updated' do
    # arrange
    force_validation_to :pass
    setup_mock_config_files 'nginx.conf'
    stub_updated_by do |instance|
      case instance.name
        when '/tmp/temp_file_0/nginx.conf'
          true
        when '/etc/nginx/nginx.conf'
          false
      end
    end

    # act
    temp_lwrp_recipe <<-EOF
      bsw_nginx_complete_config 'the config'
    EOF

    # assert
    resource = @chef_run.find_resource 'bsw_nginx_complete_config', 'the config'
    resource.updated_by_last_action?.should == false
  end

  it 'returns updated by last action if the site config resource was updated' do
    # arrange
    force_validation_to :pass
    setup_mock_config_files 'nginx.conf'
    stub_updated_by { true }

    # act
    temp_lwrp_recipe <<-EOF
      bsw_nginx_complete_config 'the config'
    EOF

    # assert
    resource = @chef_run.find_resource 'bsw_nginx_complete_config', 'the config'
    resource.updated_by_last_action?.should == true
  end

  it 'does not return updated by last action if the site config resource was not updated' do
    # arrange
    force_validation_to :pass
    setup_mock_config_files 'nginx.conf'
    stub_updated_by { false }

    # act
    temp_lwrp_recipe <<-EOF
      bsw_nginx_complete_config 'the config'
    EOF

    # assert
    resource = @chef_run.find_resource 'bsw_nginx_complete_config', 'the config'
    resource.updated_by_last_action?.should == false
  end

  it 'cleans up temporary config files if validation passes' do
    # arrange
    force_validation_to :pass
    setup_mock_config_files 'nginx.conf'
    deleted_stuff = []
    FileUtils.stub(:rm_rf) do |dir|
      deleted_stuff << dir
    end

    # act
    temp_lwrp_recipe <<-EOF
      bsw_nginx_complete_config 'the config'
    EOF

    # assert
    deleted_stuff.should == @open_tempfiles
  end

  it 'cleans up temporary config files if validation fails' do
    # arrange
    force_validation_to :fail
    setup_mock_config_files 'nginx.conf'
    deleted_stuff = []
    FileUtils.stub(:rm_rf) do |dir|
      deleted_stuff << dir
    end

    # act
    lambda { temp_lwrp_recipe <<-EOF
      bsw_nginx_complete_config 'the config'
    EOF
    }.should raise_exception

    # assert
    deleted_stuff.should == @open_tempfiles
  end
end
