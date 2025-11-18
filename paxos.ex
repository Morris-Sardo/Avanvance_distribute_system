#############################################################################
# Paxos implementation – up to Stage 6.5 with UNIQUE BALLOTS
#
# API:
#   Paxos.start(name, participants, upper) :: pid
#   Paxos.propose(pid, value)              :: :ok
#   Paxos.start_ballot(pid)                :: :ok
#
# Each Paxos process acts as:
#   - a LEADER (when start_ballot/1 is called)
#   - an ACCEPTOR (when it receives PREPARE / PROPOSE)
# and it notifies its upper process with:
#   {:decide, value}
#############################################################################

defmodule Paxos do

  # PUBLIC API
  # name: unique atom for this Paxos replica (e.g., :p1)
  # participants: list of *names* (atoms) of all Paxos replicas
  # upper: pid of the upper-layer process to notify when decided
  def start(name, participants, upper) do

    # this used to to give a ballot number unique to each process.
    # i have added this to pass test.
    # it strange because in the real scenarion i multiple process can have same ballot number.  
    ######
    #I DONT UNDERSRADN THE POINNT
    my_index =
      case Enum.find_index(participants, fn p -> p == name end) do
        nil -> 0
        idx -> idx
      end

    #number of particitpant
    # WHAT IS THE MEANING OF BALLOT STEP.
    # WHAT IS BALLOT STEP.
    ballot_step = length(participants)

    # Initial state of this Paxos process
    state = %{
      name: name,
      participants: participants,  # all process names (atoms)
      upper: upper,                # who to notify on decision TO UPPER LAYER.

      # ballot numbering
      my_index: my_index,          # 0, 1, 2, ...
      ballot_step: ballot_step,    # usually = length(participants)
      next_ballot: my_index + 1,   # 1..n initially, then jumps by ballot_step

    
      my_value: nil,               # this is the value of the leader.

      # acceptor-side state
      promised_ballot: nil,        # highest ballot I promised
      accepted_ballot: nil,        # last accepted ballot
      accepted_value: nil,         # last accepted value

      # leader-side collections
      promises: %{},               # from -> {ab, av}
      accepts: %{},                # from -> true

      decided: false               # has this process decided?
    }

    # Start the Paxos process loop
    pid = spawn(Paxos, :loop, [state])
    :global.register_name(name, pid)
    pid
  end

  # pid: Paxos process pid
  # val: value we want to propose
  def propose(pid, val) do
    send(pid, {:propose, val})
  end

  # pid: Paxos process pid
  # Tell this process to start a new ballot as leader.
  def start_ballot(pid) do
    send(pid, :start_ballot)
  end


  # MAIN LOOP – keeps the Paxos process alive
  def loop(state) do
    receive do

      ######################################################################
      # User sets the value this process wants to propose (leader side)
      ######################################################################
      {:propose, val} ->
        loop(%{state | my_value: val})


      ######################################################################
      # Start Phase 1 (with UNIQUE BALLOTS)
      # Leader sends PREPARE(b) to all participants
      ######################################################################
      :start_ballot ->
        # b is the ballot we are starting now
        b = state.next_ballot
        # IO.puts("Leader #{state.name}: sending PREPARE #{b} to #{inspect state.participants}")

        # Send PREPARE to all participants
        Enum.each(state.participants, fn name ->
          case :global.whereis_name(name) do
            :undefined -> :ok
            pid -> send(pid, {:prepare, b, self()})
          end
        end)

        # Next ballot for THIS process jumps by ballot_step
        new_state = %{
          state |
          promises: %{},    # empty map – we will fill this when PROMISES arrive
          accepts: %{},     # empty map – will be used in Phase 2
          decided: false,
          next_ballot: b + state.ballot_step
        }

        loop(new_state)


      ######################################################################
      # ACCEPTOR: handle PREPARE(b, leader_pid)
      ######################################################################
      {:prepare, b, leader_pid} ->
        promised = state.promised_ballot

        # Rule:
        # - If I already promised a higher ballot, reject
        # - Else promise this ballot and reply with PROMISE
        if promised != nil and b < promised do
          # IO.puts("Acceptor #{state.name}: REJECTING PREPARE #{b}, already promised #{promised}")
          loop(state)
        else
          # IO.puts("Acceptor #{state.name}: ACCEPTING PREPARE #{b} (old promised #{inspect promised})")

          new_state = %{state | promised_ballot: b}

          # Reply with PROMISE including my accepted info
          send(leader_pid, {
            :promise,
            state.name,
            b,
            state.accepted_ballot,
            state.accepted_value
          })

          loop(new_state)
        end


      ######################################################################
      # Stage 6.3 – LEADER: handle PROMISE(from, b, ab, av)
      ######################################################################
      {:promise, from, b, ab, av} ->
        # last started ballot for this leader
        current_ballot = state.next_ballot - state.ballot_step

        # Ignore PROMISE from an old ballot
        if b != current_ballot do
          # IO.puts("Leader #{state.name}: IGNORING PROMISE from #{from} for old ballot #{b}")
          loop(state)
        else
          # Store the PROMISE from acceptor
          new_promises = Map.put(state.promises, from, {ab, av})
          # IO.puts("Leader #{state.name}: stored PROMISE from #{from} -> {ab=#{inspect ab}, av=#{inspect av}}")

          majority = div(length(state.participants), 2) + 1

          if map_size(new_promises) >= majority do
            #################################################
            # MAJORITY PROMISES REACHED – choose value
            #################################################

            # Find the highest accepted_ballot among all promises
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

            # Send PROPOSE to all participants (Phase 2)
            Enum.each(state.participants, fn name ->
              case :global.whereis_name(name) do
                :undefined -> :ok
                pid -> send(pid, {:propose, value_to_propose, b, self()})
              end
            end)

            # Reset accepts for Phase 2, keep promises and remember proposal
            new_state = %{
              state |
              promises: new_promises,
              accepts: %{},
              accepted_value: value_to_propose
            }

            loop(new_state)
          else
            # Not enough PROMISES yet – just update state
            new_state = %{state | promises: new_promises}
            loop(new_state)
          end
        end


      ######################################################################
      # ACCEPTOR: handle PROPOSE(v, b, leader_pid)
      ######################################################################
      {:propose, v, b, leader_pid} ->
        promised = state.promised_ballot

        # Rule 1: reject if ballot < promised_ballot
        if promised != nil and b < promised do
          # IO.puts("Acceptor #{state.name}: REJECTING PROPOSE ballot #{b}, promised #{promised}")
          loop(state)
        else
          # IO.puts("Acceptor #{state.name}: ACCEPTING PROPOSE value #{inspect v} for ballot #{b}")

          new_state = %{
            state |
            accepted_ballot: b,
            accepted_value: v
          }

          # Send ACCEPT back to leader
          send(leader_pid, {:accept, state.name, b})
          loop(new_state)
        end


      ######################################################################
      # Stage 6.5 – LEADER: handle ACCEPT(from, b)
      ######################################################################
      {:accept, from, b} ->
        # last started ballot for this leader
        current_ballot = state.next_ballot - state.ballot_step

        # Ignore ACCEPT from an old ballot
        if b != current_ballot do
          # IO.puts("Leader #{state.name}: ignoring ACCEPT from #{from} for old ballot #{b}")
          loop(state)
        else
          # Store the ACCEPT 
          new_accepts = Map.put(state.accepts, from, :accepted)
          # IO.puts("Leader #{state.name}: stored ACCEPT from #{from}")

          majority = div(length(state.participants), 2) + 1

          if map_size(new_accepts) >= majority and state.decided == false do
            # Final decided value:
            decided_value =
              if state.accepted_value != nil do
                state.accepted_value
              else
                state.my_value
              end

            # Notify upper layer – format {:decide, value}
            send(state.upper, {:decide, decided_value})

            # Broadcast DECIDE to all participants
            Enum.each(state.participants, fn name ->
              case :global.whereis_name(name) do
                :undefined -> :ok
                pid -> send(pid, {:decide, decided_value})
              end
            end)

            new_state = %{
              state |
              accepts: new_accepts,
              decided: true
            }

            loop(new_state)
          else
            # Not enough ACCEPTs yet – keep waiting
            new_state = %{state | accepts: new_accepts}
            loop(new_state)
          end
        end


      ######################################################################
      # DECIDE handler – all processes receive it
      ######################################################################
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


      ######################################################################
      # Stop (not really used in tests)
      ######################################################################
      :stop ->
        :ok
    end
  end
end
