set confirm off

eval "target extended-remote %s", $remote

load
continue
quit

#load
#continue &
#shell sleep 5
#detach
#quit
