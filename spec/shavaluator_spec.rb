require 'redis'
require 'yaml'
require 'shavaluator'

SCRIPTS = {
  :echo => "return ARGV[1]",
  :luaget => "return redis.call('GET', KEYS[1])",
  :setnxget => "redis.call('SETNX', KEYS[1], ARGV[1]); return redis.call('GET', KEYS[1]);",
}

describe Shavaluator do

	before :each do
		config = YAML.load_file(File.join(File.dirname(__FILE__), 'redis.yml'))
		@redis = Redis.new(config)
		@redis.flushdb
		@redis.script :flush
		@shavaluator = Shavaluator.new(:redis => @redis)
	end

	describe 'basic usage' do

		example 'hash syntax' do
			@shavaluator.add :setnxget => "redis.call('SETNX', KEYS[1], ARGV[1]); return redis.call('GET', KEYS[1]);"
			expect(@shavaluator.setnxget(:keys => [:foo], :argv => ['hello'])).to eql('hello')
			expect(@shavaluator.setnxget(:keys => [:foo], :argv => ['bye'])).to eql('hello')
		end

		example 'array syntax' do
			@shavaluator.add :setnxget => "redis.call('SETNX', KEYS[1], ARGV[1]); return redis.call('GET', KEYS[1]);"
			expect(@shavaluator.setnxget([:foo], ['hello'])).to eql('hello')
			expect(@shavaluator.setnxget([:foo], ['bye'])).to eql('hello')
		end

	end # describe 'basic usage'

	describe '#add' do

		it 'should create methods on the shavaluator object' do
			@shavaluator.add :fake => 'not a real script'
			expect(@shavaluator).to respond_to(:fake)
		end

		it 'should not create methods if the bind option is false' do
			@shavaluator.add({:fake => 'not a real script'}, :bind => false)
			expect(@shavaluator).not_to respond_to(:fake)
		end

		it 'should raise an exception if we try to bind the same script twice' do
			@shavaluator.add :fake => 'not a real script'
			expect { @shavaluator.add :fake => 'still not real' }.to raise_error
		end

	end # describe '#add'

	describe '#command' do

		before :each do
			@shavaluator.add(SCRIPTS)
		end

		it 'executes Lua scripts that take arguments' do
			expect(@shavaluator.exec(:echo, :argv => ['hello, world'])).to eql('hello, world')
		end

		it 'executes the same Lua script multiple times' do
			prev_commands = Integer(@redis.info['total_commands_processed'])
			iterations = 10

			iterations.times do
				expect(@shavaluator.exec(:echo, :argv => ['hello, world'])).to eql('hello, world')
			end

			# Commands processed in this example:
			# INFO
			# EVAL, for first failed EVALSHA
			# iterations * EVALSHA
			expect(
				Integer(@redis.info['total_commands_processed']) - prev_commands
			).to eql(iterations + 2)
		end

		it 'executes Lua scripts that take keys' do
			@redis.set :foobar, 'hello, world'
			expect(@shavaluator.exec(:luaget, :keys => [:foobar])).to eql('hello, world')
		end

		it 'executes Lua scripts with both keys and arguments' do
			expect(
				@shavaluator.exec(:setnxget, :keys => [:foobar], :argv => ['hello, world'])
			).to eql('hello, world')

			expect(
				@shavaluator.exec(:setnxget, :keys => [:foobar], :argv => ['goodbye, world'])
			).to eql('hello, world')
		end

	end # describe '#command'

end # describe Shavaluator