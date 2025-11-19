
defmodule Paxos do

 
  def start(name, participants, upper) do
    
    # this is used to give a starting unique value to each participant.
    my_index =
      case Enum.find_index(participants, fn p -> p == name end) do
        nil -> 0
        idx -> idx
      end

    
    ballot_step = length(participants)

    
    state = %{
      name: name,                    #idenfifier of the process
      participants: participants,    #list of all parteciapnt
      upper: upper,                  #pid of upper layer process

      
      my_index: my_index,           # my index in the participants list
      ballot_step: ballot_step,     # step to get unique ballot numbers
      next_ballot: my_index + 1,    # next ballot number to use

    
      my_value: nil,                # value this process wants to propose

      
      promised_ballot: nil,         # highest ballot promised
      accepted_ballot: nil,         # highest ballot accepted
      accepted_value: nil,          # value accepted

      
      promises: %{},                # map of promises received
      accepts: %{},                 # map of accepts received
  
      decided: false                # whether decision has been made   
    }

  
    pid = spawn(Paxos, :loop, [state])
    :global.register_name(name, pid)
    pid
  end

  # API for upper layer to propose a value.
  # this is used by the leader to set its value to propose. 
  # in my case is used bey the test.
  def propose(pid, val) do
    send(pid, {:propose, val})
  end

  # API for upper layer to start a new ballot.
  # this is used by the leader to start the ballot process.
  # in my case is used by the test.
  def start_ballot(pid) do
    send(pid, :start_ballot)
  end


  # the main loop of the paxos process.
  # this loop generally recieve message from all parteciapnt and act accordinly changing the state.
  def loop(state) do
    receive do

      
      # this is used by the leader(test) to set its value to propose.
      {:propose, val} ->
        loop(%{state | my_value: val})


      
      # this is where the leader starts the ballot process
      :start_ballot ->
      
        # b is the ballot we are starting now
        b = state.next_ballot
        # IO.puts("Leader #{state.name}: sending PREPARE #{b} to #{inspect state.participants}")

        # leader send prepare to all accpetors.
        # there is alos condition to chack of process failure. if so I do not do nothing.
        # self() is the pid of the leader process.
        Enum.each(state.participants, fn name ->
          case :global.whereis_name(name) do
            # if process is not found we do nothing
            # this is condition accounting for process failure.
            :undefined -> :ok
            pid -> send(pid, {:prepare, b, self()}) 
          end
        end)

        
        #this update ballot in the state 
        new_state = %{
          state |
          promises: %{},    
          accepts: %{},     
          decided: false,
          #guaranteed unique ballot numbers per leader.
          #this is smsart trick to avoid ballot collosion. 
          next_ballot: b + state.ballot_step
        }

        # loop with the new state
        loop(new_state)

      #start PHASE 1:
      # as i describe about prepare and promise phase.
      # this message,  send a ballot from leader to all acceptor.
      # the acceptor will check if the ballot just received is higher than the one it has already promised.
      # if so they will accept. no otherwise.
      {:prepare, b, leader_pid} ->
        promised = state.promised_ballot # ballor used by accpetor

    
        # this condiction check it ballot received it higher of the one already promised.
        # if so it reject the prepare.
        # otherwise it accept the prepare and send back a promise to the leader. 
        if promised != nil and b < promised do
          # IO.puts("Acceptor #{state.name}: REJECTING PREPARE #{b}, already promised #{promised}")
          loop(state)
        else
          # IO.puts("Acceptor #{state.name}: ACCEPTING PREPARE #{b} (old promised #{inspect promised})")
          new_state = %{state | promised_ballot: b} # update the promised ballot in the state.

          # acceptor send back to the leader, its promises, the ballot accepted and aknowledge aloso about previously accepted ballot, and value. 
          send(leader_pid, {
            :promise,
            state.name,
            b,
            state.accepted_ballot,
            state.accepted_value
          })
          
          #  recurse with the new state. new_state = %{state | promised_ballot: b} descrive above.
          loop(new_state) 
        end

      # PHASE 1:
      # this is stage where the leader recieve the promisethe pormise from accceptor.
      #i nthis stage the leader first will verfy thr ballot recieved is the same it send it. to avoid old ballot from other leader.
      # if the ballot is right it will store the promise in a map with all details about the poormose. this inclused the accepted ballot and value from acceptor. the highest value(if there is any) be use by the leader to to decide which value to propose in phase 2. if no value is present the leader will use its own value.
      # Lastly the leader record all partecipant to to chack if there is quorum(majority) to preceed phase 2.
      # if quorum not found the process will start the process form prepare again.   

      # i wll explain the name of that may be confusing.
      # from is name of accpetor process.
      # b ballot
      # ab acccepted ballot old.
      # accepted value old.
      {:promise, from, b, ab, av} ->

        # this is an operation require.
        # when leader send prepare b = next_ballot and then upgrade next_ballot = next_ballot + ballot_step.
        # therefore to compare the ballot recieved from acceptor(which i considering current one) i have ot substract at at the next one the ballot _step. I HOPE THIS IS CLEAR.
        current_ballot = state.next_ballot - state.ballot_step

        # Ignore PROMISE from an old ballot
        if b != current_ballot do
          # IO.puts("Leader #{state.name}: IGNORING PROMISE from #{from} for old ballot #{b}")
          loop(state) # recurse with the same state.
        else
          # if the ballot is right we store the promise in a map.
          new_promises = Map.put(state.promises, from, {ab, av})
          # IO.puts("Leader #{state.name}: stored PROMISE from #{from} -> {ab=#{inspect ab}, av=#{inspect av}}")

          # we are in stage where we are checking for quorum.
          # therefore this calculate the majority. NUMBER PARTECIAPANTS/2 + 1.
          majority = div(length(state.participants), 2) + 1

          
          # this statemtent clarly axplain itself.
          # it check it the mumber of partecipant that promised is higher of equal half + 1.
          # if so check if there are any previous values accpeted by acceptor. if so use the highest one.
          # otherwise use the leader value.
          # then we send the propose ot all active acceptor.
          # we update the state and we pass in phase 2.
          #if there is no quorum we restat from prepare.
          if map_size(new_promises) >= majority do
           
           # I am pretty sure there is a more elegant way to do this. But it works... 
           # this satify the condition require by the algorithm Paxos. which is to use vlaue of the highest old ballot accepted by acceptor if there is any.
           # therefore the Enum first filter into the map only the accepted ballot not nil.
           # then it use max to get the the highest one.
           # finally the value_to_propose chekc if there is value releated with higest old ballot, otheriwise use the one of the leader.   
            best =
              new_promises
              |> Enum.filter(fn {_p, {ab2, _v2}} -> ab2 != nil end)
              |> Enum.max_by(fn {_p, {ab2, _v2}} -> ab2 end, fn -> nil end)

            value_to_propose =
              case best do
                nil ->
                  state.my_value

                {_p, {_ab2, v2}} ->
                  v2
              end

            # IO.puts("Leader #{state.name}: sending PROPOSE #{inspect value_to_propose} for ballot #{b}")

            
            # this send to all to active acceptor the propose with the value decided above and the ballot.
            # as above if any cprocess is down we do nothing.
            # self() is the pid of the leader process.
            Enum.each(state.participants, fn name ->
              case :global.whereis_name(name) do
                :undefined -> :ok
                pid -> send(pid, {:propose, value_to_propose, b, self()})
              end
            end)

            # this is the usual action.
            # this update map state in consequne of the action just done. ACCEPTED VALUE AND PROMISE.
            new_state = %{
              state |
              promises: new_promises,
              accepts: %{},
              accepted_value: value_to_propose
            }

            loop(new_state) # recursive as usual with the new state.
          else
            
            # this is the condition if the quorum is not found.
            # we update the state with new promises even if quorum is not found. becase we may need them later. and we arewith same ballot.
            # IF I RESET NAD START FROM PREPARE THE TEST ARE GOING TO FAILS.
            new_state = %{state | promises: new_promises}
            loop(new_state)
          end
        end

       #PHASE 2:
       # v is value to propose
       # b is ballot
       # leader_pid is pid of the leader.
       # this is the first part of stage two of paxos.
       # this is the propose meassage sent from the leader to all the acceptor.
       # the acceptor first check if the promise are are not lower then the ballot recieved. if so that means thet propose received is from old leader and therefore reject it. this is prevent Safeness violation.
       # if is not the case th acceptor accept the promise and send back to the leader the acknowledge of accepting the propose.
      {:propose, v, b, leader_pid} ->
        #variable for promised ballot
        promised = state.promised_ballot

        # this is a very important coNdition.
        # this guarantee the safeness of this stage.
        # none propose is accepted if actual ballot is less value than the promised ballot. this could be suggest that the propose is from old leader.
        # otherwise the propose is accepted and the state is updated accordingly.
        if promised != nil and b < promised do
          # IO.puts("Acceptor #{state.name}: REJECTING PROPOSE ballot #{b}, promised #{promised}")
          loop(state)
        else
          # IO.puts("Acceptor #{state.name}: ACCEPTING PROPOSE value #{inspect v} for ballot #{b}")

          #the new state is updated accordingly.  
          new_state = %{
            state |
            accepted_ballot: b,
            accepted_value: v
          }

          # Send akknowledge back to leader.
          send(leader_pid, {:accept, state.name, b})
          loop(new_state)
        end

       # this is the message sent to the leader from the acceptor to aknowledge the accepting of the propose.
       # from is name of acceptor
       # b is ballot

       # this step is pretty similar to the promise step descrive above.
       # first leader check if the ballot received is the same it sent. for safeness.
       # if so it is sotre in map state.
       # after that it checks for quorum.
       # if this is the case(found quorum) it change accpeting state in decided and send message to the upper layer and the algorithm ends.
       # if no quorim is found it just recurse with new state.
      {:accept, from, b} ->
        # this is the same exaplination as above for promise.
        current_ballot = state.next_ballot - state.ballot_step

        # Ignore ACCEPT from an old ballot
        if b != current_ballot do
          # IO.puts("Leader #{state.name}: ignoring ACCEPT from #{from} for old ballot #{b}")
          loop(state) # recurse with the same state.
        else
         
          #store the accept in map state.
          new_accepts = Map.put(state.accepts, from, :accepted)
          # IO.puts("Leader #{state.name}: stored ACCEPT from #{from}")

          #calculate for majority  
          majority = div(length(state.participants), 2) + 1

          # check for quorum and the decided state is not true(already decided).
          if map_size(new_accepts) >= majority and state.decided == false do

            # IO.puts("Leader #{state.name}: QUORUM OF ACCEPTS RECEIVED for ballot #{b}, DECIDING VALUE")
            # this guarantee that if none value was accepted before by acceptor the leader will use its own value.
            decided_value =
              if state.accepted_value != nil do
                state.accepted_value
              else
                state.my_value
              end

            # notify upper layer about the decided value.
            send(state.upper, {:decide, decided_value})

            # send decided value to all participants.
            Enum.each(state.participants, fn name ->
              case :global.whereis_name(name) do
                :undefined -> :ok
                pid -> send(pid, {:decide, decided_value})
              end
            end)

            # update state accordingly.
            new_state = %{
              state |
              accepts: new_accepts,
              decided: true
            }

            loop(new_state)
          else

            # no quorum found we just recurse with new state.
            new_state = %{state | accepts: new_accepts}
            loop(new_state)
          end
        end


      # this is the final message sent from leader to the upper layer to notify the decided value. 
      {:decide, value} ->
        # Only act once
        if not state.decided do
          send(state.upper, {:decide, value})
        end

        new_state = %{
          state |
          decided: true,
          accepted_value: value
        }

        loop(new_state)

        #this is used to stop the process.
      :stop ->
        :ok
    end
  end
end
