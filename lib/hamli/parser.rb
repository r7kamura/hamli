# frozen_string_literal: true

require 'temple'

module Hamli
  class Parser < ::Temple::Parser
    # @param [String] source Haml template source.
    # @return [Array]
    def call(source)
      @stacks = [%i[multi]]
      @indents = []
      @scanner = ::StringScanner.new(source)
      parse_block until @scanner.eos?
      @stacks[0]
    end

    private

    def parse_block
      return if parse_blank_line

      parse_tag_line ||
        syntax_error!(Errors::UnknownLineIndicatorError)
    end

    # @return [Boolean]
    def parse_blank_line
      if @scanner.scan(/[ \t]*$/)
        parse_line_ending
        true
      else
        false
      end
    end

    # @return [Boolean]
    def parse_line_ending
      if @scanner.scan(/\r?\n/)
        @stacks.last << [:newline]
        true
      else
        false
      end
    end

    # Parse tag line part.
    #   e.g. %div abc
    #        ^^^^^^^^
    # @return [Boolean]
    def parse_tag_line
      if @scanner.scan(/%/)
        tag_name = parse_tag_name
        attributes = parse_attributes
        tag = [:html, :tag, tag_name, attributes]
        @stacks.last << tag

        if @scanner.scan(/[ \t]*$/)
          content = [:multi]
          tag << content
          @stacks << content
        elsif @scanner.skip(/[ \t]*=([<>])*/)
          # TODO
        elsif @scanner.skip(%r{[ \t]*/[ \t]*})
          # TODO
        else
          @scanner.scan(/[ \t]+/)
          tag << [:haml, :text, :inline, parse_text_block]
        end
        parse_line_ending
        true
      else
        false
      end
    end

    # Parse tag name part.
    #   e.g. %div{:a => "b"}
    #         ^^^
    # @return [String, nil]
    def parse_tag_name
      @scanner.scan(/([-:\w]+)/)
    end

    # Parse attribute shortcuts part.
    #   e.g. %div#a
    #            ^^
    #   e.g. %div.a
    #            ^^
    # @return [Array<Array>]
    def parse_attribute_shortcuts
      result = []
      while @scanner.scan(/([#.])([-:\w]+)/)
        marker = @scanner[1]
        value = @scanner[2]
        name = marker == '#' ? 'id' : 'class'
        result << [:html, :attr, name, [:static, value]]
      end
      result
    end

    # Parse attributes part.
    #   e.g. %div{:a => "b"}
    #            ^^^^^^^^^^^
    #   e.g. %div(a=b)
    #            ^^^^^^
    #   e.g. %div(a: b)
    #            ^^^^^^
    #   e.g. %div(a)
    #            ^^^
    def parse_attributes
      attributes = %i[html attrs]
      attributes + parse_attribute_shortcuts
    end

    # Parse text block part.
    #   e.g. %div abc
    #            ^^^^
    # @return [String]
    def parse_text_block
      @scanner.scan(/.*/)
    end

    # @param [Class] syntax_error_class A child class of Hamli::Errors::HamlSyntaxError.
    # @raise [Hamli::Errors::HamlSyntaxError]
    def syntax_error!(syntax_error_class)
      range = Range.new(index: @scanner.charpos, source: @scanner.string)
      raise syntax_error_class.new(
        column: range.column,
        file_path: @file_path,
        line: range.line,
        line_number: range.line_number
      )
    end
  end
end
