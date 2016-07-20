require 'spec_helper'

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

      expect { subject.load_arn }.to raise_error(
        AwsMfa::Errors::Error,
        'There was a problem fetching MFA devices from AWS'
      )
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

    let(:credentials_path) { '/home/.aws/mfa_credentials' }

    it 'loads credentials from file when it is fresh' do
      subject.write_arn_to_file(credentials_path, '{"Credentials":"bar"}')
      expect(subject.load_credentials('arn')).to eq 'bar'
    end

    it 'loads credentials from aws when file is too old' do
      threshold = 60 * 60 * 12
      subject.write_arn_to_file(credentials_path, '{"Credentials":"bar"}')
      File.utime(Time.now, Time.now - threshold, credentials_path)
      allow(subject).to receive(:load_credentials_from_aws).and_return('{"Credentials":"foo"}')
      expect(subject.load_credentials('arn')).to eq 'foo'
    end

    it 'loads credentials from aws when file does not exist' do
      allow(subject).to receive(:load_credentials_from_aws).and_return('{"Credentials":"foo"}')
      expect(subject.load_credentials('arn')).to eq 'foo'
    end

    it 'raises an error when aws returns an error' do
      allow(subject).to receive(:request_code_from_user).and_return('867530')
      command = double(call: double(succeeded?: false))
      allow(AwsMfa::ShellCommand).to receive(:new).and_return(command)
      expect { subject.load_credentials('arn') }.to raise_error(
        AwsMfa::Errors::InvalidCode,
        'There was a problem validating the MFA code with AWS'
      )
    end
  end

  describe '#load_credentials_profile' do
    before(:each) do
      create_aws_binary
      create_aws_config
    end

    let(:credentials_path) { '/home/.aws/prod_mfa_credentials' }

    it 'loads credentials from file when it is fresh for profile' do
      subject.write_arn_to_file(credentials_path, '{"Credentials":"bar"}')
      expect(subject.load_credentials('arn', 'prod')).to eq 'bar'
    end

    it 'loads credentials from aws when file is too old for profile' do
      threshold = 60 * 60 * 12
      subject.write_arn_to_file(credentials_path, '{"Credentials":"bar"}')
      File.utime(Time.now, Time.now - threshold, credentials_path)
      allow(subject).to receive(:load_credentials_from_aws).and_return('{"Credentials":"foo"}')
      expect(subject.load_credentials('arn', 'prod')).to eq 'foo'
    end

    it 'loads credentials from aws when file does not exist' do
      allow(subject).to receive(:load_credentials_from_aws).and_return('{"Credentials":"foo"}')
      expect(subject.load_credentials('arn', 'prod')).to eq 'foo'
    end
  end

end
