require 'digest/sha1'

class Shavaluator
	def initialize(opts)
		@redis = opts[:redis]
		@scripts = {}
	end

	def add(scripts, opts = {})
		defaults = {:bind => true}
		opts = {}.merge(defaults).merge(opts)

		scripts.each do |name, lua|
			name = name.to_sym

			@scripts[name.to_sym] = {
				:lua => lua,
				:sha => Digest::SHA1.hexdigest(lua),
			}

			if opts[:bind]
				raise "#{name} method already defined!" if respond_to?(name)
				define_singleton_method(name) do |*args|
					exec name, *args
				end
			end
		end

		nil
	end

	# This method calls a previously-added lua script. The argument syntax
	# is the same as redis-rb's eval and evalsha methods.
  #
  # @example EVAL without KEYS nor ARGV
  #   shavaluator.exec(:script)
  #     # => 1
  # @example EVAL with KEYS and ARGV as array arguments
  #   shavaluator.exec(:script, ["k1", "k2"], ["a1", "a2"])
  #     # => [["k1", "k2"], ["a1", "a2"]]
  # @example EVAL with KEYS and ARGV in a hash argument
  #   shavaluator.exec(:script, :keys => ["k1", "k2"], :argv => ["a1", "a2"])
  #     # => [["k1", "k2"], ["a1", "a2"]]
	def exec(script, *args)
		begin
			s = @scripts.fetch(script.to_sym)
		rescue KeyError
			raise "'#{script}' script has not been added yet!"
		end

		lua, sha = s.values_at(:lua, :sha)

		begin
			@redis.evalsha(s[:sha], *args)
		rescue Redis::CommandError => e
			if e.to_s.match /^NOSCRIPT/
				@redis.eval(s[:lua], *args)
			else
				raise
			end
		end
	end
end