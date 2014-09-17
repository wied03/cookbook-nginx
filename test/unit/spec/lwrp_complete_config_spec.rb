# Encoding: utf-8

require_relative 'spec_helper'

describe 'bsw_nginx::lwrp:complete_config' do
  def setup_mock_config_files(other_files, draft_main_config_contents='')
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
    original = File.method(:read)
    allow(File).to receive(:read) do |filename|
      if filename == File.join(@tmp_dir_within_project, 'temp_file_0', 'nginx.conf')
        draft_main_config_contents
      else
        original[filename]
      end
    end
  end

  include BswTech::ChefSpec::LwrpTestHelper

  before {
    stub_resources
    @tmp_dir_within_project = File.absolute_path(File.join(File.dirname(__FILE__), 'temp_gen'))
    FileUtils.rm_rf @tmp_dir_within_project
    @open_tempfiles = []
    @written_to_files = {}
    Dir.stub(:mktmpdir) do
      name = "#{@tmp_dir_within_project}/temp_file_#{@open_tempfiles.length}"
      @open_tempfiles << name
      puts "Creating mock temp directory #{name}"
      FileUtils.mkdir_p name
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
    FileUtils.rm_rf @tmp_dir_within_project
    cleanup
  }

  def cookbook_under_test
    'bsw_nginx'
  end

  def lwrps_under_test
    'complete_config'
  end

  def force_validation_to(option, with_binary=:default)
    @stub_setup = lambda do |shell_out|
      bin_path = with_binary
      bin_path = '/usr/sbin/nginx' if with_binary == :default
      case shell_out.command
        when "#{bin_path} -c #{@tmp_dir_within_project}/temp_file_0/nginx.conf -t"
          stub = shell_out.stub!(:error!)
          stub.and_raise("Expected validation failure") unless option == :pass
        else
          shell_out.stub(:error!).and_raise "Unexpected command #{shell_out.command}"
      end
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
    @chef_run.should_not render_file "#{@tmp_dir_within_project}/temp_file_0/ignore.this"
    @chef_run.should render_file "#{@tmp_dir_within_project}/temp_file_0/nginx.conf"
    @chef_run.should render_file '/etc/nginx/nginx.conf'
    resource = @chef_run.find_resource 'bsw_nginx_site_config', 'real site config'
    resource.should_not be_nil
    resource.base_path.should == '/etc/nginx'
    resource = @chef_run.find_resource 'bsw_nginx_site_config', 'test site config'
    resource.should_not be_nil
    resource.base_path.should == "#{@tmp_dir_within_project}/temp_file_0"
  end

  it 'allows customizing the nginx bin location' do
    # arrange
    force_validation_to :pass, '/usr/local/nginx'
    setup_mock_config_files 'nginx.conf'

    # act
    temp_lwrp_recipe <<-EOF
          bsw_nginx_complete_config 'the config'
    EOF

    # assert
    @chef_run.should_not render_file '/etc/nginx/ignore.this'
    @chef_run.should_not render_file "#{@tmp_dir_within_project}/temp_file_0/ignore.this"
    @chef_run.should render_file "#{@tmp_dir_within_project}/temp_file_0/nginx.conf"
    @chef_run.should render_file '/etc/nginx/nginx.conf'
    resource = @chef_run.find_resource 'bsw_nginx_site_config', 'real site config'
    resource.should_not be_nil
    resource.base_path.should == '/etc/nginx'
    resource = @chef_run.find_resource 'bsw_nginx_site_config', 'test site config'
    resource.should_not be_nil
    resource.base_path.should == "#{@tmp_dir_within_project}/temp_file_0"
  end

  it 'substitutes the PID file for a temporary file' do
    # arrange
    force_validation_to :pass
    nginx_mock_config_contents = <<-EOF
pid /some/pid/file;
other stuff
    EOF
    setup_mock_config_files 'nginx.conf', nginx_mock_config_contents

    # act
    temp_lwrp_recipe <<-EOF
      bsw_nginx_complete_config 'the config'
    EOF

    # assert
    actual = File.open(File.join(@tmp_dir_within_project, 'temp_file_0', 'nginx.conf')).read
    expect(actual).to eq ''
    pending 'Write this test'
  end

  it 'substitutes the PID file with a lot of spaces in the config for a temporary file' do
    # arrange

    # act

    # assert
    pending 'Write this test'
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

  it 'works properly with default variables' do
    # arrange
    force_validation_to :pass
    setup_mock_config_files 'nginx.conf'

    # act
    temp_lwrp_recipe <<-EOF
      bsw_nginx_complete_config 'the config'
    EOF

    # assert
    resource = @chef_run.find_resource 'template', '/etc/nginx/nginx.conf'
    resource.variables.should == {:nginx_config_path => '/etc/nginx'}
    resource = @chef_run.find_resource 'template', '/tmp/temp_file_0/nginx.conf'
    resource.variables.should == {:nginx_config_path => '/tmp/temp_file_0'}
  end

  it 'works properly with specified variables' do
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
    verify_var = lambda do |resource_type, name, extra_vars|
      expected_vars = {:stuff => 'foobar'}.merge(extra_vars || {})
      resource = @chef_run.find_resource resource_type, name
      resource.variables.should == expected_vars
    end

    verify_var['template', '/tmp/temp_file_0/nginx.conf', :nginx_config_path => '/tmp/temp_file_0']
    verify_var['template', '/etc/nginx/nginx.conf', :nginx_config_path => '/etc/nginx']
    verify_var['bsw_nginx_site_config', 'real site config', :nginx_config_path => '/etc/nginx']
    verify_var['bsw_nginx_site_config', 'test site config', :nginx_config_path => '/tmp/temp_file_0']
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

  it 'creates resources with the temporary resource flag set' do
    # arrange
    force_validation_to :pass
    setup_mock_config_files 'nginx.conf'

    # act
    temp_lwrp_recipe <<-EOF
      bsw_nginx_complete_config 'the config'
    EOF

    # assert
    resource = @chef_run.find_resource 'bsw_nginx_site_config', 'test site config'
    resource.temporary_resource.should == true
    resource = @chef_run.find_resource 'template', '/tmp/temp_file_0/nginx.conf'
    resource.temporary_resource.should == true
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

  it 'suppresses output on temp files' do
    # arrange
    force_validation_to :pass
    setup_mock_config_files 'nginx.conf'

    # act
    temp_lwrp_recipe <<-EOF
      bsw_nginx_complete_config 'the config'
    EOF

    # assert
    resource = @chef_run.find_resource 'template', '/tmp/temp_file_0/nginx.conf'
    resource.should_not be_nil
    resource.sensitive.should == true
    resource = @chef_run.find_resource 'bsw_nginx_site_config', 'test site config'
    resource.should_not be_nil
    resource.suppress_output.should == true
  end

  it 'does not suppress output on the real files' do
    # arrange
    force_validation_to :pass
    setup_mock_config_files 'nginx.conf'

    # act
    temp_lwrp_recipe <<-EOF
      bsw_nginx_complete_config 'the config'
    EOF

    # assert
    resource = @chef_run.find_resource 'template', '/etc/nginx/nginx.conf'
    resource.should_not be_nil
    resource.sensitive.should == false
    resource = @chef_run.find_resource 'bsw_nginx_site_config', 'real site config'
    resource.should_not be_nil
    resource.suppress_output.should == false
  end
end
