require 'tilt'

module HandlebarsAssets
  class TiltHandlebars < Tilt::Template

    def self.default_mime_type
      'application/javascript'
    end

    def evaluate(scope, locals, &block)
      template_path = TemplatePath.new(scope)

      source = if template_path.is_haml?
                Haml::Engine.new(data, HandlebarsAssets::Config.haml_options).render
               else
                 data
               end

      compiled_hbs = Handlebars.precompile(source, HandlebarsAssets::Config.options)

      template_namespace = HandlebarsAssets::Config.template_namespace

      if HandlebarsAssets::Config.for_ember
        source_one_line = source.gsub(/([^\n])\n([^\n])/, '\1 \2').chomp
        <<-TEMPLATE
          this.#{template_namespace} || (this.#{template_namespace} = {});
          this.#{template_namespace}[#{template_path.name}] = Ember.Handlebars.compile("#{source_one_line}");
        TEMPLATE
      else
        if template_path.is_partial?
          <<-PARTIAL
            (function() {
              Handlebars.registerPartial(#{template_path.name}, Handlebars.template(#{compiled_hbs}));
            }).call(this);
          PARTIAL
        else
          <<-TEMPLATE
            (function() {
              this.#{template_namespace} || (this.#{template_namespace} = {});
              this.#{template_namespace}[#{template_path.name}] = Handlebars.template(#{compiled_hbs});
              return this.#{template_namespace}[#{template_path.name}];
            }).call(this);
          TEMPLATE
        end
      end
    end

    def initialize_engine
      require_template_library 'haml'
    rescue LoadError
      # haml not available
    end

    protected

    def prepare; end

    class TemplatePath
      def initialize(scope)
        self.full_path = scope.pathname
        self.template_path = scope.logical_path
      end

      def is_haml?
        full_path.to_s.end_with?('.hamlbars')
      end

      def is_partial?
        template_path.gsub(%r{.*/}, '').start_with?('_')
      end

      def name
        is_partial? ? partial_name : template_name
      end

      private

      attr_accessor :full_path, :template_path

      def forced_underscore_name
        '_' + relative_path
      end

      def relative_path
        template_path.gsub(/^#{HandlebarsAssets::Config.path_prefix}\/(.*)$/i, "\\1")
      end

      def partial_name
        forced_underscore_name.gsub(/\//, '_').gsub(/__/, '_').dump
      end

      def template_name
        relative_path.dump
      end
    end
  end
end
