import sets
import strutils
import "../cmd.nim"

proc echoCommand(ctx: var cmd.CmdPrompt, input: seq[string]): void =
  echo(strutils.join(input, " "))

let foo = cmd.Command(name: "echo", help:"echos a string back", exeCmd: echoCommand)
var my_commands: HashSet[cmd.Command] = [foo].toSet
var prompt = cmd.CmdPrompt(commands: my_commands, promptString: "> ")
prompt.run()
