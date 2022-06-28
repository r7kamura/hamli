# frozen_string_literal: true

require 'temple'

module Hamli
  class Parser < ::Temple::Parser
    define_options(
      :file
    )

    def initialize(_options = {})
      super
      @file_path = options[:file] || '(__TEMPLATE__)'
    end

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
      elsif @scanner.match?(%r{/\[})
        parse_html_conditional_comment_line
      elsif @scanner.match?(%r{/})
        parse_html_comment_line
      elsif @scanner.match?(/-#/)
        parse_haml_comment_line
      elsif @scanner.match?(/-/)
        parse_control_line
      elsif @scanner.match?(/=/)
        parse_output_line
      elsif @scanner.match?(/&=/)
        parse_escaped_output_line
      elsif @scanner.match?(/!=/)
        parse_non_escaped_output_line
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
      elsif @scanner.scan(/[ \t]*([<>]*)=/)
        # white_space_marker = @scanner[1]
        # without_outer_white_space = white_space_marker.include?('>') # TODO
        # without_inner_white_space = white_space_marker.include?('<') # TODO
        @scanner.skip(/[ \t]+/)
        begin_ = @scanner.charpos
        content = parse_broken_lines
        end_ = @scanner.charpos
        block = [:multi]
        tag << [:hamli, :position, begin_, end_, [:hamli, :output, false, content, block]]
        @stacks << block
      elsif @scanner.scan(%r{[ \t]*/[ \t]*})
        # Does nothing.
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
      attributes += parse_attributes_groups
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
    def parse_attributes_groups
      result = []
      loop do
        if @scanner.match?(/\{/)
          result += [parse_ruby_attributes]
        elsif @scanner.match?(/\(/)
          result += parse_html_style_attributes
        elsif @scanner.match?(/\[/)
          result += [parse_object_reference]
        else
          break
        end
      end
      result
    end

    # Parse HTML-style attributes part.
    #   e.g. %div(a=b)
    #            ^^^^^
    # @return [Array]
    def parse_html_style_attributes
      @scanner.pos += 1
      result = []
      until @scanner.scan(/\)/)
        syntax_error!(Errors::UnexpectedEosError) if @scanner.eos?

        @scanner.scan(/[ \t\r\n]+/)

        if (attribute = parse_html_style_attribute)
          result << attribute
        end
      end
      result
    end

    # Parse HTML-style attribute part.
    #   e.g. %div(key1=value1 key2="value2" key3)
    #             ^^^^^^^^^^^
    # @return [Array, nil]
    def parse_html_style_attribute
      return unless @scanner.scan(/[-:\w]+/)

      name = @scanner[1]

      @scanner.scan(/[ \t]*/)
      return [:html, :attr, name, [:static, true]] unless @scanner.scan(/=/)

      @scanner.scan(/[ \t]*/)
      unless (quote = @scanner.scan(/["']/))
        return unless (variable = @scanner.scan(/(@@?|\$)?\w+/))

        return [:html, :attr, name, [:dynamic, variable]]
      end

      [:html, :attr, name, parse_quoted_attribute_value(quote)]
    end

    # Parse quoted attribute value part.
    #   e.g. %input(type="text")
    #                    ^^^^^^
    # @note Skip closing quote in {}.
    # @param [String] quote ' or ".
    # @return [Array]
    def parse_quoted_attribute_value(quote)
      begin_ = @scanner.charpos
      end_ = nil
      value = +''
      count = 0
      loop do
        if @scanner.match?(/#{quote}/)
          if count.zero?
            end_ = @scanner.charpos
            @scanner.pos += @scanner.matched_size
            break
          else
            @scanner.pos += @scanner.matched_size
            value << @scanner.matched
          end
        elsif @scanner.skip(/\{/)
          count += 1
          value << @scanner.matched
        elsif @scanner.skip(/\}/)
          count -= 1
          value << @scanner.matched
        else
          value << @scanner.scan(/[^{}#{quote}]*/)
        end
      end
      [:hamli, :interpolate, begin_, end_, value]
    end

    # Parse object reference attributes part.
    #   e.g. %div[a, :b]
    #            ^^^^^^^
    # @return [Array]
    def parse_object_reference
      begin_ = @scanner.charpos
      value = @scanner.scan(
        /
          (?<brackets>
            \[
              (?:[^\[\]] | \g<brackets>)*
            \]
          )
        /x
      )
      [:hamli, :object_reference, [:hamli, :position, begin_, @scanner.charpos, value]]
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
      [:hamli, :ruby_attributes, [:hamli, :position, begin_, @scanner.charpos, value]]
    end

    # Parse HTML comment part.
    #   e.g. /[if IE]
    #        ^^^^^^^^
    def parse_html_conditional_comment_line
      @scanner.pos += 1
      condition = @scanner.scan(
        /
          (?<brackets>
            \[
              (?:[^\[\]] | \g<brackets>)*
            \]
          )
        /x
      )
      block = [:multi]
      @stacks.last << [:html, :condcomment, condition, block]
      @stacks << block
      parse_line_ending
    end

    # Parse HTML comment part.
    #   e.g. / abc
    #        ^^^^^
    def parse_html_comment_line
      @scanner.pos += 1
      block = [:multi]
      block << [:static, @scanner.scan(/[^\r\n]*/)]
      @stacks.last << [:html, :comment, block]
      @stacks << block
      parse_line_ending
    end

    # Parse Haml comment part.
    #   e.g. -# abc
    #        ^^^^^^
    def parse_haml_comment_line
      @scanner.pos += 2
      @scanner.scan(/[^\r\n]*/)
      while !@scanner.eos? && (@scanner.match?(/[ \t]*(?=\r|$)/) || peek_indent > @indents.last)
        @scanner.scan(/[^\r\n]*/)
        parse_line_ending
      end
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
      return unless @scanner.match?(/[^\r\n]+/)

      begin_ = @scanner.charpos
      value = @scanner.matched
      @scanner.pos += @scanner.matched_size
      end_ = @scanner.charpos
      [:hamli, :interpolate, begin_, end_, value]
    end

    # Parse escaped output line part.
    #   e.g. != abc
    #        ^^^^^^
    # @todo Support :escape_html option on this parser, then rethink about escaping.
    def parse_non_escaped_output_line
      @scanner.pos += 1
      parse_output_line
    end

    # Parse escaped output line part.
    #   e.g. &= abc
    #        ^^^^^^
    def parse_escaped_output_line
      @scanner.pos += 2
      @scanner.scan(/[ \t]*/)
      parse_ruby_line(escaped: true, name: :output)
    end

    # Parse output line part.
    #   e.g. = abc
    #        ^^^^^
    def parse_output_line
      @scanner.pos += 1
      @scanner.scan(/[ \t]*/)
      parse_ruby_line(escaped: false, name: :output)
    end

    # Parse control line part.
    #   e.g. - abc
    #        ^^^^^
    def parse_control_line
      @scanner.pos += 1
      @scanner.scan(/[ \t]*/)
      parse_ruby_line(escaped: false, name: :control)
    end

    # @param [Boolean] escaped
    # @param [Symbol] name
    def parse_ruby_line(escaped:, name:)
      @scanner.scan(/[ \t]*/)
      block = [:multi]
      begin_ = @scanner.charpos
      content = parse_broken_lines
      end_ = @scanner.charpos
      @stacks.last << [:hamli, :position, begin_, end_, [:hamli, name, escaped, content, block]]
      @stacks << block
    end

    # @note Broken line means line-breaked lines, separated by trailing "," or "|".
    # @return [String]
    def parse_broken_lines
      result = +''
      result << @scanner.scan(/[^\r\n]*/)
      while result.end_with?(',') || (result.end_with?('|') && (result !~ /\bdo\s*\|[^|]*\|\z/))
        syntax_error!(Errors::UnexpectedEosError) unless @scanner.scan(/\r?\n/)

        result << "\n"
        result << @scanner.scan(/[^\r\n]*/)
      end
      lines = result.lines
      result.gsub!(/\|$/, '') if lines.length >= 2 && lines.all? { |line| line.end_with?("|\n") }
      result.delete_suffix("\n")
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
      (@scanner.matched || '').chars.map do |char|
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

    # @return [Integer] Indent level.
    def peek_indent
      @scanner.match?(/[ \t]*/)
      indent_from_last_match
    end
  end
end
