#!/usr/bin/env bash
#
# px completion script

which px > /dev/null 2>&1 || return

_complete(){
    local curr="${COMP_WORDS[$COMP_CWORD]}"
    if [ "$COMP_CWORD" -lt 2 ]; then
        COMPREPLY+=($(compgen -W "$(px commands)" -- "$curr"))
    else
        COMPREPLY=($(compgen -f "$curr"))
    fi
}

complete -o bashdefault -o filenames -F _complete px
