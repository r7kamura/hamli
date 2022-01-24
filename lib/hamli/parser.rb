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

      parse_indent

      if @scanner.match?(/%/)
        parse_tag_line
      elsif @scanner.match?(/[#.]/)
        parse_div_line
      else
        parse_text_line
      end
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

    # Parse indent part.
    # e.g.     %div
    #      ^^^^
    def parse_indent
      @scanner.scan(/[ \t]*/)
      indent = indent_from_last_match
      @indents << indent if @indents.empty?

      if indent > @indents.last
        syntax_error!(Errors::UnexpectedIndentationError) unless expecting_indentation?

        @indents << indent
      else
        @stacks.pop if expecting_indentation?

        while indent < @indents.last && @indents.length > 1
          @indents.pop
          @stacks.pop
        end

        syntax_error!(Errors::MalformedIndentationError) if indent != @indents.last
      end
    end

    # Parse text line part.
    #   e.g. abc
    #        ^^^
    def parse_text_line
      @stacks.last << [:hamli, :text, parse_text_block]
      parse_line_ending
    end

    # Parse tag line part.
    #   e.g. %div{:a => "b"} c
    #        ^^^^^^^^^^^^^^^^^
    def parse_tag_line
      @scanner.pos += 1
      parse_tag_line_body(tag_name: parse_tag_name)
    end

    # Parse tag line part where %div is omitted.
    #   e.g. #a b
    #        ^^^^
    def parse_div_line
      parse_tag_line_body(tag_name: 'div')
    end

    # Parse tag line body part.
    #   e.g. %div{:a => "b"} c
    #            ^^^^^^^^^^^^^
    # @param [String] tag_name
    def parse_tag_line_body(tag_name:)
      attributes = parse_attributes
      tag = [:html, :tag, tag_name, attributes]
      @stacks.last << tag

      if @scanner.scan(/[ \t]*$/)
        content = [:multi]
        tag << content
        @stacks << content
      elsif @scanner.scan(/[ \t]*=([<>])*/)
        # TODO
      elsif @scanner.scan(%r{[ \t]*/[ \t]*})
        # TODO
      else
        @scanner.scan(/[ \t]+/)
        tag << [:hamli, :text, parse_text_block]
      end
      parse_line_ending
    end

    # Parse tag name part.
    #   e.g. %div{:a => "b"}
    #         ^^^
    # @return [String, nil]
    def parse_tag_name
      @scanner.scan(/([-:\w]+)/)
    end

    # Parse attribute shortcuts part.
    #   e.g. #a
    #        ^^
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
    #   e.g. #a
    #        ^^
    #   e.g. %div{:b => "b"}
    #            ^^^^^^^^^^^
    def parse_attributes
      attributes = %i[html attrs]
      attributes += parse_attribute_shortcuts
      attributes += parse_attribute_braces
      attributes
    end

    # Parse attribute braces part.
    #   e.g. %div{:a => "b"}
    #            ^^^^^^^^^^^
    #   e.g. %div(a=b)
    #            ^^^^^
    #   e.g. %div[a, :b]
    #            ^^^^^^^
    # @return [Array]
    def parse_attribute_braces
      result = []
      loop do
        if @scanner.match?(/\{/)
          result += parse_ruby_attributes
        elsif @scanner.match?(/\(/)
          result += parse_html_style_attributes
        elsif @scanner.match?(/\[/)
          result += parse_object_reference_attributes
        else
          break
        end
      end
      result
    end

    # Parse HTML-style attributes part.
    #   e.g. %div(a=b)
    #            ^^^^^
    # @todo
    def parse_html_style_attributes
      raise ::NotImplementedError
    end

    # Parse object reference attributes part.
    #   e.g. %div[a, :b]
    #            ^^^^^^^
    # @todo
    def parse_object_reference_attributes
      raise ::NotImplementedError
    end

    # Parse ruby attributes part.
    #   e.g. %div{:a => "b"}
    #            ^^^^^^^^^^^
    # @return [Array]
    def parse_ruby_attributes
      begin_ = @scanner.charpos
      value = @scanner.scan(
        /
          (?<braces>
            \{
              (?:[^{}] | \g<braces>)*
            \}
          )
        /x
      )
      [:hamli, :ruby_attributes, begin_, @scanner.charpos, value]
    end

    # Parse text block part.
    #   e.g. %div abc
    #            ^^^^
    # @return [Array]
    def parse_text_block
      result = [:multi]

      interpolate = parse_interpolate_line
      result << interpolate if interpolate

      until @scanner.eos?
        if @scanner.scan(/\r?\n[ \t]*(?=\r?\n)/)
          result << [:newline]
          next
        end

        @scanner.match?(/\r?\n[ \t]*/)
        indent = indent_from_last_match
        break if indent <= @indents.last

        @scanner.pos += @scanner.matched_size
        result << [:newline]
        result << parse_interpolate_line
      end

      result
    end

    # @return [Array, nil]
    def parse_interpolate_line
      return unless @scanner.match?(/.+/)

      begin_ = @scanner.charpos
      value = @scanner.matched
      @scanner.pos += @scanner.matched_size
      end_ = @scanner.charpos
      [:hamli, :interpolate, begin_, end_, value]
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

    # @return [Integer]
    def indent_from_last_match
      @scanner.matched.chars.map do |char|
        case char
        when "\t"
          4
        when ' '
          1
        else
          0
        end
      end.sum(0)
    end

    # @return [Boolean]
    def expecting_indentation?
      @stacks.length > @indents.length
    end
  end
end
