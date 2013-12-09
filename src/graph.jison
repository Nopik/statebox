/*
my_graph_id = 42 #global ctx val set

Graph g1
	State g
		->

def my_list
	action 1
	action 2

State foo
	->
		? trigger.from == "state.${id}"
			action1
		action 2

	<-
		? trigger.to == "state.${id}"
			action1
		action

	@timer.abc -> baz
		? ctx.id + action.foo.bar == trigger.id
			moveTo bar
		sendHttp
			port: 80
			method: POST
			url: url
		!sendHttp { port: 80, method: GET, url: url } #asynchronous
		sendHttp { port: 80, method: GET, url: url }
		ctx.response = sendHttp { url: url }
		ctx.a.b = [ "s", 2+3 ]
		call my_list #positional arguments, comma separated

	@timer.${id}
		kill
*/

%lex

%%

\s+ { return 'WS'; }
'[' { return '['; }
']' { return ']'; }
',' { return ','; }
';' { return ';'; }

'state' { return 'STATE'; }
\w+ { return 'WORD'; }

/* [0-9]+ { return 'NUM'; } */

/lex

%start graph

%%

graph
	: states { return $1; };

states
	: state { $$ = [ $1 ]; }
	| states opt_ws state { $$ = $1.concat( [ $3 ] ); };

state : STATE state_flags ';' { console.log($2); };

state_flags : { $$ = []; } | opt_ws '[' flags ']' { $$ = $3; };

flags : WORD { $$ = [ $1 ]; } | flags ',' opt_ws WORD { $$ = $1.concat( [ $4 ] ) };

opt_ws : | WS ;
