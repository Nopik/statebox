Q = require 'q'

class SimpleAction
	constructor: (@name, @args = [], @async = false )->

	execute: (ctx, triggerValues)->
		Q.resolve({})

class ConditionalAction
	constructor: (@condition, @actions)->

	execute: (ctx, triggerValues)->
		#TODO: check condition, execute all actions
		Q.resolve({})

class ExpressionAction
	constructor: (@expression)->

	execute: (ctx, triggerValues)->
		#TODO: calculate expression
		Q.resolve({})

module.exports =
	SimpleAction: SimpleAction
	ConditionalAction: ConditionalAction
	ExpressionAction: ExpressionAction
