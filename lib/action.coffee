Q = require 'q'

class Action
	constructor: (@name, @args = [], @async = false )->
		@condition = null

	execute: (ctx, triggerValues)->
		Q.resolve({})

module.exports = Action
