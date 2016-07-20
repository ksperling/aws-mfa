class AwsMfa
  class ShellCommandResult
    attr_reader :output

    def initialize(command_output, process_status)
      @output = command_output
      @process_status = process_status
    end

    def succeeded?
      process_status.success?
    end

    private

    attr_reader :process_status
  end
end
