module DockerHelpers
  module Base
    require 'shellwords'

    ##########
    # coersion
    ##########

    def coerce_labels(v)
      case v
      when Hash, nil
        v
      else
        Array(v).each_with_object({}) do |label, h|
          parts = label.split(':')
          h[parts[0]] = parts[1]
        end
      end
    end

    def coerce_shell_command(v)
      return nil if v.nil?
      return Chef::Resource::DockerBase::ShellCommandString.new(
        ::Shellwords.join(v)) if v.is_a?(Array
                                        )
      Chef::Resource::DockerBase::ShellCommandString.new(v)
    end

    ################
    # Helper methods
    ################

    def to_port_exposures(ports)
      return nil if ports.nil?
      Array(ports).inject({}) { |a, e| a.merge(PortBinding.new(e).exposure) }
    end

    def to_port_bindings(ports)
      return nil if ports.nil?
      Array(ports).inject({}) { |a, e| a.merge(PortBinding.new(e).binding) }
    end

    def api_version
      @api_version ||= Docker.version['ApiVersion']
    end

    def connection
      @connection ||= begin
          opts = {}
          opts['read_timeout'] = read_timeout if property_is_set?(:read_timeout)
          opts['write_timeout'] = write_timeout if property_is_set?(:write_timeout)
          Docker::Connection.new(host || Docker.url, opts)
        end
    end

    def with_retries(&block)
      tries = api_retries
      begin
        block.call
        # Only catch errors that can be fixed with retries.
      rescue Docker::Error::ServerError, # 404
             Docker::Error::UnexpectedResponseError, # 400
             Docker::Error::TimeoutError,
             Docker::Error::IOError
        tries -= 1
        retry if tries > 0
        raise
      end
    end

    def call_action(_action)
      new_resource.run_action
    end
  end
end
