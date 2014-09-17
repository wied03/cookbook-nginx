# Encoding: utf-8

require_relative 'spec_helper'

describe 'bsw_nginx::lwrp:complete_config' do
  def setup_mock_config_files(template_config_filenames_and_contents)
    # Chef returns files in subdirectories as well
    list = case template_config_filenames_and_contents
             when Hash
               empty = []
               empty << template_config_filenames_and_contents
               empty
             when Array
               template_config_filenames_and_contents
             else
               fail "Unknown mock stuff #{template_config_filenames_and_contents}, should be hash or list of hashes {:name => 'filename', :content => 'stuff'}"
           end
    list << {:name => 'sites/ignore.this', :content => 'stuff'}
    template_dir = File.join cookbook_path, 'templates', 'default', environment_name
    FileUtils.mkdir_p template_dir
    list.each do |other_file|
      site_filename = File.join template_dir, other_file[:name]
      FileUtils.mkdir_p File.dirname(site_filename)
      File.open site_filename, 'w' do |file|
        file << other_file[:content]
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
    @current_temp_dir = "#{@tmp_dir_within_project}/temp_file_#{@open_tempfiles.length}"
    Dir.stub(:mktmpdir) do
      name = "#{@tmp_dir_within_project}/temp_file_#{@open_tempfiles.length}"
      @open_tempfiles << name
      @current_temp_dir = name
      puts "Creating mock temp directory #{name}"
      FileUtils.mkdir_p name
      name
    end
    original_rm = FileUtils.method(:rm_rf)
    @deleted_stuff = []
    allow(FileUtils).to receive(:rm_rf) do |path|
      original_rm[path] unless path == @current_temp_dir
      @deleted_stuff << path
    end
    @stub_setup = nil
    original_new = Mixlib::ShellOut.method(:new)
    allow(Mixlib::ShellOut).to receive(:new) do |*args|
      cmd = original_new.call(*args)
      allow(cmd).to receive(:run_command)
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

  def lwrps_full
    ['bsw_nginx_complete_config']
  end

  def force_validation_to(option, with_binary=:default)
    @stub_setup = lambda do |shell_out|
      bin_path = with_binary
      bin_path = '/usr/sbin/nginx' if with_binary == :default
      case shell_out.command
        when "#{bin_path} -c #{@current_temp_dir}/nginx.conf -t"
          stub = allow(shell_out).to receive(:error!)
          stub.and_raise('You have an NGINX validation failure') unless option == :pass
        else
          shell_out.stub(:error!).and_raise "Unexpected command #{shell_out.command}"
      end
    end
  end

  it 'works with a valid config' do
    # arrange
    force_validation_to :pass
    setup_mock_config_files({:name => 'nginx.conf.erb', :content => 'the config file for <%= node.environment %>'})

    # act
    temp_lwrp_recipe <<-EOF
      bsw_nginx_complete_config 'the config'
    EOF

    # assert
    @chef_run.should_not render_file '/etc/nginx/ignore.this'
    @chef_run.should render_file('/etc/nginx/nginx.conf').with_content 'the config file for thestagingenv'
  end

  it 'works with a valid config and sites' do
    # arrange
    force_validation_to :pass
    setup_mock_config_files([
                                {:name => 'nginx.conf.erb', :content => 'the config file for <%= node.environment %>'},
                                {:name => 'sites/site1.conf.erb', :content => 'the site for <%= node.name %>'}
                            ])

    # act
    temp_lwrp_recipe <<-EOF
      bsw_nginx_complete_config 'the config'
    EOF

    # assert
    @chef_run.should render_file('/etc/nginx/nginx.conf').with_content 'the config file for thestagingenv'
    @chef_run.should render_file('/etc/nginx/sites-available/nginx.conf').with_content 'the site for thestagingenv'
    # TODO: Test both permanent and temp link
    pending 'Write this test'
  end

  it 'does not converge if validation fails' do
    # arrange
    force_validation_to :fail
    setup_mock_config_files({:name => 'nginx.conf.erb', :content => 'the config file for <%= node.environment %>'})

    # act
    action = lambda {
      temp_lwrp_recipe <<-EOF
      bsw_nginx_complete_config 'the config'
      EOF
    }

    # assert
    expect(action).to raise_exception
    resource = @chef_run.find_resource 'bsw_nginx_complete_config', 'the config'
    expect(resource).to do_nothing
  end

  it 'allows customizing the nginx bin location' do
    # arrange
    force_validation_to :pass, '/usr/local/nginx'
    setup_mock_config_files({:name => 'nginx.conf.erb', :content => 'the config file for <%= node.environment %>'})

    # act
    temp_lwrp_recipe <<-EOF
      bsw_nginx_complete_config 'the config' do
        nginx_binary '/usr/local/nginx'
      end
    EOF

    # assert
    @chef_run.should_not render_file '/etc/nginx/ignore.this'
    @chef_run.should render_file('/etc/nginx/nginx.conf').with_content 'the config file for thestagingenv'
  end

  it 'substitutes the PID file for a temporary file' do
    # arrange
    force_validation_to :pass
    nginx_mock_config_contents = <<-EOF
pid /some/pid/file;
other stuff
<%= node.name %>
    EOF
    setup_mock_config_files({:name => 'nginx.conf.erb', :content => nginx_mock_config_contents})

    # act
    temp_lwrp_recipe <<-EOF
      bsw_nginx_complete_config 'the config'
    EOF

    # assert
    actual = File.open(File.join(@current_temp_dir, 'nginx.conf')).read
    real_contents = <<-EOF
pid /some/pid/file;
other stuff
chefspec.local
    EOF
    expect(actual).to_not eq real_contents
  end

  it 'substitutes the PID file with a lot of spaces in the config for a temporary file' do
    # arrange
    force_validation_to :pass
    nginx_mock_config_contents = <<-EOF
pid   /some/pid/file  ;
other stuff
<%= node.name %>
    EOF
    setup_mock_config_files({:name => 'nginx.conf.erb', :content => nginx_mock_config_contents})

    # act
    temp_lwrp_recipe <<-EOF
          bsw_nginx_complete_config 'the config'
    EOF

    # assert
    actual = File.open(File.join(@current_temp_dir, 'nginx.conf')).read
    real_contents = <<-EOF
pid   /some/pid/file  ;
other stuff
chefspec.local
    EOF
    expect(actual).to_not eq real_contents
  end

  it 'works properly with more than 1 top level config file' do
    # arrange
    force_validation_to :pass
    setup_mock_config_files([
                                {:name => 'nginx.conf.erb', :content => 'the config file for <%= node.environment %>'},
                                {:name => 'some.other.file.erb', :content => "the node <%= node.name %>"}
                            ])

    # act
    temp_lwrp_recipe <<-EOF
      bsw_nginx_complete_config 'the config'
    EOF

    # assert
    @chef_run.should render_file('/etc/nginx/nginx.conf').with_content 'the config file for thestagingenv'
    @chef_run.should render_file('/etc/nginx/some.other.file').with_content 'the node chefspec.local'
  end

  it 'works properly with specified variables' do
    # arrange
    force_validation_to :pass
    setup_mock_config_files({:name => 'nginx.conf.erb', :content => 'the config file for <%= node.environment %> is <%= @stuff %>'})

    # act
    temp_lwrp_recipe <<-EOF
      bsw_nginx_complete_config 'the config' do
        variables({:stuff => 'foobar'})
      end
    EOF

    # assert
    @chef_run.should render_file('/etc/nginx/nginx.conf').with_content 'the config file for thestagingenv is foobar'
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
    action.should raise_exception RuntimeError, 'bsw_nginx_complete_config[the config] (lwrp_gen::default line 1) had an error: RuntimeError: You must have a top level nginx.conf.erb file in your templates/default/env directory.  You only have []'
  end

  it 'complains when there are files in the templates directory but not the main one' do
    # arrange
    force_validation_to :pass
    setup_mock_config_files({:name => 'junk.conf.erb', :content => 'the config file for <%= node.environment %> is <%= @stuff %>'})

    # act
    action = lambda {
      temp_lwrp_recipe <<-EOF
        bsw_nginx_complete_config 'the config' do
          variables({:stuff => 'foobar'})
        end
      EOF
    }

    # assert
    action.should raise_exception RuntimeError, 'bsw_nginx_complete_config[the config] (lwrp_gen::default line 1) had an error: RuntimeError: You must have a top level nginx.conf.erb file in your templates/default/env directory.  You only have ["junk.conf.erb"]'
  end

  it 'cleans up temporary config files if validation passes' do
    # arrange
    force_validation_to :pass
    setup_mock_config_files({:name => 'nginx.conf.erb', :content => 'the config file for <%= node.environment %>'})

    # act
    temp_lwrp_recipe <<-EOF
      bsw_nginx_complete_config 'the config'
    EOF

    # assert
    @deleted_stuff.should == @open_tempfiles
  end

  it 'cleans up temporary config files if validation fails' do
    # arrange
    force_validation_to :fail
    setup_mock_config_files({:name => 'nginx.conf.erb', :content => 'the config file for <%= node.environment %>'})

    # act
    lambda { temp_lwrp_recipe <<-EOF
      bsw_nginx_complete_config 'the config'
    EOF
    }.should raise_exception

    # assert
    @deleted_stuff.should == @open_tempfiles
  end
end
