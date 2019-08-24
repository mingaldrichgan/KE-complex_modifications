# frozen_string_literal: true

require_relative 'karabiner.rb'

class Variable
  NAMESPACE = File.basename($PROGRAM_NAME, '.json.rb').freeze

  attr_reader :if_set, :if_unset, :set, :unset

  def initialize(name)
    @if_set = Karabiner.variable_if("#{NAMESPACE}.#{name}", 1)
    @if_unset = Karabiner.variable_unless("#{NAMESPACE}.#{name}", 1)
    @set = Karabiner.set_variable("#{NAMESPACE}.#{name}", 1)
    @unset = Karabiner.set_variable("#{NAMESPACE}.#{name}", 0)
  end
end
