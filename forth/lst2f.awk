# parse nasm listing and generate definitions for kernel code

function hex(h) {return sprintf("%d", "0x" h)}

BEGIN {
    base = hex(mbase)
    word = ""
    const = ""
    offset = 0
    system("rm -f addrs.f")
}

$2 ~ /^[[:xdigit:]]+$/ {
    off = base + hex($2)
    if(word != "") print off, "kcode", word
    else if(const != "") print off, ("constant '" const) >> "addrs.f"
    word = ""
    const = ""
}

$2 == ";=" {const = $3; word = ""}
$2 == ";" {word = $3; const = ""}
