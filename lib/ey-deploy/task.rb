module EY
  class Task

    attr_reader :config
    alias :c :config

    def initialize(conf)
      @config = conf
      @roles = :all
    end

    def require_custom_tasks
      deploy_file = ["config/eydeploy.rb", "eydeploy.rb"].map do |short_file|
        File.join(c.repository_cache, short_file)
      end.detect do |file|
        File.exist?(file)
      end

      if deploy_file
        puts "~> Loading deployment task overrides from #{deploy_file}"
        instance_eval(File.read(deploy_file))
        true
      else
        false
      end
    end

    def roles(*task_roles)
      raise "Roles must be passed a block" unless block_given?

      begin
        @roles = task_roles
        yield
      ensure
        @roles = :all
      end
    end

    def run(cmd, &blk)
      run_on_roles(cmd, &blk)
    end

    def sudo(cmd, &blk)
      run_on_roles(cmd, %w[sudo sh -l -c], &blk)
    end

    def prepare_run(command)
      Escape.shell_command ["sh", "-l", "-c", command]
    end

    def prepare_sudo(command)
      Escape.shell_command ["sudo", "sh", "-l", "-c", command]
    end

    private

    def run_on_roles(cmd, wrapper=%w[sh -l -c])
      EY::Server.from_roles(@roles).inject(false) do |acc, server|
        to_run = block_given? ? yield(server, cmd.dup) : cmd
        failure = !server.run(Escape.shell_command(wrapper + [to_run]))
        acc || failure
      end && raise(EY::RemoteFailure)
    end
  end
end
