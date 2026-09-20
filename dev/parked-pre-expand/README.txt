Rollback point: the panel exactly as it was before the collapse/expand experiment.

Everything in here is inert - nothing imports it.

To roll back:
    cp dev/parked-pre-expand/shell.qml   shell.qml
    cp dev/parked-pre-expand/ui/*.qml    ui/
    cp dev/parked-pre-expand/theme/*.qml theme/

(This folder has no git, so this is the only copy.)
