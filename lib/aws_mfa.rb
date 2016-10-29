require 'json'
require 'time'
require 'optparse'
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
    arn_file_name = "#{profile}_#{arn_file_name}" unless profile == 'default'
    arn_file = File.join(aws_config_dir, arn_file_name)

    arn = load_arn_from_file(arn_file)
    unless arn
      arn = load_arn_from_aws(profile)
      write_arn_to_file(arn_file, arn)
    end

    arn
  end

  def load_arn_from_file(arn_file)
    begin
      File.read(arn_file)
    rescue Errno::ENOENT
      nil
    end
  end

  def load_arn_from_aws(profile='default')
    STDERR.puts 'Fetching MFA devices for your account...'
    devs = mfa_devices(profile)
    raise Errors::DeviceNotFound, 'No MFA devices were found for your account' unless devs.any?
    devs.first['SerialNumber']
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
    raise Errors::Error, 'There was a problem fetching MFA devices from AWS' unless result.succeeded?
    JSON.parse(result.output)['MFADevices']
  end

  def write_arn_to_file(arn_file, arn)
    File.open(arn_file, 'w', 0600) {|f| f.print arn }
    STDERR.puts "Using MFA device #{arn}. To change this in the future edit #{arn_file}."
  end

  def load_credentials(arn, profile='default', duration=0, persist=true)
    credentials_file_name = 'mfa_credentials'
    credentials_file_name = "#{profile}_#{credentials_file_name}" unless profile == 'default'
    credentials_file  = File.join(aws_config_dir, credentials_file_name)

    credentials = load_credentials_from_file(credentials_file)
    unless credentials_valid?(credentials)
      credentials = load_credentials_from_aws(arn, profile, duration)
      write_credentials_to_file(credentials_file, credentials) if persist
    end

    credentials
  end

  def load_credentials_from_file(credentials_file)
    begin
      JSON.parse(File.read(credentials_file))['Credentials']
    rescue Errno::ENOENT
      nil
    end
  end

  def load_credentials_from_aws(arn, profile='default', duration=0)
    code = request_code_from_user
    unset_environment
    credentials_command = "aws --profile #{profile} --output json sts get-session-token --serial-number #{arn} --token-code #{code}"
    credentials_command += " --duration-seconds #{duration}" if duration > 0
    result = AwsMfa::ShellCommand.new(credentials_command).call
    raise Errors::InvalidCode, 'There was a problem validating the MFA code with AWS' unless result.succeeded?
    JSON.parse(result.output)['Credentials']
  end

  def write_credentials_to_file(credentials_file, credentials)
    # Wrap back into the top-level Credentials object for backwards compatibility
    File.open(credentials_file, 'w', 0600) {|f| f.print(JSON.unparse({ 'Credentials' => credentials })) }
  end

  def request_code_from_user
    STDERR.print 'Enter the 6-digit code from your MFA device: '
    STDERR.flush
    code = $stdin.gets.chomp
    raise Errors::InvalidCode, 'That is an invalid MFA code' unless code =~ /^\d{6}$/
    code
  end

  def credentials_valid?(credentials)
    # Simple lexical comparison works due to the fixed ISO 8601 format
    credentials && Time.now.utc.iso8601 < credentials['Expiration']
  end

  def generate_environment(credentials, profile)
    yield 'AWS_SECRET_ACCESS_KEY', credentials['SecretAccessKey']
    yield 'AWS_ACCESS_KEY_ID', credentials['AccessKeyId']
    yield 'AWS_SESSION_TOKEN', credentials['SessionToken']
    yield 'AWS_SECURITY_TOKEN', credentials['SessionToken']
    yield 'AWS_SESSION_EXPIRATION', credentials['Expiration']
    yield 'AWS_DEFAULT_PROFILE', profile
  end

  def unset_environment
    generate_environment({}, nil) {|k,v| ENV.delete(k) }
  end

  def print_environment(credentials, profile)
    generate_environment(credentials, profile) {|k,v| puts "export #{k}='#{v}'" }
  end

  def export_environment(credentials, profile)
    generate_environment(credentials, profile) {|k,v| ENV[k] = v }
  end

  def interactive_shell
    # Export path to aws-mfa so it can be invoked from the shell
    ENV['AWS_MFA'] = File.expand_path('../bin/aws-mfa', File.dirname(__FILE__))

    # Figure out the type of shell and enable shell-specific functionality if available
    shell = ENV['SHELL'] || '/bin/sh'
    name = File.basename(shell)

    if name == 'bash' || name != 'sh' && %x(#{shell} --version 2>&1 </dev/null).start_with?('GNU bash')
      # bash --rcfile lets us load our custom bashrc. Note this doesn't work when running bash as 'sh'
      [ shell, '--rcfile', File.expand_path('bashrc', File.dirname(__FILE__)), '-i' ]

    elsif name == 'zsh' || %x(#{shell} --version 2>&1 </dev/null).start_with?('zsh')
      # zsh doesn't have anything like '--rcfile', so we have to hook the entire ZDOTDIR
      ENV['AWS_MFA_ZDOTREAL'] = ENV['ZDOTDIR']
      ENV['ZDOTDIR'] = File.expand_path(File.dirname(__FILE__))
      [ shell, '-i' ]

    else
      STDERR.puts "Note: automatic token refresh is not supported in this shell (#{shell})"
      [ shell, '-i' ]
    end
  end

  def execute
    profile = ENV['AWS_DEFAULT_PROFILE'] || 'default'
    duration = (ENV['AWS_MFA_SESSION_DURATION'] || '0').to_i
    persist = (ENV['AWS_MFA_PERSIST'] || 'true') == 'true'
    begin
      OptionParser.new do |opts|
        opts.banner = "Usage: aws-mfa [options]"
        opts.on("--profile=PROFILE", "Use a specific profile from your credential file") {|p| profile = p }
        opts.on("--session-duration=SECONDS", Integer, "Session validity period to request from STS") {|s| duration = s }
        opts.on("--[no-]persist", "Store temporary credentials in ~/.aws (default: enabled)") {|p| persist = p }
        opts.on("--help", "Prints this help") { puts opts; exit }
      end.parse!
    rescue OptionParser::ParseError => e
      raise Errors::Error, e
    end

    arn = load_arn(profile)
    credentials = load_credentials(arn, profile, duration, persist)

    if ARGV.empty?
      print_environment(credentials, profile)
    else
      ENV['AWS_MFA_SESSION_DURATION'] = duration.to_s
      ENV['AWS_MFA_PERSIST'] = persist.to_s
      export_environment(credentials, profile)
      exec(*(ARGV == [ 'shell' ] ? interactive_shell : ARGV))
    end
  end
end
