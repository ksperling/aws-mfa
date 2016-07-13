require 'spec_helper'

RSpec.describe 'AWS::ShellCommand' do
  subject { AwsMfa::ShellCommand.new('ls -1') }

  describe '#new' do
    it 'returns the command' do
      expect(subject.command).to eq('ls -1')
    end
  end

  describe '#call' do
    it 'runs the command' do
      allow(AwsMfa::ShellCommandResult).to receive(:new)
      expect(subject).to receive(:`).with('ls -1')
      subject.call
    end

    it 'returns the output' do
      output = "Gemfile\nGemfile.lock\nLICENSE\nREADME.md"
      allow(subject).to receive(:`).with('ls -1').and_return(output)

      # Note: $? is a special read-only variable that is set by ruby after the
      # ` method is invoked. $? will be nil in this case because the ` method
      # is being stubbed for this test. If AwfMfa::ShellCommandResult is being
      # called with something besides nil as the second argument, there is
      # probably an unexpected invocation of ` somewhere else in the test(s)
      # preceeding this one that is setting $?.
      expect(AwsMfa::ShellCommandResult).to receive(:new).with(output, nil)

      subject.call
    end
  end
end
