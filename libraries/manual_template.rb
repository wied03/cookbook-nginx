require 'erb'

module BswTech
  class ManualTemplate
    def initialize(run_context)
      @run_context = run_context
    end

    def write_with_variables(cookbook, source, variables, location)
      FileUtils.mkdir_p location
      ctx = Chef::Mixin::Template::TemplateContext.new variables
      ctx[:node] = @run_context.node
      path = cookbook_template_location(source, cookbook)
      output = ctx.render_template(path)
      filename_without_erb_extension = ::File.basename(source, '.erb')
      destination = ::File.join(location, filename_without_erb_extension)
      Chef::Log.debug "Writing temporary template #{path} to #{destination}"
      ::File.open destination, 'w' do |file|
        file << output
      end
    end

    private

    def cookbook_template_location(source, cookbook_name)
      node = @run_context.node
      cookbook = @run_context.cookbook_collection[cookbook_name]
      file = ::File.join(node.environment, source)
      cookbook.preferred_filename_on_disk_location(node, :templates, file)
    end
  end
end