{deepEqual} = require '../util'
{diffArrays} = require '../diffMatchPatch'

module.exports = (model, path, inputs, callback, destroy) ->
  modelPassFn = model.pass 'fn'
  run = ->
    previous = model.get path
    value = callback (model.get input for input in inputs)...

    if Array.isArray(previous) && Array.isArray(value)
      diff = diffArrays previous, value
      for args in diff
        method = args[0]
        args[0] = path
        modelPassFn[method] args...
      return

    return value if deepEqual value, previous
    modelPassFn.set path, value
    return value

  out = run()

  # Create regular expression matching the path or any of its parents
  p = ''
  source = (for segment, i in path.split '.'
    "(?:#{p += if i then '\\.' + segment else segment})"
  ).join '|'
  reSelf = new RegExp '^' + source + '$'

  # Create regular expression matching any of the inputs or
  # child paths of any of the inputs
  source = ("(?:#{input}(?:\\..+)?)" for input in inputs).join '|'
  reInput = new RegExp '^' + source + '$'

  listener = model.on 'mutator', (mutator, mutatorPath, _arguments) ->
    return if _arguments[3] == 'fn'

    if reSelf.test(mutatorPath) && (test = model.get path) != out && (
      # Don't remove if both test and out are NaN
      test == test || out == out
    )
      model.removeListener 'mutator', listener
      destroy?()
    else if reInput.test mutatorPath
      process.nextTick -> out = run()
    return

  return out
