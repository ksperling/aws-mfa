# AWS-MFA

[![Build Status](https://travis-ci.org/lonelyplanet/aws-mfa.svg)](https://travis-ci.org/lonelyplanet/aws-mfa)
[![Code Climate](https://codeclimate.com/repos/542b7941e30ba06a6101ef2b/badges/25d9c28493f8b29398d0/gpa.svg)](https://codeclimate.com/repos/542b7941e30ba06a6101ef2b/feed)
[![Test Coverage](https://codeclimate.com/repos/542b7941e30ba06a6101ef2b/badges/25d9c28493f8b29398d0/coverage.svg)](https://codeclimate.com/repos/542b7941e30ba06a6101ef2b/feed)

## Introduction

`aws-mfa` prepares the environment for commands that interact with AWS. It uses [AWS STS](http://docs.aws.amazon.com/cli/latest/reference/sts/index.html) to get temporary credentials. This is necessary if you have [MFA](https://aws.amazon.com/iam/details/mfa/) enabled on your account. The variables it sets are 

* AWS_SECRET_ACCESS_KEY
* AWS_ACCESS_KEY_ID
* AWS_SESSION_TOKEN
* AWS_SECURITY_TOKEN

## Installation

`aws-mfa` is available via [Rubygems](https://rubygems.org/gems/aws-mfa). To install it you can run `gem install aws-mfa`.

Before using `aws-mfa`, you must have the [AWS CLI](https://aws.amazon.com/cli/) installed (through whatever [method](http://docs.aws.amazon.com/cli/latest/userguide/installing.html) you choose) and configured (through `aws configure`).

## Usage

The very first time you run `aws-mfa` it will fetch the ARN for your MFA device and ask you to confirm it. Next, it will prompt you for the 6-digit code from your MFA device. For the next 12 hours, `aws-mfa` will not prompt you for anything. After 12 hours, your temporary credentials expire, so `aws-mfa` will prompt you for the 6-digit code again.

By default `aws-mfa` will use the default profile from aws cli; to specify a different profile to use simply use the `--profile` parameter or the `AWS_DEFAULT_PROFILE` environment variable like you normally would with the aws cli.

By default your temporary credentials will be stored in `~/.aws/mfa_credentials`; if you do not want the credentials to be written to disk, use the `--no-persist` option, or set `AWS_MFA_PERSIST=false`. This option is particularly useful in combination with `shell` mode (see below).

The default session validity of 12 hours can be changed with the `--session-duration` option, e.g. `--session-duration=900` would cause the temporary credentials to expire after 15 minutes (the minimum value accepted by AWS). This value can also be set using the `AWS_MFA_SESSION_DURATION` environment variable.

There are three ways you can use `aws-mfa`:

### Eval

The first is to use it to alter the environment of your current shell. To do this, run `eval $(aws-mfa)`. Now any command that uses the standard AWS environment variables should work. Note that if you specified a `--profile` on the command line, the `AWS_DEFAULT_PROFILE` environmenet variable will be set to that profile.

### Wrapper

The second is to use it to alter the environment of a single invocation of a program. `aws-mfa` tries to execute its arguments. `aws-mfa aws` would run the aws cli, `aws-mfa kitchen` would run test-kitchen, and so on. You can safely setup an alias with `alias aws=aws-mfa aws`. With the alias, if you had set up autcompletion for `aws` it will still work.

### Shell

The final option is to run `aws-mfa shell`. This will run a new instance of your shell with temporary credentials set up in the environment. If you shell is `bash` or `zsh` it will be configured such that the `aws` command will first check if your session is still valid and otherwise prompt for your MFA code again. This mode is particularly useful in combination with the `--no-persist` option of `aws-mfa` as it allows the session to be used interactively for multiple commands without saving the session credentials to disk. To discard the temporary credentials simply exit the sub-shell.


## IAM Policy

The following IAM policy enables the permissions required for a user to use `aws-mfa`. If auto-discovery of the MFA device is not needed only `sts:GetSessionToken` is required.

```
{ "Version": "2012-10-17",
  "Statement": [ {
    "Action": "sts:GetCallerIdentity",
    "Resource": "*",
    "Effect": "Allow"
  }, {
    "Action": "iam:ListMfaDevices",
    "Resource": "arn:aws:iam::*:user/${aws:username}",
    "Effect": "Allow"
  }, {
    "Action": "sts:GetSessionToken",
    "Resource": "*",
    "Condition": { "Bool": { "aws:SecureTransport": "true" } },
    "Effect": "Allow"
  } ]
}
```

## Standard Release Process

Maintainers should use the standard process below when releasing a new version. The text can be copied into a GitHub issue or PR to serve as a checklist.

```
- [ ] update `aws-mfa.gemspec`
  - [ ] update `s.version`
  - [ ] update `s.date`
  - [ ] add/remove any new/deleted items from `s.files`
- [ ] build the gem locally: `rake gem build aws-mfa.gemspec`
- [ ] install built gem locally: `gem install ./aws-mfa-x.x.x.gem`
- [ ] test the gem locally
  - [ ] test the first run experience: `rm -f ~/.aws/mfa_credentials ~/.aws/mfa_devices && aws-mfa`
  - [ ] test any changes in this release
- [ ] publish to rubygems: `gem push aws-mfa-x.x.x.gem`
- [ ] install the gem from rubygems and test (see testing steps above)
- [ ] create a release on GitHub https://github.com/lonelyplanet/aws-mfa/releases
```
