Q = require 'q'

class Action
	constructor: (@type, @values = {}, @label = '')->

	execute: (ctx, values)->
		Q.resolve({})

module.exports = Action
