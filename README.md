# Jpty

PTY for jruby using expectj.

## Installation

Add this line to your application's Gemfile:

    gem 'jpty'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install jpty

## Usage

    require 'jpty'

    shell = JPTY.spawn("/bin/sh", 5)
    shell.send("echo Chunder\n")
    shell.expect("Chunder")

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

