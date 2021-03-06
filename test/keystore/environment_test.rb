require_relative '../test_helper'
require 'stringio'

module SymmetricEncryption
  class FileTest < Minitest::Test
    describe SymmetricEncryption::Keystore::Environment do
      after do
        # Cleanup generated encryption key files.
        `rm tmp/tester* 2> /dev/null`
      end

      describe '.new_key_config' do
        let :version do
          10
        end

        let :keystore_config do
          SymmetricEncryption::Keystore::Environment.new_key_config(
            cipher_name: 'aes-256-cbc',
            app_name:    'tester',
            environment: 'test',
            version:     version
          )
        end

        it 'increments the version' do
          assert_equal 11, keystore_config[:version]
        end

        describe 'with 255 version' do
          let :version do
            255
          end

          it 'handles version wrap' do
            assert_equal 1, keystore_config[:version]
          end
        end

        describe 'with 0 version' do
          let :version do
            0
          end

          it 'increments version' do
            assert_equal 1, keystore_config[:version]
          end
        end

        it 'retains the env var name' do
          assert_equal 'TESTER_TEST_V11', keystore_config[:key_env_var]
        end

        it 'retains cipher_name' do
          assert_equal 'aes-256-cbc', keystore_config[:cipher_name]
        end
      end

      describe '.new_config' do
        let :environments do
          %i[development test acceptance preprod production]
        end

        let :config do
          SymmetricEncryption::Keystore::Environment.new_config(
            app_name:     'tester',
            environments: environments,
            cipher_name:  'aes-128-cbc'
          )
        end

        it 'creates keys for each environment' do
          assert_equal environments, config.keys, config
        end

        it 'use test config for development and test' do
          assert_equal SymmetricEncryption::Keystore.dev_config, config[:test]
          assert_equal SymmetricEncryption::Keystore.dev_config, config[:development]
        end

        it 'each non test environment has a key encryption key' do
          (environments - %i[development test]).each do |env|
            assert config[env][:ciphers].first[:key_encrypting_key], "Environment #{env} is missing the key encryption key"
          end
        end

        it 'every environment has ciphers' do
          environments.each do |env|
            assert ciphers = config[env][:ciphers], "Environment #{env} is missing ciphers: #{config[env].inspect}"
            assert_equal 1, ciphers.size
          end
        end

        it 'creates an encrypted key file for all non-test environments' do
          (environments - %i[development test]).each do |env|
            assert ciphers = config[env][:ciphers], "Environment #{env} is missing ciphers: #{config[env].inspect}"
            assert ciphers.first[:key_env_var], "Environment #{env} is missing key_env_var: #{ciphers.inspect}"
          end
        end
      end

      describe '#read' do
        let :key do
          SymmetricEncryption::Key.new
        end

        let :keystore do
          SymmetricEncryption::Keystore::Environment.new(key_env_var: 'TESTER_ENV_VAR', key_encrypting_key: key)
        end

        it 'reads the key' do
          ENV['TESTER_ENV_VAR'] = Base64.strict_encode64(key.encrypt('TEST'))
          assert_equal 'TEST', keystore.read
        end
      end
    end
  end
end
