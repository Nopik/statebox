utils = require './utils'

class State
	constructor: (@name = '', @enterActions = [], @leaveActions = [], @flags = 0)->

	hasFlag: (flag)->
		(@flags & flag) != 0x00

	enter: (ctx, values)->
		utils.reduce @enterActions, (ea)=>
			ea.execute( ctx, values )

	leave: (ctx, values)->
		utils.reduce @leaveActions, (ea)=>
			ea.execute( ctx, values )

	@Flags:
		Start: 0x01
		Finish: 0x02

module.exports = State
