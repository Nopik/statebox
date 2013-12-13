util = require 'util'
utils = require './utils'
Q = require 'q'
_ = require 'underscore'

class SimpleAction
	constructor: (@name, @args = [], @async = false )->

	execute: (ctx, triggerValues)->
		action = ctx.getActions()?[ @name ]

		if action?
			args = []
			q = utils.reduce @args, (arg)->
				arg.evaluate( ctx, triggerValues ).then (a)->
					args.push a

			q.then ->
				res = action.invoke( ctx, args )

				if @async
					null
				else
					res
		else
			Q.reject new Error( "Unknown action #{@name}" )

class ConditionalAction
	constructor: (@condition, @actions)->

	execute: (ctx, triggerValues)->
		@condition.evaluate( ctx, triggerValues ).then (cond)=>
			if cond == true
				utils.reduce @actions, (ea)=>
					ea.execute( ctx, triggerValues )
			else
				{}

class ExpressionAction
	constructor: (@expression)->

	execute: (ctx, triggerValues)->
		@expression.evaluate( ctx, triggerValues )

module.exports =
	SimpleAction: SimpleAction
	ConditionalAction: ConditionalAction
	ExpressionAction: ExpressionAction
