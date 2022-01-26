# frozen_string_literal: true

require 'temple'

module Hamli
  module Filters
    # Pass-through some expressions which are unknown for Temple.
    class Base < ::Temple::HTML::Filter
      # @param [Integer] begin_
      # @param [Integer] end_
      # @param [Array] expression
      # @return [Array]
      def on_hamli_position(begin_, end_, expression)
        [:hamli, :position, begin_, end_, compile(expression)]
      end

      # @param [Array] expression
      # @return [Array]
      def on_hamli_text(expression)
        [:hamli, :text, compile(expression)]
      end
    end
  end
end
