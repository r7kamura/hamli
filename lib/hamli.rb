# frozen_string_literal: true

require_relative 'hamli/version'

module Hamli
  autoload :Errors, 'hamli/errors'
  autoload :Parser, 'hamli/parser'
  autoload :Range, 'hamli/range'
end
