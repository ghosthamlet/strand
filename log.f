\ Strand - logging

.( log )

variable logging        variable logfile    
variable debugging
variable writelimit     variable writecount
: openlog  ( a u -- ) a/o open-file ?ior logfile ! ;
variable stdout'        variable logdepth
: limited  ( u -- ) writelimit !  writecount off ;
: errout  2 stdout ! ;
: logout  depth logdepth !  
  stdout @ stdout' !  logfile @ stdout ! ;
: (<log)  ( [a] -- ) r>  logging @ 0=  if  @ >r  |  cell+ >r  
  LOGLIMIT limited  logout ;
: (<dlog)  ( [a] -- ) r>  logging @ debugging @ and 0=  if  @ >r  |  
  cell+ >r  LOGLIMIT limited  logout ;
: <log  ( -- a ) postpone (<log)  here  0 , ; immediate
: <dlog  ( -- a ) postpone (<dlog)  here  0 , ; immediate
: (log>)  logging @ 0= ?exit  writelimit off
  depth logdepth @ <> abort" uneven stack in log"
  stdout' @ stdout ! ;
: log>  ( a -- ) postpone (log>)  here swap ! ; immediate
defer (<err)  ( [ip] -- )
defer <fatal        defer fatal>
defer (err>)        defer reason  ( a u -- )
: <err"  ( | ..." ... err> -- ) ( -- a ) 
  [char] " parse sliteral  postpone reason
  postpone (<err)  here  0 , ; immediate
: err>  ( ) ( a -- ) here swap !  postpone (err>) ; immediate
defer .reason
