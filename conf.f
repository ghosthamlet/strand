\ Strand - configuration

.( conf )

[defined] debug-build  constant dbg-build 
: [if-debug-build]  ( | ... -- ) dbg-build  postpone [if] ; immediate
