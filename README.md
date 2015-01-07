## weekly_snippets Gem

[![Gem Version](https://badge.fury.io/rb/weekly_snippets.svg)](https://badge.fury.io/rb/weekly_snippets)
[![Build Status](https://travis-ci.org/18F/weekly_snippets.svg?branch=master)](https://travis-ci.org/18F/weekly_snippets)
[![Code Climate](https://codeclimate.com/github/18F/weekly_snippets/badges/gpa.svg)](https://codeclimate.com/github/18F/weekly_snippets)
[![Test Coverage](https://codeclimate.com/github/18F/weekly_snippets/badges/coverage.svg)](https://codeclimate.com/github/18F/weekly_snippets)

Standardizes different weekly snippet formats into a common format,
[munges](http://en.wikipedia.org/wiki/Mung_(computer_term)) snippet text
according to user-supplied rules, performs redaction of internal information,
and publishes snippets in plaintext or Markdown format.

Downloads and API docs are available on the [weekly_snippets RubyGems
page](https://rubygems.org/gems/weekly_snippets). API documentation is written
using [YARD markup](http://yardoc.org/).

Contributed by the 18F team, part of the United States General Services
Administration: https://18f.gsa.gov/

### Motivation

This gem was extracted from [the 18F Hub Joiner
plugin](https://github.com/18F/hub/blob/master/_plugins/joiner.rb). That
plugin manipulates [Jekyll-imported data](http://jekyllrb.com/docs/datafiles/)
by removing or promoting private data, building indices, and performing joins
between different data files so that the results appear as unified collections
in Jekyll's `site.data` object. It serves as the first stage in a pipeline
that also builds cross-references and canonicalizes data before generating
static HTML pages and other artifacts.

### Installation

Add this line to your application's Gemfile:

```ruby
gem 'weekly_snippets'
```

And then execute:
```
$ bundle
```

Or install it yourself as:
```
$ gem install weekly_snippets
```

### Usage

The [18F Hub](https://github.com/18F/hub) processes snippet data as [CSV
files](https://en.wikipedia.org/wiki/Comma-separated_values) harvested from a
web-based spreadsheet, stored using [timestamped
filenames](http://en.wikipedia.org/wiki/ISO_8601#Calendar_dates) in the
[Jekyll _data folder](http://jekyllrb.com/docs/datafiles/). Since we have
experimented with different CSV column formats, we keep the data files
corresponding to each version in separate directories:

```
$ ls -1d _data/private/snippets/*
_data/private/snippets/v1/
_data/private/snippets/v2/
_data/private/snippets/v3/
```

The content of the lattermost `v3` directory as of writing:

```
$ ls -1 _data/private/snippets/v3
20141208.csv
20141215.csv
20141222.csv
```

With this data in-place, the Hub performs the following steps:

#### Standardize versions

The [18F Hub joiner.rb
plugin](https://github.com/18F/hub/blob/master/_plugins/joiner.rb) defines
this map from version names to `Version` objects:

```ruby
# Used to standardize snippet data of different versions before joining
# and publishing.
SNIPPET_VERSIONS = {
  'v1' => WeeklySnippets::Version.new(
    version_name:'v1',
    field_map:{
      'Username' => 'username',
      'Timestamp' => 'timestamp',
      'Name' => 'full_name',
      'Snippets' => 'last-week',
      'No This Week' => 'this-week',
    }
  ),
  'v2' => WeeklySnippets::Version.new(
    version_name:'v2',
    field_map:{
      'Timestamp' => 'timestamp',
      'Public vs. Private' => 'public',
      'Last Week' => 'last-week',
      'This Week' => 'this-week',
      'Username' => 'username',
    },
    markdown_supported: true
  ),
  'v3' => WeeklySnippets::Version.new(
    version_name:'v3',
    field_map:{
      'Timestamp' => 'timestamp',
      'Public' => 'public',
      'Username' => 'username',
      'Last week' => 'last-week',
      'This week' => 'this-week',
    },
    public_field: 'public',
    public_value: 'Public',
    markdown_supported: true
  ),
}
```

This map is then used to standardize batches of weekly snippets, converting
each different version to a common format, before joining the data with team
member information:

```ruby
# Snippet data is expected to be stored in files matching the pattern:
# _data/@source/snippets/[version]/[YYYYMMDD].csv
#
# resulting in the initial structure:
# site.data[@source][snippets][version][YYYYMMDD] = Array<Hash>
#
# After this function returns, the `standardized` will be of the form:
# site.data[snippets][YYYYMMDD] = Array<Hash>
standardized = ::WeeklySnippets::Version.standardize_versions(
  @data[@source]['snippets'], snippet_versions)
```

#### Munge

To accommodate the preferred formats employed by some team members, the
[18F Hub snippets.rb plugin](https://github.com/18F/hub/blob/master/_plugins/snippets.rb)
defines a Ruby block to
[munge](http://en.wikipedia.org/wiki/Mung_(computer_term)) the snippet data
before converting it to a uniform
[Markdown](http://daringfireball.net/projects/markdown/syntax) representation:

```ruby
MARKDOWN_SNIPPET_MUNGER = Proc.new do |text|
  text.gsub!(/^::: (.*) :::$/, "#{HEADLINE} \\1") # For jtag. ;-)
  text.gsub!(/^\*\*\*/, HEADLINE) # For elaine. ;-)
end
```

This block is then passed as an argument to `WeeklySnippets::Publisher.new()`,
discussed in the **Publish** section below.

#### Redact internal info

Text that should be available when published internally, but redacted from
publicly-published snippets, can be surrounded by `{{` and `}}` tokens:

```ruby
> require 'weekly_snippets/publisher'

# Instantiate a publisher for internally-visible snippets
> publisher = WeeklySnippets::Publisher.new(
    headline: "\n####", public_mode: false)

> snippets = [
    '- Did stuff{{ including private details}}',
    '{{- Did secret stuff}}',
    '- Did more stuff',
    '{{- Did more secret stuff',
    '- Yet more secret stuff}}',
  ]

# For internally-visible snippets, the text inside the `{{` and `}}`
# tokens will be preserved.
> puts publisher.redact! snippets.join("\n")

- Did stuff including private details
- Did secret stuff
- Did more stuff
- Did more secret stuff
- Yet more secret stuff

# Instantiate a publisher for publicly-visible snippets
> publisher = WeeklySnippets::Publisher.new(
    headline: "\n####", public_mode: true)

# For publicly-visible snippets, the text inside the `{{` and `}}`
# tokens will be removed.
> puts publisher.redact! snippets.join("\n")

- Did stuff
- Did more stuff
```

`WeeklySnippets::Publisher::publish()` automatically calls
`WeeklySnippets::Publisher::redact!`, so it shouldn't be necessary to call it
directly.

#### Publish

This is how the 
[18F Hub snippets.rb plugin](https://github.com/18F/hub/blob/master/_plugins/snippets.rb)
creates a `WeeklySnippets::Publisher` object and uses its `publish()` method
to process snippets and store the result in the [Jekyll site.data
object](http://jekyllrb.com/docs/datafiles/):

```ruby
publisher = ::WeeklySnippets::Publisher.new(
  headline: HEADLINE, public_mode: site.config['public'],
  markdown_snippet_munger: MARKDOWN_SNIPPET_MUNGER)
site.data['snippets'] = publisher.publish site.data['snippets']
```

### Contributing

1. Fork the repo ( https://github.com/18F/weekly_snippets/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

Feel free to ping [@mbland](https://github.com/mbland) with any questions you
may have, especially if the current documentation should've addressed your
needs, but didn't.

### Public domain

This project is in the worldwide [public domain](LICENSE.md). As stated in
[CONTRIBUTING](CONTRIBUTING.md):

> This project is in the public domain within the United States, and copyright
> and related rights in the work worldwide are waived through the
> [CC0 1.0 Universal public domain dedication](https://creativecommons.org/publicdomain/zero/1.0/).
>
> All contributions to this project will be released under the CC0 dedication.
> By submitting a pull request, you are agreeing to comply with this waiver of
> copyright interest.
