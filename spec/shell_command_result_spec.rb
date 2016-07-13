require 'spec_helper'

RSpec.describe 'AwsMfa::ShellCommandResult' do
  context 'successful command' do
    subject { AwsMfa::ShellCommandResult.new('hello world', process_status) }
    let(:process_status) { double(success?: true)  }

    it 'returns the command output' do
      expect(subject.output).to eql('hello world')
    end

    it 'returns that the command succeeded' do
      expect(subject.succeeded?).to eql(true)
    end
  end

  context 'unsuccessful command' do
    subject { AwsMfa::ShellCommandResult.new('hello world', process_status) }
    let(:process_status) { double(success?: false)  }

    it 'returns the command output' do
      expect(subject.output).to eql('hello world')
    end

    it 'returns that the command failed' do
      expect(subject.succeeded?).to eql(false)
    end
  end
end
