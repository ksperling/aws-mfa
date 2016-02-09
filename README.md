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

By default `aws-mfa` will use the default profile from aws cli, to specify a different profile to use simply use the `--profile` parameter like you normally would with the aws cli

There are two ways you can use `aws-mfa`:

### Eval

The first is to use it to alter the environment of your current shell. To do this, run `eval $(aws-mfa)`. Now any command that uses the standard AWS environment variables should work.

### Wrapper

The second is to use it to alter the environment of a single invocation of a program. `aws-mfa` tries to execute its arguments. `aws-mfa aws` would run the aws cli, `aws-mfa kitchen` would run test-kitchen, and so on. You can safely setup an alias with `alias aws=aws-mfa aws`. With the alias, if you had set up autcompletion for `aws` it will still work.
