require 'json'
require 'aws_mfa/errors'
require 'aws_mfa/shell_command'
require 'aws_mfa/shell_command_result'

class AwsMfa
  attr_reader :aws_config_dir

  def initialize
    validate_aws_installed
    @aws_config_dir = find_aws_config
  end

  def validate_aws_installed
    raise Errors::CommandNotFound, 'Could not find the aws command' unless which('aws')
  end

  def find_aws_config
    if ENV['AWS_CREDENTIAL_FILE']
      aws_config_file = ENV['AWS_CREDENTIAL_FILE']
      aws_config_dir = File.dirname(aws_config_file)
    else
      aws_config_dir = File.join(ENV['HOME'], '.aws')
      aws_config_file = File.join(aws_config_dir, 'config')
    end

    unless File.readable?(aws_config_file)
      raise Errors::ConfigurationNotFound, 'Aws configuration not found. You must run `aws configure`'
    end

    aws_config_dir
  end

  # http://stackoverflow.com/questions/2108727/which-in-ruby-checking-if-program-exists-in-path-from-ruby
  def which(cmd)
    exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
    ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
      exts.each { |ext|
        exe = File.join(path, "#{cmd}#{ext}")
        return exe if File.executable? exe
      }
    end
    return nil
  end

  def load_arn(profile='default')
    arn_file_name = 'mfa_device'
    if (! profile.eql? 'default')
      arn_file_name = "#{profile}_#{arn_file_name}"
    end
    arn_file = File.join(aws_config_dir, arn_file_name)

    if File.readable?(arn_file)
      arn = load_arn_from_file(arn_file)
    else
      arn = load_arn_from_aws(profile)
      write_arn_to_file(arn_file, arn)
    end

    arn
  end

  def load_arn_from_file(arn_file)
    File.read(arn_file)
  end

  def load_arn_from_aws(profile='default')
    STDERR.puts 'Fetching MFA devices for your account...'
    devs = mfa_devices(profile)
    if devs.any?
      devs.first.fetch('SerialNumber')
    else
      raise Errors::DeviceNotFound, 'No MFA devices were found for your account'
    end
  end

  def username(profile='default')
    # User will need sts:GetCallerIdentity permission
    get_identity_command = "aws --profile #{profile} --output json sts get-caller-identity"
    result = AwsMfa::ShellCommand.new(get_identity_command).call
    raise Errors::Error, 'Unable to determine identity' unless result.succeeded?
    user = JSON.parse(result.output)['Arn'][/^arn:aws:iam::\d+:user\/([\w+=,.@-]+)$/, 1]
    raise Errors::Error, 'Unable to derive username from identity ARN' unless user
    user
  end

  def mfa_devices(profile='default')
    user = username(profile)
    list_mfa_devices_command = "aws --profile #{profile} --output json iam list-mfa-devices --user-name #{user}"
    result = AwsMfa::ShellCommand.new(list_mfa_devices_command).call
    if result.succeeded?
      JSON.parse(result.output).fetch('MFADevices')
    else
      raise Errors::Error, 'There was a problem fetching MFA devices from AWS'
    end
  end

  def write_arn_to_file(arn_file, arn)
    File.open(arn_file, 'w') { |f| f.print arn }
    STDERR.puts "Using MFA device #{arn}. To change this in the future edit #{arn_file}."
  end

  def load_credentials(arn, profile='default')
    credentials_file_name = 'mfa_credentials'
    if (! profile.eql? 'default')
      credentials_file_name = "#{profile}_#{credentials_file_name}"
    end
    credentials_file  = File.join(aws_config_dir, credentials_file_name)

    if File.readable?(credentials_file) && token_not_expired?(credentials_file)
      credentials = load_credentials_from_file(credentials_file)
    else
      credentials = load_credentials_from_aws(arn, profile)
      write_credentials_to_file(credentials_file, credentials)
    end

    JSON.parse(credentials).fetch('Credentials')
  end

  def load_credentials_from_file(credentials_file)
    File.read(credentials_file)
  end

  def load_credentials_from_aws(arn, profile='default')
    code = request_code_from_user
    unset_environment
    credentials_command = "aws --profile #{profile} --output json sts get-session-token --serial-number #{arn} --token-code #{code}"
    result = AwsMfa::ShellCommand.new(credentials_command).call
    if result.succeeded?
      result.output
    else
      raise Errors::InvalidCode, 'There was a problem validating the MFA code with AWS'
    end
  end

  def write_credentials_to_file(credentials_file, credentials)
    File.open(credentials_file, 'w') { |f| f.print credentials }
  end

  def request_code_from_user
    STDERR.puts 'Enter the 6-digit code from your MFA device:'
    code = $stdin.gets.chomp
    raise Errors::InvalidCode, 'That is an invalid MFA code' unless code =~ /^\d{6}$/
    code
  end

  def unset_environment
    ENV.delete('AWS_SECRET_ACCESS_KEY')
    ENV.delete('AWS_ACCESS_KEY_ID')
    ENV.delete('AWS_SESSION_TOKEN')
    ENV.delete('AWS_SECURITY_TOKEN')
  end

  def token_not_expired?(credentials_file)
    # default is 12 hours
    expiration_period = 12 * 60 * 60
    mtime = File.stat(credentials_file).mtime
    now = Time.new
    if now - mtime < expiration_period
      true
    else
      false
    end
  end

  def print_credentials(credentials)
    puts "export AWS_SECRET_ACCESS_KEY='#{credentials['SecretAccessKey']}'"
    puts "export AWS_ACCESS_KEY_ID='#{credentials['AccessKeyId']}'"
    puts "export AWS_SESSION_TOKEN='#{credentials['SessionToken']}'"
    puts "export AWS_SECURITY_TOKEN='#{credentials['SessionToken']}'"
  end

  def export_credentials(credentials)
    ENV['AWS_SECRET_ACCESS_KEY'] = credentials['SecretAccessKey']
    ENV['AWS_ACCESS_KEY_ID'] = credentials['AccessKeyId']
    ENV['AWS_SESSION_TOKEN'] = credentials['SessionToken']
    ENV['AWS_SECURITY_TOKEN'] = credentials['SessionToken']
  end

  def execute
    profile = 'default'
    profile_index = ARGV.index('--profile')
    if (!profile_index.nil?)
      profile = ARGV.delete_at(profile_index + 1)
      ARGV.delete_at(profile_index)
    end
    arn = load_arn(profile)
    credentials = load_credentials(arn, profile)
    if ARGV.empty?
      print_credentials(credentials)
    else
      export_credentials(credentials)
      exec(*ARGV)
    end
  end
end
