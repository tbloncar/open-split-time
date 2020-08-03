require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module OpenSplitTime
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = 'UTC'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    config.autoload_paths += %W(#{config.root}/lib)
    config.autoload_paths += Dir[File.join(Rails.root, "lib", "core_ext", "**/*.rb")].each {|l| require l }
    config.autoload_paths += ['app/presenters/*.rb']

    config.exceptions_app = self.routes

    Raven.configure do |config|
      config.dsn = ENV['SENTRY_DSN']
      config.sanitize_fields = Rails.application.config.filter_parameters.map(&:to_s)
    end
  end
end
