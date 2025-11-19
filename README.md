# Files:
- paxos.ex: main Paxos layer source
- beb.ex: best effort broadcast (BEB) layer the Paxos layer is built upon. 
Mostly there to illustrate a possible way to implement layers in Elixir. Can be inlined into paxos.ex
- test_harness.ex: testing framework
- paxos_test.ex: collection of unit tests for the Paxos protocol
- test_script_local.exs: the test driver script for the local tests
- test_script.exs: the test driver script for the distributed tests
- uuid.ex: library for generating unique identifiers; used by 
the test script to generate unique node names
- seat_reserve.ex: a fault-tolerant implementation of the seat reservation service (requires a working implementation of the Paxos service!)
- README: this file

# Paxos interface:
- start(name, participants, upper): start an instance of a Paxos layer process; returns PID
- propose(pid, value): propose a value via the Paxos process associated with PID. N.B. for testability, this should do nothing except store the input value until start_ballot is invoked (see below).
- start_ballot(pid): ask the Paxos process process associated with PID to start a new ballot as the leader of that ballot. At this point the process should begin to execute the 2-phase Paxos protocol as the leader.

# Testing
To test Paxos, customise test_script.exs and/or test_script_local.exs as instructed in the comments. You may wish to comment out the more advanced tests initially.

Make sure there are no any leftover Erlang VMs from previous runs:

killall -9 beam.smp

Launch the test script by entering

iex test_script_local.exs

Or for distributed testing
 
iex test_script.exs

For convenience, helper scripts are also provided (Linux only) 

$ ./run_test_local.sh

or 

$ ./run_test.sh

# Debugging tips - warnings
1. Make sure you understand any Elixir warnings you receive, e.g. for unused variable names, and that they are indeed harmless.
2. The test framework may output its own warnings, *even for passing tests*. These warnings come in two flavours: (i) it took an unexpectedly large number of attempts/retries for your solution to come to consensus for the test (ii) there appear to be an unexpectedly large number of messages in some of your process message queues. If you find that your solution passes the simpler tests but fails more complex tests, double-check that you are not receiving any warnings for the passing tests since it may indicate an underlying issue or inefficiency in your solution.  

# Example application
The file seat_reserve.ex gives a fault-tolerant implementation of the seat
reservation service from Lab 5 that uses the Paxos service. Its API is slightly
amended in that the `start` function also requires a list of names
of the other participating service replicas.

Once your Paxos implementation is passing all the tests, you may wish to try it
out by customising example_script_local.exs. For convenience, a helper script
run_example_local.sh is also provided (Linux only). 

