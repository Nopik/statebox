util = require 'util'
utils = require './utils'
Q = require 'q'

class SimpleAction
	constructor: (@name, @args = [], @async = false )->

	execute: (ctx, triggerValues)->
		Q.resolve({})

class ConditionalAction
	constructor: (@condition, @actions)->

	execute: (ctx, triggerValues)->
		if @condition.evaluate( ctx, triggerValues ) == true
			utils.reduce @actions, (ea)=>
				ea.execute( ctx, triggerValues )
		else
			Q.resolve({})

class ExpressionAction
	constructor: (@expression)->

	execute: (ctx, triggerValues)->
		@expression.evaluate( ctx, triggerValues )

		Q.resolve({})

module.exports =
	SimpleAction: SimpleAction
	ConditionalAction: ConditionalAction
	ExpressionAction: ExpressionAction
