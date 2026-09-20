Parked, not wired up. The glass / backlit-pane material from "layout study 14".

It was reverted because the look did not land: softening the pigment as well as
the lighting made the whole shell read as pastel plastic rather than lit glass,
and the highlight blew the pale alloys (lilac, pink) out to white.

Kept only because this folder has no git, so a revert is otherwise permanent.
These files are inert - nothing imports them, Quickshell never loads them.

To try it again: copy LcarsRect.qml / LcarsElbow.qml back into ui/, the material
half of LcarsUi.qml back into theme/, and re-add the LCARS_GLASS binding and the
`glass: false` opt-out on the app field in shell.qml. glass-test.qml is the
material bench that was used to tune it.
