import sets
import strutils
import "../src/cmd.nim"

proc echoCommand(ctx: var CmdPrompt, input: seq[string]): void =
  echo(strutils.join(input, " "))

proc fooCommand(ctx: var CmdPrompt, input: seq[string]): void =
  echo "foo!"

let echostr = Command(name: "echo", desc: "repeats back a string", help:"echos a string back", exeCmd: echoCommand)
let foo = Command(name: "foo", desc: "prints 'foo'", help: "using this to test multiple commands", exeCmd: fooCommand)
var my_commands: HashSet[cmd.Command] = [foo, echostr].toSet
var prompt = cmd.CmdPrompt(commands: my_commands, promptString: "> ")
prompt.run()
