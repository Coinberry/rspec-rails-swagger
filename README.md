# RSpec Swagger

The design of this is heavily influenced by the awesome [swagger_rails](https://github.com/domaindrivendev/swagger_rails) gem.

## Setup

- install gem
- `rails generate rspec:install`
- create `spec/swagger_helper.rb` ... would be nice to be a generator


## Running tests

Set up a test site for a specific version of Rails:
```
RAILS_VERSION=4.2.0
./make_site.sh
```

Re-run the tests:
```
bundle exec rspec
```
