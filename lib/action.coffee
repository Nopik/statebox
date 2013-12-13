util = require 'util'
utils = require './utils'
Q = require 'q'
_ = require 'underscore'

class SimpleAction
	constructor: (@name, @args = [], @async = false )->

	execute: (ctx, triggerValues)->
		action = ctx.getActions()?[ @name ]

		if action?
			args = _.map @args, (arg)-> arg.evaluate( ctx, triggerValues )

			action.invoke( args )
		else
			Q.reject new Error( "Unknown action #{@name}" )

#		Q.resolve {}

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
