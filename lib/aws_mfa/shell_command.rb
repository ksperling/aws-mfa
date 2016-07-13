class AwsMfa
  class ShellCommand
    attr_reader :command

    def initialize(command)
      @command = command
    end

    def call
      output = `#{command}`
      ShellCommandResult.new(output, $?)
    end
  end
end
