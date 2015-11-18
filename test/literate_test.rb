require 'minitest/autorun'
require File.expand_path(File.join(File.dirname(__FILE__), '../lib/literate'))
require 'fileutils'

class TestLiterate < Minitest::Test

  def setup
    ENV['TEST'] = 'true'
    remove_generated_templates!
  end

  def teardown
    remove_generated_templates!
  end

  def test_1_1
    run_literate
    r = `ruby #{relative_to_full('sample_data/template1-1.rb')}`.split("\n")
    assert_equal 'valid1.1.1', r[0]
    assert_equal 'valid1.2.1', r[1]
  end

  def test_1_2
    run_literate
    r = `ruby #{relative_to_full('sample_data/template1-2.rb')}`.split("\n")
    assert_equal 'valid1.1.2', r[0]
    assert_equal 'valid1.2.1', r[1]
    assert_equal 'valid1.3.2', r[2]
  end

  def test_2_1
    run_literate
    r = `ruby #{relative_to_full('sample_data/template2-1.rb')}`.split("\n")
    assert_equal 'valid2.1.1', r[0]
    assert_equal 'valid2.2.1', r[1]
  end

  def test_2_2
    run_literate
    r = `ruby #{relative_to_full('sample_data/template2-2.rb')}`.split("\n")
    assert_equal 'valid2.1.2', r[0]
    assert_equal 'valid2.2.1', r[1]
    assert_equal 'valid2.3.2', r[2]
  end

  def test_literaterc_absent
    run_literate
    f = File.open(relative_to_full('sample_data/template1-1.rb')).read
    assert f.match(/\#not-rendered/)
  end

  def test_literaterc_present
    Literate::Config.config_file = relative_to_full('.literaterc')
    run_literate
    f = File.open(relative_to_full('sample_data/template1-1.rb')).read
    assert !f.match(/\#not-rendered/)
  end

  private

  def run_literate
    Literate.extract_and_render(markdown_file_path, template_path)
  end

  def template_path
    relative_to_full('sample_data')
  end

  def markdown_file_path
    relative_to_full('sample_data/markdown.md')
  end

  GENERATED_TEMPLATES = ['template1-1.rb', 'template1-2.rb', 'template2-1.rb', 'template2-2.rb']
  def remove_generated_templates!
    GENERATED_TEMPLATES.each do |t|
      f = File.join(template_path, t)
      if File.exists?(f)
        FileUtils.rm(f)
      end
    end
  end

  def relative_to_full(relative)
     File.expand_path(File.join(File.dirname(__FILE__), relative))
  end
end
