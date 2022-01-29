# frozen_string_literal: true

RSpec.describe Hamli::Parser do
  describe '#call' do
    subject do
      instance.call(source)
    end

    let(:instance) do
      described_class.new
    end

    let(:source) do
      raise NotImplementedError
    end

    context 'with tag line' do
      let(:source) do
        <<~HAML
          %div
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'div', %i[html attrs], [:multi, [:newline]]]]
        )
      end
    end

    context 'with tag line text block' do
      let(:source) do
        <<~HAML
          %div a b
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'div', %i[html attrs], [:hamli, :text, [:multi, [:hamli, :interpolate, 5, 8, 'a b']]]], [:newline]]
        )
      end
    end

    context 'with indentation' do
      let(:source) do
        <<~HAML
          %div
            %div
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'div', %i[html attrs], [:multi, [:newline], [:html, :tag, 'div', %i[html attrs], [:multi, [:newline]]]]]]
        )
      end
    end

    context 'with text line' do
      let(:source) do
        <<~HAML
          a
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:hamli, :text, [:multi, [:hamli, :interpolate, 0, 1, 'a']]], [:newline]]
        )
      end
    end

    context 'with ID shortcut' do
      let(:source) do
        <<~HAML
          #a
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'div', [:html, :attrs, [:html, :attr, 'id', [:static, 'a']]], [:multi, [:newline]]]]
        )
      end
    end

    context 'with class shortcut' do
      let(:source) do
        <<~HAML
          .a
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'div', [:html, :attrs, [:html, :attr, 'class', [:static, 'a']]], [:multi, [:newline]]]]
        )
      end
    end

    context 'with both shortcuts' do
      let(:source) do
        <<~HAML
          .a#b
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'div', [:html, :attrs, [:html, :attr, 'class', [:static, 'a']], [:html, :attr, 'id', [:static, 'b']]], [:multi, [:newline]]]]
        )
      end
    end

    context 'with Ruby attributes' do
      let(:source) do
        <<~HAML
          %div{ :a => b }
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'div', [:html, :attrs, [:hamli, :ruby_attributes, [:hamli, :position, 4, 15, '{ :a => b }']]], [:multi, [:newline]]]]
        )
      end
    end

    context 'with Ruby attributes with nested braces' do
      let(:source) do
        <<~HAML
          %div{ :data => { a => b } }
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'div', [:html, :attrs, [:hamli, :ruby_attributes, [:hamli, :position, 4, 27, '{ :data => { a => b } }']]], [:multi, [:newline]]]]
        )
      end
    end

    context 'with Ruby attributes with line break' do
      let(:source) do
        <<~HAML
          %div{ :a => b,
                :c => d}
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'div', [:html, :attrs, [:hamli, :ruby_attributes, [:hamli, :position, 4, 29, "{ :a => b,\n      :c => d}"]]], [:multi, [:newline]]]]
        )
      end
    end

    context 'with HTML-style attributes with boolean value' do
      let(:source) do
        <<~HAML
          %div(a)
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'div', [:html, :attrs, [:html, :attr, nil, [:static, true]]], [:multi, [:newline]]]]
        )
      end
    end

    context 'with HTML-style attributes with local variable' do
      let(:source) do
        <<~HAML
          %div(a=b)
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'div', [:html, :attrs, [:html, :attr, nil, [:dynamic, 'b']]], [:multi, [:newline]]]]
        )
      end
    end

    context 'with HTML-style attributes with class variable' do
      let(:source) do
        <<~HAML
          %div(a=@@b)
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'div', [:html, :attrs, [:html, :attr, nil, [:dynamic, '@@b']]], [:multi, [:newline]]]]
        )
      end
    end

    context 'with HTML-style attributes with instance variable' do
      let(:source) do
        <<~HAML
          %div(a=@b)
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'div', [:html, :attrs, [:html, :attr, nil, [:dynamic, '@b']]], [:multi, [:newline]]]]
        )
      end
    end

    context 'with HTML-style attributes with global variable' do
      let(:source) do
        <<~HAML
          %div(a=$b)
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'div', [:html, :attrs, [:html, :attr, nil, [:dynamic, '$b']]], [:multi, [:newline]]]]
        )
      end
    end

    context 'with HTML-style attributes with multi keys' do
      let(:source) do
        <<~HAML
          %div(key1=value1 key2=value2)
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'div', [:html, :attrs, [:html, :attr, nil, [:dynamic, 'value1']], [:html, :attr, nil, [:dynamic, 'value2']]], [:multi, [:newline]]]]
        )
      end
    end

    context 'with HTML-style attributes with line break' do
      let(:source) do
        <<~HAML
          %div(key1=value1
               key2=value2)
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'div', [:html, :attrs, [:html, :attr, nil, [:dynamic, 'value1']], [:html, :attr, nil, [:dynamic, 'value2']]], [:multi, [:newline]]]]
        )
      end
    end

    context 'with HTML-style attributes with quoted value' do
      let(:source) do
        <<~HAML
          %div(a="b")
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'div', [:html, :attrs, [:html, :attr, nil, [:hamli, :interpolate, 8, 9, 'b']]], [:multi, [:newline]]]]
        )
      end
    end

    context 'with object reference' do
      let(:source) do
        <<~HAML
          %div[@user, :greeting]
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'div', [:html, :attrs, [:hamli, :object_reference, [:hamli, :position, 4, 22, '[@user, :greeting]']]], [:multi, [:newline]]]]
        )
      end
    end

    context 'with object reference and Ruby attributes' do
      let(:source) do
        <<~HAML
          %div[user]{:class => 'alpha bravo'}
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'div', [:html, :attrs, [:hamli, :object_reference, [:hamli, :position, 4, 10, '[user]']], [:hamli, :ruby_attributes, [:hamli, :position, 10, 35, "{:class => 'alpha bravo'}"]]], [:multi, [:newline]]]]
        )
      end
    end

    context 'with tag name and output block' do
      let(:source) do
        <<~HAML
          %div= a
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'div', %i[html attrs], [:hamli, :position, 6, 7, [:hamli, :output, false, 'a', [:multi, [:newline]]]]]]
        )
      end
    end

    context 'with HTML comment' do
      let(:source) do
        <<~HAML
          / a
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:html, :comment, [:multi, [:static, ' a'], [:newline]]]]
        )
      end
    end

    context 'with HTML comment with indent' do
      let(:source) do
        <<~HAML
          /
            %div a
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:html, :comment, [:multi, [:static, ''], [:newline], [:html, :tag, 'div', %i[html attrs], [:hamli, :text, [:multi, [:hamli, :interpolate, 9, 10, 'a']]]], [:newline]]]]
        )
      end
    end

    context 'with HTML conditional comment' do
      let(:source) do
        <<~HAML
          /[if IE]
            %div a
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:html, :condcomment, '[if IE]', [:multi, [:newline], [:html, :tag, 'div', %i[html attrs], [:hamli, :text, [:multi, [:hamli, :interpolate, 16, 17, 'a']]]], [:newline]]]]
        )
      end
    end

    context 'with Haml comment' do
      let(:source) do
        <<~HAML
          -# a
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:newline]]
        )
      end
    end

    context 'with Haml comment with indent' do
      let(:source) do
        <<~HAML
          -#
            a
              b
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:newline], [:newline], [:newline]]
        )
      end
    end

    context 'with Haml comment in tag' do
      let(:source) do
        <<~HAML
          %div
            -# a
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'div', %i[html attrs], [:multi, [:newline], [:newline]]]]
        )
      end
    end

    context 'with control line' do
      let(:source) do
        <<~HAML
          - a
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:hamli, :position, 2, 3, [:hamli, :control, false, 'a', [:multi, [:newline]]]]]
        )
      end
    end

    context 'with control line with pipe multi-line' do
      let(:source) do
        <<~HAML
          - a |
            b |
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:hamli, :position, 2, 12, [:hamli, :control, false, "a \n  b ", [:multi]]]]
        )
      end
    end

    context 'with control line that ends with pipe' do
      let(:source) do
        <<~HAML
          - a do |b|
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:hamli, :position, 2, 11, [:hamli, :control, false, 'a do |b|', [:multi]]]]
        )
      end
    end

    context 'with output line' do
      let(:source) do
        <<~HAML
          = a
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:hamli, :position, 2, 3, [:hamli, :output, false, 'a', [:multi, [:newline]]]]]
        )
      end
    end

    context 'with output line with line break' do
      let(:source) do
        <<~HAML
          = a,
              b
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:hamli, :position, 2, 10, [:hamli, :output, false, "a,\n    b", [:multi, [:newline]]]]]
        )
      end
    end

    context 'with escaped output line' do
      let(:source) do
        <<~HAML
          &= a
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:hamli, :position, 3, 4, [:hamli, :output, true, 'a', [:multi, [:newline]]]]]
        )
      end
    end

    context 'with non-escaped output line' do
      let(:source) do
        <<~HAML
          != a
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:hamli, :position, 3, 4, [:hamli, :output, false, 'a', [:multi, [:newline]]]]]
        )
      end
    end
  end
end
