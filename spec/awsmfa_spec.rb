require 'spec_helper'
require 'time'

RSpec.describe 'AwsMfa' do

  include FakeFS::SpecHelpers
  subject { AwsMfa.new }

  before(:each) do
    stub_const('ENV', { 'PATH' => '/bin', 'HOME' => '/home' })
  end

  describe '#initialize' do
    it 'exits when aws config is not found' do
      create_aws_binary
      expect { subject }.to raise_error AwsMfa::Errors::ConfigurationNotFound
    end

    it 'exits when aws cli is not found' do
      create_aws_config
      expect { subject }.to raise_error AwsMfa::Errors::CommandNotFound
    end

    it 'initializes when aws cli and config are both found' do
      create_aws_binary
      create_aws_config
      expect { subject }.not_to raise_error
    end
  end

  describe '#aws_config_dir' do
    it 'uses default when AWS_CREDENTIAL_FILE not set' do
      create_aws_binary
      create_aws_config
      expect(subject.aws_config_dir).to eq '/home/.aws'
    end

    it 'uses AWS_CREDENTIAL_FILE when it is set' do
      stub_const('ENV', { 'PATH' => '/bin', 'HOME' => '/home', 'AWS_CREDENTIAL_FILE' => '/foo/config' })
      create_aws_binary
      create_aws_config
      create_aws_config('/foo')
      expect(subject.aws_config_dir).to eq '/foo'
    end
  end

  describe '#load_arn' do
    before(:each) do
      create_aws_binary
      create_aws_config
    end

    let(:device_path) { '/home/.aws/mfa_device' }

    it 'loads arn from file when it exists' do
      subject.write_arn_to_file(device_path, 'bar')
      expect(subject.load_arn).to eq 'bar'
    end

    it 'loads arn from aws when file does not exist' do
      allow(subject).to receive(:mfa_devices).and_return([{
        'SerialNumber' => 'foo'
      }])
      expect(subject.load_arn).to eq 'foo'
    end

    it 'raises an error when there is a problem with aws' do
      command = double(call: double(succeeded?: false))
      allow(AwsMfa::ShellCommand).to receive(:new).and_return(command)

      expect { subject.load_arn }.to raise_error(AwsMfa::Errors::Error)
    end
  end

  describe '#load_arn_profile' do
    before(:each) do
      create_aws_binary
      create_aws_config
    end

    let(:device_path) { '/home/.aws/prod_mfa_device' }

    it 'loads arn from file when it exists for profile' do
      subject.write_arn_to_file(device_path, 'bar')
      expect(subject.load_arn('prod')).to eq 'bar'
    end

    it 'loads arn from aws when file does not exist for profile' do
      allow(subject).to receive(:mfa_devices).and_return([{
                                                              'SerialNumber' => 'foo'
                                                          }])
      expect(subject.load_arn('prod')).to eq 'foo'
    end
  end

  describe '#load_credentials' do
    before(:each) do
      create_aws_binary
      create_aws_config
    end

    let(:credentials_path) { '/home/.aws/prod_mfa_credentials' }

    it 'loads credentials from file when it is fresh' do
      credentials = { 'Expiration' => (Time.now + 60).utc.iso8601 }
      subject.write_credentials_to_file(credentials_path, credentials)
      expect(subject.load_credentials('arn', 'prod')).to eq credentials
    end

    it 'loads credentials from aws when stored credentials are expired' do
      old_credentials = { 'Expiration' => (Time.now - 100).utc.iso8601 }
      new_credentials = {}
      subject.write_credentials_to_file(credentials_path, old_credentials)
      allow(subject).to receive(:load_credentials_from_aws).and_return(new_credentials)
      expect(subject.load_credentials('arn', 'prod')).to eq new_credentials
    end

    it 'loads credentials from aws when file does not exist' do
      credentials = { 'hello' => 'world' }
      allow(subject).to receive(:load_credentials_from_aws).and_return(credentials)
      expect(subject.load_credentials('arn', 'prod')).to eq credentials
    end

    it 'loads does not persist credentials when persist=false' do
      allow(subject).to receive(:load_credentials_from_aws).and_return({})
      subject.load_credentials('arn', 'prod', 0, false)
      expect(File).not_to exist(credentials_path)
    end

    it 'raises an error when aws returns an error' do
      allow(subject).to receive(:request_code_from_user).and_return('867530')
      command = double(call: double(succeeded?: false))
      allow(AwsMfa::ShellCommand).to receive(:new).and_return(command)
      expect { subject.load_credentials('arn', 'prod') }.to raise_error(AwsMfa::Errors::InvalidCode)
    end
  end

end
