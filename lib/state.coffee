Q = require 'q'
utils = require './utils'

class State
	constructor: (@name = '', @enterActions = [], @leaveActions = [], @triggerActions = [], @flags = 0)->

	hasFlag: (flag)->
		(@flags & flag) != 0x00

	enter: (ctx, values)->
		utils.reduce @enterActions, (ea)=>
			ea.execute( ctx, values )

	leave: (ctx, values)->
		utils.reduce @leaveActions, (ea)=>
			ea.execute( ctx, values )

	runTrigger: (ctx, name, values)->
		triggerAction = @findTriggerAction( name )

		if triggerAction?
			q = utils.reduce triggerAction.exe, (ea)=>
				ea.execute( ctx, values )

			q.then ->
				triggerAction.to
		else
			Q.resolve({}) #ignore unhandled trigger

	findTriggerAction: (name)->
		for triggerAction in @triggerActions
			if triggerAction.at == name
				return triggerAction

		undefined

	@Flags:
		Start: 0x01
		Finish: 0x02

module.exports = State
