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
          %div a
        HAML
      end

      it 'returns expected S-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'div', %i[html attrs], [:hamli, :text, [:multi, [:hamli, :interpolate, 5, 6, 'a']]]], [:newline]]
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
  end
end
