module Travis
  module Build
    class Script
      module Addons
        class Artifacts
          REQUIRES_SUPER_USER = false

          attr_accessor :script, :config
          attr_writer :concurrency, :max_size

          def initialize(script, config)
            @script = script
            @config = config
          end

          def after_script
            return if config.empty?
            script.if(want) { run }
          end

          private

          def want
            "($TRAVIS_PULL_REQUEST = false) && ($TRAVIS_BRANCH = #{branch})"
          end

          def run
            override_controlled_params
            options = config.delete(:options)

            return unless validate!

            script.cmd('echo "Uploading Artifacts (beta)"', echo: false, assert: false)
            script.fold('artifacts.0') do
              install
              configure_env
              script.set('PATH', '$HOME/bin:$PATH', echo: false, assert: false)
            end
            script.fold('artifacts.1') do
              script.cmd(
                "artifacts upload #{options}",
                assert: false
              )
            end
            script.cmd('echo "Done uploading artifacts"', echo: false, assert: false)
          end

          def branch
            config[:branch] || 'master'
          end

          def install
            script.cmd(
              'curl -sL https://raw.githubusercontent.com/meatballhat/artifacts/master/install | bash',
              echo: false, assert: false
            )
          end

          def override_controlled_params
            %w(max_size concurrency).map(&:to_sym).each do |k|
              config.delete(k)
            end
            config[:concurrency] = concurrency
            config[:max_size] = max_size
          end

          def concurrency
            @concurrency ||= Integer(ENV['ARTIFACTS_CONCURRENCY'] || 5)
          end

          def max_size
            @max_size ||= Float(ENV['ARTIFACTS_MAX_SIZE'] || 1024 * 1024 * 5)
          end

          def configure_env
            config.each { |key, value| setenv(key.to_s.upcase, value) }
          end

          def setenv(key, value, prefix = 'ARTIFACTS_')
            value = value.map(&:to_s).join(';') if value.respond_to?(:each)
            script.set(
              "#{prefix}#{key}", "#{value}", echo: setenv_echoable?(key), assert: false
            )
          end

          def setenv_echoable?(key)
            %w(PATHS).include?(key)
          end

          def validate!
            valid = true
            unless config[:key]
              script.cmd('echo "Artifacts config missing :key param"', echo: false, assert: false)
              valid = false
            end
            unless config[:secret]
              script.cmd('echo "Artifacts config missing :secret param"', echo: false, assert: false)
              valid = false
            end
            unless config[:bucket]
              script.cmd('echo "Artifacts config missing :bucket param"', echo: false, assert: false)
              valid = false
            end
            valid
          end
        end
      end
    end
  end
end
