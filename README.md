# Literate

Literate extracts code from Leanpub Markdown files.

## Usage

Create a template. This might match the boilerplate that your reader starts with:

````
# code/sequencer.rb.erb

require 'bio'

class Sequencer

  <%= def_initialize %>

  <%= def_protein %>

end
````

Annotate code blocks. All options (`name`, `template`, `ver`) are required:

````
# chapters/1-sequencers.md

{lang='ruby',name='def_initialize',template='sequencer',ver='1'}
    def initialize
      @seq = Bio::Sequence::NA.new('auggcaccguccagauu')
    end
````

If you ran Literate now:

````
literate chapters/1-sequencers.md code/
````

It would generate the following file:

````
# code/sequencer-1.rb

require 'bio'

class Sequencer

  def initialize
    @seq = Bio::Sequence::NA.new('auggcaccguccagauu')
  end

end
````

Say you continued writing in your Markdown file for version two of the app. You first add this code block later on in the file, modifying the `initialize` method (note `ver='2'` here):

````
# chapters/1-sequencers.md

{lang='ruby',name='def_initialize',template='sequencer',ver='2'}
    def initialize(seq)
      @seq = Bio::Sequence::NA.new(seq)
    end
````

And then, also in version two, you define the other method:

````
# chapters/1-sequencers.md

{lang='ruby',name='def_protein',template='sequencer',ver='2'}
    def protein
      @seq.translate
    end
````

Running Literate again:

````
literate chapters/1-sequencers.md code/
````

Renders what you'd expect (note the file is versioned as `sequencer-2.rb`):

````
# code/sequencer-2.rb

require 'bio'

class Sequencer

  def initialize(seq)
    @seq = Bio::Sequence::NA.new(seq)
  end

  def protein
    @seq.translate
  end

end
````

## Config

Place the file `.literaterc` in your project's root directory. It is a YAML file. There are only two options.

**`filter_lines_matching`** (default: **none**)

An array of filters which will be treated as regular expressions. Lines in your code blocks matching these filters will not be included in the rendered file.

**`filter_leanpub_code_comments`** (default: **true**)

Leanpub code block comments will not be included in the rendered file. Example of one such comment in HTML:

````
<!-- leanpub-start-insert -->
````

Run the following to generate an example `.literaterc` in your working directory:

````
literate --gen-rc
````

## Dependencies

One: `diffy` for diffing codeblocks. `diffy` has no dependencies.

## Installation

Manual. Not on Rubygems at the moment.

## Other crazy ideas

1. Support adjacent automated testing
2. Support code blocks that execute code at a given version
3. Automatic code versioning by section number
4. Package gem with file monitoring option
