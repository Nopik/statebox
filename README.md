# statebox

Engine for running tons of state machines concurrently.

## Getting Started
Install the module with: `npm install statebox`

## Documentation

### Example state machine grammar

my_graph_id = 42 #global ctx val set

Graph g1
	State g
		->

def my_list
	action 1
	action 2

State foo [start, finish]
	->
		? trigger.from == "state.${id}"
			action1
		action 2

	<-
		? trigger.to == "state.${id}"
			action1
		action

	@timer.abc -> baz
		? ctx.id + action.id == trigger.id
			moveTo bar
		sendHttp
			port: 80
			method: POST
			url: url
		!sendHttp { port: 80, method: GET, url: url } #asynchronous
		sendHttp { port: 80, method: GET, url: url }
		ctx.response = sendHttp { url: url }
		call my_list #positional arguments, comma separated

	@timer.${id}
		kill


Actions:
	ctx.a = b #set
	timer: start, stop, set
	http: url, data
	rmq...
	kill...
	run: graph id
	conversions (string->json) #operator?
	log
	call list of actions
	trigger

## Release History
_(Nothing yet)_

## License
Copyright (c) 2013 Kamil Burzynski. Licensed under the MIT license.
