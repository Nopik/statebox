# statebox

Engine for running tons of state machines concurrently.

<!---
## Getting Started
Install the module with: `npm install statebox`
-->

## Idea

The basic idea behind this project is to abstract the state machine and scriptability away from applications. It was created in CodeProject.com labs, when I was working there. At some point we were creating some notification micro service for internal use in our products. During the architecture design part of that module it became clear that we need some kind of scripting to handle tasks like 'what if there will be an error during notification delivery, we would like to retry few times', 'what if some user will want to have their messages delivered via email during business hours but via SMS during night?', etc. After some brainstorming I have realized that having remote scriptable state machine could solve all of our problems and many more. And here we go.

## Project status

This project currently consists of 2 repositories, statebox and statebox-server. Currently only first one is released (this repository). This code is meant to be embedded in other software, in a Node.js environment. The other repository, statebox-server, is just an example how to embed StateBox in Node.js application and expose its functionality over HTTP. Unfortunately, the statebox-server currently is basing on some proprietary code now and need to be slightly rewritten prior to the public release. I plan to do it in a nearby future, ping me if you are interested in this project.
 
Nevertheless, this repository is fully functioning, and already been tested in production, working flawlessly for few months.

Currently our systems do send small traffic to the StateBox, so probably at higher traffic rates some performance optimizations should be made - as current implementation can be optimized to be faster.

## How does it work?

Generally StateBox allows you to specify state machine graph using some simple language created just for this purpose. Each graph has a number of states (including start and stop states), and descriptions how transitions between states should be done. Each transition has a trigger (event which need to happen in order to start the transition) and list of actions which need to be done during the transition. States also have enter/leave list of actions.

Actions are configurable and generally you can add our own actions to integrate with your own systems. Few generic actions (like 'send HTTP requst' or 'send message to RabbitMQ') are already provided out of the box.
 
Since StateBox also support internal timers, it is trivial to set up a simple graph which sends some message to RabbitMQ, e.g. every hour. I have found this single feature quite useful, and often desired in my RabbitMQ-integrated products.

Once graph(s) are defined host application may ask StateBox to 'launch' a graph, i.e. to create instance of specified state machine. Such instance is called context. When some contexts are active, engine may process triggers addressed to them, causing them to update their internal state. In order to help with scriptability, engine is able to do some computations inside contexts. Each context has associated JSON object (available via 'ctx' variable in the script), and each trigger can carry JSON object as well (available via 'trigger' variable in the script). This allows user to create advanced graphs with business logic inside.

Engine also allows easy running of multiple versions of the code. You can have many contexts of some graph running, define new version of the graph, and then continue to spawn new contexts from new graph. In such scenario both old and new graphs are living side by side, which is be extremely useful in many deployment scenarios. 

As an advanced feature, a single context may spawn other contexts, from other graphs, much like function calling other functions in programming languages. That allow to split graphs into smaller pieces, reuse them, and be really independent when some part of graph changes often.

### Example

The whole project is engineered to allow, among others, constructs like this:

<pre>
Send state [start state]:
 on enter:
  start timer t1 with 10 second interval and 1 cycle
  send HTTP request, store result into ctx.result
  cancel t1 timer
  go to 'received' state
  
 on t1 tick:
  go to 'failed' state
  
Failed state [end state]:
 on enter:
  send message to RabbitMQ
  
Received state [end state]:
 on enter:
  do some processing 
  send HTTP result to RabbitMQ
</pre>

The above meta description translated to StateBox DSL will look like this:

<pre>
state send[start]
{
	-> {
		startTimer 't1', 10000, { count: 1 };
		= ctx.result = action.http( "http://example.com" );
		stopTimer 't1';
		trigger 'next'
	}
	
	@next -> received {}

	@timer.tick.t1 -> failed {}
}

state failed[end] {
	-> {
		= action.amqp( "amqp://rabbitmq.example.com", 'example-exchange', 'example-routing-key, { val: 42 } );
	}
}

state received[end] {
	-> {
		= ctx.processedResult = ctx.result.a + ctx.result.b;
		= action.amqp( "amqp://rabbitmq.example.com", 'example-exchange', 'example-routing-key, { result: ctx.processedResult } );
	}
}
</pre>

As you can see this example can be trivially extended to do other useful stuff, e.g. fetch some JSON from HTTP every 10 minutes and send it to RabbitMQ. If you provide action bindings for Redis or some other service, you will be easily able to use them as well.

### Short DSL grammar introduction

Really simplified BNF syntax:

<pre>
graph: [list of states]

state: state identifier [flags] { [list of triggers] }
 
trigger
 : -> { [list of actions] }
 | <- { [list of actions] }
 | @identifier { [list of actions] }
 | @identifier -> identifier { [list of actions] }
 
action
 : ? [expression] { [list of actions] }
 | = [assignment expression]
 | [async specifier] [action name] [arguments]
</pre>

Where:

identifier is an alphanumeric word

-> trigger means 'on state enter'

<- trigger means 'on state exit'

@A -> B trigger means 'when A happens, go to B'

the list of actions in each trigger lists what needs to be done when given trigger happens

? is conditional - if the given expression evaluates to true, the following list of actions will be executed

async specifier ('!' character) means that engine should not wait for the result of given action and proceed immediately to the next one

Example:

This example will start with 'a' state, set 'ctx.foo' to 42, wait for 'b' or 't' trigger. Depending on the trigger transition will be done to the matching state. 'b' trigger will cause cascade of transitions through 'b', 'c' states all the way to 'd', which will set 'ctx.bar' to 1 on arrival.

't' trigger will start timer and start counting its ticks.

<pre>
state a[start] {
	@test.name {
		= ctx.foo = 42;
	};

	@b -> b {};
	@t -> t {};
};

state b {
	@c -> c {};
};

state c {
	@c1 {
		trigger 'd';
	};

	@d -> d {};
};

state d {
	-> {
		= ctx.bar = 1;
	}
}

state t {
	-> {
		= ctx.tcnt = 0;
		startTimer 't1', 10, { firstIn: 1, count: 3 };
	}

	@timer.tick.t1 {
		= ctx.tcnt += 1;
	}
}
</pre>

## Release History

0.1.0 - first GitHub release

## License
Copyright (c) 2013-2014 Kamil Burzynski. Licensed under the MIT license.
