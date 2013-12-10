StateBox = require '../lib/statebox'

class Helpers
	@getFlag: (name)->
		for k, v of StateBox.State.Flags
			if name.toLowerCase() == k.toLowerCase()
				return v
		throw new Error( "Unknown flag: #{name}" )

	@joinTriggers: (triggers, trigger)->
		triggers.enter = triggers.enter.concat trigger.enter if trigger.enter?
		triggers.leave = triggers.leave.concat trigger.leave if trigger.leave?
		triggers.at = triggers.at.concat trigger.at if trigger.at?

		triggers

module.exports = Helpers
