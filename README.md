# shavaluator

This library provides a convenient wrapper for sending Lua scripts to a Redis server via `EVALSHA`.

## What is EVALSHA?

`EVALSHA` allows you to send Lua scripts to a Redis server by sending the SHA-1 hashes instead of actual script content. As long as the body of your script was previously sent to Redis via `EVAL` or `SCRIPT LOAD`, you can use `EVALSHA` to avoid the overhead of sending your entire Lua script over the network.

A Shavaluator object wraps a Redis client for executing Lua scripts. When executing Lua scripts, a shavaluator will always attempt `EVALSHA` first, falling back on `EVAL` if the script has not yet been cached by the Redis server.

## Example

```ruby
require 'redis'
require 'shavaluator'

# 1. Initialize a shavaluator with a Redis client
redis = Redis.new(:host => '127.0.0.1', :port => 6379)
shavaluator = Shavaluator.new(:redis => redis)

# 2. Add a series of named Lua scripts to the shavaluator.
shavaluator.add(
  :delequal => """
    if redis.call('GET', KEYS[1]) == ARGV[1] then
      return redis.call('DEL', KEYS[i])
    end
    return 0
   """
)

# 3. The 'delequal' script is now added to the shavaluator and bound
#    as a method. When you call this, the shavaluator will first attempt
#    an EVALSHA, and fall back onto EVAL.
shavaluator.delequal :keys => ['key'], :argv => ['val']
```

## Adding scripts

Before you can run Lua scripts, you should give each one a name and add them to a shavaluator.

```ruby
scripts = {
  :delequal => """
    if redis.call('GET', KEYS[1]) == ARGV[1] then
      return redis.call('DEL', KEYS[i])
    end
    return 0
   """,

  :zmembers => """
    local key = KEYS[1]
    local results = {}
    if redis.call('ZCARD', key) == 0 then
      return {}
    end
    for i = 1, #ARGV, 1 do
      local memberName = ARGV[i]
      if redis.call('ZSCORE', key, memberName) then
        table.insert(results, memberName)
      end
    end
    return results
   """,
}

shavaluator.add scripts
```

Adding a script does two things by default: it generates the SHA-1 of the script body, and binds the script name as a method on the shavaluator object. It **does not** perform any network operations, such as sending `SCRIPT LOAD` to the Redis server.

## Executing scripts

By default, adding a script to a shavaluator will bind each script as a method on the shavaluator object. These methods preserve [redis-rb](https://github.com/redis/redis-rb)'s calling convention for Lua scripts, where keys and script arguments are either passed via a hash, or as a pair of arrays.

- **hash**: `shavaluator.your_script :keys => ['key1', 'key2'], :argv => ['arg1', 'arg2']`
- **array pair**: `shavaluator.your_script ['key1', 'key2'], ['arg1', 'arg2']`

If you don't like the auto-binding interface, you can use the `exec` function, which takes the name of a script.

```ruby
shavaluator.exec 'your_script', :keys => ['key1', 'key2'], :argv => ['arg1', 'arg2']
```

## Class reference

### new(opts)

Creates a new Shavaluator object.

Options:

- `:redis`: (required) an instance of a [redis-rb](https://github.com/redis/redis-rb) client that the Shavaluator will use to connect to a Redis server.

### add(scripts, opts = {})

Adds Lua scripts to the shavaluator. scripts is a key/value object, mapping script names to script bodies.

Options:

- `:bind`: (defaults to `true`) new methods will be created for each script.

### exec(script_name, params...)

Executes the script corresponding to the provided `script_name`. Script parameters can be passed in two different ways. See [Executing scripts](#executing-scripts) for usage examples.
