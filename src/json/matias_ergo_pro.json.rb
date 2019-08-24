#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require_relative '../lib/karabiner.rb'
require_relative '../lib/variable.rb'

def main
  puts JSON.pretty_generate(
    'title' => Device::NAME,
    'maintainers' => ['mingaldrichgan'],
    'rules' => [Rules::NavKeys, Rules::RightControl].map(&:rule)
  )
end

module Device
  NAME = 'Matias Ergo Pro Keyboard'

  CONDITION = {
    'description' => NAME,
    'type' => 'device_if',
    'identifiers' => [{ 'vendor_id' => 1452, 'product_id' => 591 }],
  }.freeze
end

module FromModifiers
  ANY = Karabiner.from_modifiers.freeze

  # Modifiers used while typing.
  TYPING = Karabiner.from_modifiers(nil, %w[caps_lock shift]).freeze
end

module Keys
  FUNCTION = (1..12).map { |n| "f#{n}" }.freeze
  TOP_ROW = FUNCTION + %w[escape delete_forward]

  NUMBERS = ('0'..'9').to_a.freeze
  LETTERS = ('a'..'z').to_a.freeze

  # Non-modifier keys used while typing.
  TYPING = (NUMBERS + LETTERS + %w[
    grave_accent_and_tilde hyphen equal_sign delete_or_backspace
    tab open_bracket close_bracket backslash
    semicolon quote return_or_enter
    comma period slash
    spacebar
  ]).freeze

  ARROW = %w[left right up down].map { |d| "#{d}_arrow" }.freeze

  # Non-arrow navigation keys.
  NAV = %w[home end page_up page_down].freeze

  # Modifiable keys when the navigation keys are used as a modifier.
  NAV_MODIFIABLE = (TOP_ROW + TYPING + ARROW).freeze

  # Modifiers clustered around the navigation keys.
  NAV_MODIFIERS = %w[right_command right_shift].freeze
end

module Rules
  module NavKeys
    TO_KEY = 'right_option'
    VAR = Variable.new("use_nav_keys_as_#{TO_KEY}").freeze

    def self.rule
      {
        'description' => "Change navigation keys to #{TO_KEY} if pressed with another key (#{Device::NAME})",
        'manipulators' => [
          Keys::NAV.combination(2).map do |keys|
            {
              'description' => "Change #{keys.join(' + ')} to #{TO_KEY}",
              'type' => 'basic',
              'from' => {
                'modifiers' => FromModifiers::ANY,
                'simultaneous' => key_codes(*keys),
                'simultaneous_options' => { 'to_after_key_up' => [VAR.unset] },
              },
              'to' => [VAR.set, { 'key_code' => TO_KEY }],
              'conditions' => [Device::CONDITION, VAR.if_unset],
            }
          end,
          Keys::NAV.product(Keys::NAV_MODIFIABLE + Keys::NAV_MODIFIERS).map do |nav_key, other_key|
            {
              'description' => "Change #{nav_key} to #{TO_KEY} if pressed with #{other_key}",
              'type' => 'basic',
              'from' => {
                'modifiers' => FromModifiers::ANY,
                'simultaneous' => key_codes(nav_key, other_key),
                'simultaneous_options' => { 'to_after_key_up' => [VAR.unset] },
              },
              'to' => [VAR.set, { 'key_code' => other_key, 'modifiers' => [TO_KEY] }],
              'conditions' => [Device::CONDITION, VAR.if_unset],
            }
          end,
          (Keys::NAV + Keys::NAV_MODIFIABLE).map do |key|
            {
              'description' => "Modify #{key} with #{TO_KEY} if variable is set",
              'type' => 'basic',
              'from' => { 'key_code' => key, 'modifiers' => FromModifiers::ANY },
              'to' => [{ 'key_code' => key, 'modifiers' => [TO_KEY] }],
              'conditions' => [Device::CONDITION, VAR.if_set],
            }
          end,
        ].flatten,
      }
    end
  end # module NavKeys

  module RightControl
    FROM_KEY = 'right_control'
    TO_KEY = 'b'
    VAR = Variable.new("use_#{FROM_KEY}_as_#{TO_KEY}").freeze

    def self.rule
      {
        'description' => "Change #{FROM_KEY} to #{TO_KEY} if pressed alone, or while typing (#{Device::NAME})",
        'manipulators' => (
          Keys::TYPING.map do |key|
            {
              'description' => "Set variable if #{key} is pressed",
              'type' => 'basic',
              'from' => { 'key_code' => key, 'modifiers' => FromModifiers::TYPING },
              'to' => [VAR.set, { 'key_code' => key }],
              'to_delayed_action' => { 'to_if_invoked' => [VAR.unset] },
              'conditions' => [Device::CONDITION, NavKeys::VAR.if_unset],
            }
          end + [
            {
              'description' => "Change #{FROM_KEY} to #{TO_KEY} if variable is set",
              'type' => 'basic',
              'from' => { 'key_code' => FROM_KEY, 'modifiers' => FromModifiers::ANY },
              'to' => [VAR.set, { 'key_code' => TO_KEY }],
              'to_delayed_action' => { 'to_if_invoked' => [VAR.unset] },
              'conditions' => [Device::CONDITION, VAR.if_set],
            },
            {
              'description' => "Change #{FROM_KEY} to #{TO_KEY} if pressed alone and not held down",
              'type' => 'basic',
              'from' => { 'key_code' => FROM_KEY, 'modifiers' => FromModifiers::ANY },
              'to' => [{ 'key_code' => FROM_KEY, 'lazy' => true }],
              'to_if_alone' => [VAR.set, { 'key_code' => TO_KEY }],
              'to_if_held_down' => [{ 'key_code' => FROM_KEY }],
              'to_delayed_action' => { 'to_if_invoked' => [VAR.unset] },
              'conditions' => [Device::CONDITION, VAR.if_unset],
              'parameters' => {
                # Set these parameters to the same value.
                'basic.to_if_alone_timeout_milliseconds' => 500, # Default value is 1000.
                'basic.to_if_held_down_threshold_milliseconds' => 500, # Default value.
              },
            },
          ]
        ),
      }
    end
  end # module RightControl
end # module Rules

def key_codes(*keys)
  keys.map { |key| { 'key_code' => key } }
end

main
