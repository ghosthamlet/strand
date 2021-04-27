#!/bin/sh
# plot node statistics
heapstats=
usage () {
    echo 'usage: strand plot [-r MIN:MAX] -heap LOGFILE plot [-r MIN:MAX] AXIS ... LOGFILE

  -r MIN:MAX    restricts the range of clock ticks that should be plotted.

  valid axes are: 

    processes derefs remotes exposed atoms static allocated heap sent 
    received sentmessages receivedmessages active suspended reductions 
    suspensions' >&2
    exit $1
}
collect () {
    dfile=$(mktemp -t plot.XXXXXX)
    cat $1 | while read line; do
        case "$line" in 
            *started)
                rm -f $dfile;;
            "##"*)
                if [ -z "$heapstats" ]; then
                    echo $line | awk '{print substr($0,4)}' - >> $dfile
                fi;;
            "#\$"*)
                if [ -n "$heapstats" ]; then
                    echo $line | awk '{print substr($0,4)}' - >> $dfile
                fi;;
        esac
    done
    echo $dfile
}
rng=
fname=
items=
while [ -n "$1" ]; do
    arg=$1
    shift
    case "$arg" in
        -h|-help|--help) 
            usage 0;;
        -r)
            rng="[$1]"
            shift;;
        -heap)
            heapstats=1;;
        -*)
            usage 1;;
        p|processes)
            items="${items}using 1:4 title \"processes\"\n";;
        d|derefs)
            items="${items}using 1:5 title \"derefs\"\n";;
        s|susp|suspensions)
            items="${items}using 1:6 title \"suspensions\"\n";;
        r|red|reductions)
            items="${items}using 1:7 title \"reductions\"\n";;
        sent)
            items="${items}using 1:8 title \"sent\"\n";;
        ns|nsent|msent|sentmessages|sentmsgs)
            items="${items}using 1:9 title \"sent messages\"\n";;
        rec|received)
            items="${items}using 1:10 title \"received\"\n";;
        nr|nreceived|mreceived|receivedmessages|recdmsgs)
            items="${items}using 1:11 title \"received messages\"\n";;
        rem|remotes)
            items="${items}using 1:12 title \"remotes\"\n";;
        e|exp|exposed)
            items="${items}using 1:13 title \"exposed\"\n";;
        a|atoms)
            items="${items}using 1:14 title \"atoms\"\n";;
        st|static|staticspace)
            items="${items}using 1:15 title \"staticspace\"\n";;
        alloc|allocated)
            items="${items}using 1:16 title \"allocated\"\n";;
        h|heap)
            items="${items}using 1:17 title \"heap\"\n";;
        live|active|ap|lp)
            items="${items}using 1:2 title \"active\"\n";;
        sp|suspended)
            items="${items}using 1:3 title \"suspended\"\n";;
        *)
            if [ -n "$fname" ]; then
                usage 1
            fi
            fname=$arg;;
    esac
done
[ -z "$fname" ] && usage 1
pfile=$(mktemp -t gnuplot.XXXXXX)
if [ -n "$heapstats" ]; then
    [ -n "$items" ] && usage 1
    df=$(collect $fname)
    cat > $pfile <<EOF
set style data histogram
set style histogram rowstacked
set style fill solid border -1
set key left
plot $rng "$df" using 2:xtic(1) title "processes", $rng '' using 3 title "tuples", $rng '' using 4 title "lists", $rng '' using 5 title "variables", $rng '' using 6 title "remotes", $rng '' using 7 title "modules", $rng '' using 8 title "bytes", $rng '' using 9 title "ports"
EOF
else
    [ -z "$items" ] && usage 1
    df=$(collect $fname)
    printf "plot " > $pfile
    sep=
    echo $items | while read item; do
        if [ -n "$item" ]; then
            printf "$sep$rng \"$df\" $item with lines lw 2" >> $pfile
            sep=","
        fi
    done
    echo >> $pfile
fi
cat $pfile | gnuplot -persist
rm -f $pfile $df
