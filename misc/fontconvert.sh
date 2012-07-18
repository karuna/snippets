#!/bin/sh
# Convert an OTF font into TTF an EOT formats.
otfFont="$1.otf"
ttfFont="$1.ttf"
eotFont="$1.eot"
fontforge -c '
    Open("'$otfFont'");
    Generate("'$ttfFont'");
    Quit(0);'
ttf2eot $ttfFont > $eotFont
