# ReNote (Swift)

ReNote rewritten as a native Mac app (AppKit, no web view). Notes in four spaces (Feel, Body, Mind, Soul),
highlights (⌘B) and drawings (⌘D) in the text, export / import as JSON. It keeps its notes in the same file as
before (`~/Library/Application Support/com.artursavytskyi.renote/renote.sqlite`) and talks to ReDesk the same way.

    ./build.sh            # build/ReNote.app
    ./build.sh --install  # into /Applications/ReSpace
    build/ReNote.app/Contents/MacOS/ReNote --render <dir>   # the pages as pictures, from made-up notes
