class Holder
	constructor: (@vals)->

	get: (name)->
		@vals[ name ]

	set: (name, val)->
		@vals[ name ] = val

	serialize: ->
		@vals

class Ref
	constructor: (@base, @path = [])->

	addPath: (part)->
		@path.push part

	get: ->
		res = @base

		for v in @path
			if res instanceof Holder
				res = res.get v
			else
				res = res[ v ]

#		console.log 'get', @base, @path, '->', res
		res

	set: (value)->
		res = @base

		if @path.length > 0
			for v in @path[ 0..-2 ]
				if res instanceof Holder
					res = res.get v
				else
					res = res[ v ]

			prop = @path[-1..-1][0]
			if res instanceof Holder
				res.set prop, value
			else
				res[ prop ] = value
		else
			throw new Error "Unable to assign value"

module.exports =
	Holder: Holder
	Ref: Ref
