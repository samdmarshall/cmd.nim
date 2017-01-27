import tables
import strutils

import "../cmd.nim"

proc echoCommand(ctx: var cmd.CmdPrompt, input: seq[string]): void =
  echo(strutils.join(input))

var prompt = cmd.initializeCommandPrompt()
var hooks = tables.initTable[string, cmd.CmdCallback]()
var result = cmd.addCommand(prompt, "echo", echoCommand, hooks)
cmd.runPrompt(prompt)
