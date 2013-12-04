class State
	constructor: (@name = '', @enterActions = [], @leaveActions = [], @flags = 0)->

	hasFlag: (flag)->
		(@flags & flag) != 0x00

	leave: ->

	enter: ->

	@Flags:
		Start: 0x01
		Finish: 0x02

module.exports = State
