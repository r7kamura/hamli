# frozen_string_literal: true

require_relative 'hamli/version'

module Hamli
  autoload :Errors, 'hamli/errors'
  autoload :Filters, 'hamli/filters'
  autoload :Parser, 'hamli/parser'
  autoload :Range, 'hamli/range'
end
