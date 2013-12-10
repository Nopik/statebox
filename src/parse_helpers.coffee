StateBox = require '../lib/statebox'

class Helpers
	@getFlag: (name)->
		for k, v of StateBox.State.Flags
			if name.toLowerCase() == k.toLowerCase()
				return v
		throw new Error( "Unknown flag: #{name}" )

module.exports = Helpers
