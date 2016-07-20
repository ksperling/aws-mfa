Gem::Specification.new do |s|
  s.name         = 'aws-mfa'
  s.version      = '0.3.1'
  s.date         = '2016-07-20'
  s.description  = 'Run AWS commands with MFA'
  s.summary      = s.description
  s.authors      = ['Brian Pitts']
  s.email        = 'brian.pitts@lonelyplanet.com'
  s.files        = ['lib/aws_mfa.rb', 'lib/aws_mfa/errors.rb']
  s.executables  = ['aws-mfa']
  s.homepage     = 'http://www.github.com/lonelyplanet/aws-mfa'
  s.license      = 'Apache-2.0'
  s.requirements = ['aws-cli']
  s.add_development_dependency 'rspec', '~> 3.1'
  s.add_development_dependency 'fakefs', '~> 0.6'
  s.add_development_dependency 'simplecov', '~> 0.9'
end
