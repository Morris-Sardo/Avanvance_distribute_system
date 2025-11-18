killall -9 beam.smp 2>/dev/null
/bin/rm -f *.beam
export ERL_AFLAGS="+S 4 +SDio 2"
elixir --sname coord test_script.exs
