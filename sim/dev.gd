class_name Dev
extends RefCounted
## One switch for the whole developer build.
## Flip ENABLED to false before a player release. Debug menus, the debug
## log, spawn tools, god mode, and every debug_* command all read this.
const ENABLED := true
