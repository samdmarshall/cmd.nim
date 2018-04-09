#[
Copyright (c) 2017, Samantha Marshall
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the 
  documentation and/or other materials provided with the distribution.

3. Neither the name of Samantha Marshall nor the names of its contributors may be used to endorse or promote products derived from this 
  software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED 
TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR 
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, 
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]#

import sets
import hashes
import sequtils
import strutils

type
  Command* = object
    ## Object representing a command that can be registered with the command prompt
    name*: string
      ## Name of the command, the first word that will be entered into the prompt, all following words are arguments to this command
    desc*: string
      ## Short description of the command 
    help*: string
      ## Text to display when invoking the `help` command for this command
    preCmd*: CmdCallback
      ## A callback that gets run prior to the command being run (optional)
    exeCmd*: CmdCallback
      ## Function contaning the primary logic for the command 
    postCmd*: CmdCallback
      ## A callback that gets run prior to the command being run (optional)
  CmdPrompt* = object
    ## 
    commands*: HashSet[Command]
    promptString*: string
    activePrompt: bool
  CmdCallback* = proc (ctx: var CmdPrompt, input: seq[string]): void {.gcsafe.}
    ## 

#
##
proc builtinHelpCommand(ctx: var CmdPrompt, input: seq[string]): void =
  if input.len == 0:
    # asking for general help, not help of a specific command, this should list all available commands
    for cmd in ctx.commands:
      write(stdout, cmd.name & " - " & cmd.desc & "\n")
    write(stdout, "help - displays available commands and their descriptions\n")
    write(stdout, "quit/exit - exits the prompt\n")
  else:
    # looking for help on a specific command
    let queried_command = input[0]
    case queried_command
    of "help":
      write(stdout, "displays a list of available commands")
    of "quit":
      write(stdout, "stops the interactive prompt")
    else:
      for command in ctx.commands:
        if command.name == queried_command:
          write(stdout, command.help)

# Disable the current run-loop behavior of the prompt, allowing it to exit and return to the caller of `.run()`
##
proc builtinQuitCommand(ctx: var CmdPrompt, input: seq[string]): void =
  ctx.activePrompt = false

# ===========
# Private API
# ===========

# (re)Draws the prompt
##
proc drawPrompt(ctx: var CmdPrompt): void =
  let prompt_prefix: string = 
    if ctx.promptString == nil: "(Cmd) "
    else: ctx.promptString
  write(stdout, "\n" & prompt_prefix)
  flushFile(stdout)

#
##
proc executeCommandInput(ctx: var CmdPrompt, input: seq[string]): void =
  let command_str: string = 
    if input.len > 0: input[0] 
    else: ""
  let arguments: seq[string] = 
    if input.len >= 1: input[1..input.high] 
    else: @[]
  case command_str:
  of "help":
    builtinHelpCommand(ctx, arguments)
  of "quit", "exit":
    builtinQuitCommand(ctx, arguments)
  else:
    let matched_commands = filter(toSeq(ctx.commands.items), proc (x: Command): bool = x.name == command_str)
    if matched_commands.len > 0:
      let command = matched_commands[0]
      if not (command.preCmd == nil):
        command.preCmd(ctx, arguments)
      if not (command.exeCmd == nil):
        command.exeCmd(ctx, arguments)
      if not (command.postCmd == nil):
        command.postCmd(ctx, arguments)
    else:
      write(stdout, "unknown command")
  write(stdout, "\n")
  flushFile(stdout)

# ==========
# Public API
# ==========
 
proc run*(ctx: var CmdPrompt): void = 
  ## Starts the interactive command prompt
  ctx.activePrompt = true
  while ctx.activePrompt:
    ctx.drawPrompt()
    let raw_input = readLine(stdin)
    let input = strutils.split(raw_input)
    ctx.executeCommandInput(input)

proc hash*(command: Command): hashes.Hash =
  ## Exposing the hash implementation for the `Command` object
  result = hash(command.name)
