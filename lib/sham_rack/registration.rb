
module ShamRack

  module Registration

    ADDRESS_PATTERN = /^[a-z0-9-]+(\.[a-z0-9-]+)*$/i

    def unmount_all
      registry.clear
      wildcard_registry.clear
    end

    def splat_at(address, port =nil, &app_block)
      # You want to make it work for this and any subdomains
      mount_point = mount_point_for(address, port)

      if app_block
        mount_point.mount(app_block)
      else
        mount_point
      end

      wildcard_registry[/^(.+\.)?#{address}$/] = mount_point

      mount_point
    end

    def at(address, port = nil, &app_block)
      mount_point = mount_point_for(address, port)
      if app_block
        mount_point.mount(app_block)
      else
        mount_point
      end
    end

    def application_for(address, port = nil)
      mount_point_for(address, port).app
    end

    def mount(app, address, port = nil)
      at(address, port).mount(app)
    end

    private

    def mount_point_for(address, port)
      mount_point = registry[mount_key(address, port)]

      if (!mount_point)
        # Look and see if it can be subdomain matched
        match = nil

        wildcard_registry.each_pair do |regex, mount_point|
          if ( regex.match(address) )
            match = mount_point
          end
        end

        # Cache it for next time
        if (match)
          registry[mount_key(address, port)] = match
        end
      end

      # Now grab it and return
      registry[mount_key(address,port)] ||= MountPoint.new
    end


    def wildcard_registry
      @wildcard_registry ||= {}
    end

    def registry
      @registry ||= Hash.new
    end

    def mount_key(address, port)
      unless address =~ ADDRESS_PATTERN
        raise ArgumentError, "invalid address"
      end
      port ||= Net::HTTP.default_port
      port = Integer(port)
      [address, port]
    end

  end

  class MountPoint

    attr_reader :app

    def mount(app)
      @app = app
    end

    def unmount
      @app = nil
    end

    def rackup(&block)
      require "rack"
      mount(Rack::Builder.new(&block).to_app)
    end

    def sinatra(&block)
      require "sinatra/base"
      sinatra_app = Class.new(Sinatra::Base)
      sinatra_app.class_eval(&block)
      mount(sinatra_app.new)
    end

    def stub
      require "sham_rack/stub_web_service"
      mount(StubWebService.new)
    end

  end

end
