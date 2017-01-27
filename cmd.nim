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

import tables
import strutils

const CommandHookNames: seq[string] = @["help", "pre", "post"]

type 
  CmdPrompt* = object
    defaultCommands: Table[string, Table[string, CmdCallback]]
    additionalCommands: Table[string, Table[string, CmdCallback]]
    promptString: string
    activePrompt: bool
  CmdCallback* = proc (ctx: var CmdPrompt, input: seq[string]): void {.gcsafe.}

#
##
proc builtinHelpCommand(ctx: var CmdPrompt, input: seq[string]): void =
  if input.len == 0:
    # asking for general help, not help of a specific command, this should list all available commands
    echo("")
  else:
    # looking for help on a specific command
    let queried_command = input[0]
    if tables.hasKey(ctx.defaultCommands, queried_command):
      # the command is part of the default set
      ctx.defaultCommands[queried_command]["help"](ctx, @[])
    elif tables.hasKey(ctx.additionalCommands, queried_command):
      # the command is part of the set added by the user
      ctx.defaultCommands[queried_command]["help"](ctx, @[])
    else:
      # there is no definition for this command
      echo("no help is available for this command")

# Disable the current run-loop behavior of the prompt
##
proc builtinQuitCommand(ctx: var CmdPrompt, input: seq[string]): void =
  ctx.activePrompt = false

#
##
proc builtinQuitCommand_help(ctx: var CmdPrompt, input: seq[string]): void = 
  echo("stops the interactive prompt")

# This is used as a "do nothing" call when there is no callback assigned to a hook
##
proc builtinNoOpCommand(ctx: var CmdPrompt, input: seq[string]): void =
  discard

# ===========
# Private API
# ===========

# (re)Draws the prompt
##
proc drawPrompt(ctx: var CmdPrompt): void =
  write(stdout, "\n")
  write(stdout, ctx.promptString)
  flushFile(stdout)

#
##
proc executeCommandInput(ctx: var CmdPrompt, input: seq[string]): void =
  var command_table: Table[string, CmdCallback]
  var invalid_command: bool = false
  let command = input[0]
  let arguments = input[1..input.high]
  if tables.hasKey(ctx.defaultCommands, command):
    command_table = ctx.defaultCommands[command]
  elif tables.hasKey(ctx.additionalCommands, command):
    command_table = ctx.additionalCommands[command]
  else:
    invalid_command = true

  if not invalid_command:
    command_table["pre"](ctx, arguments)
    command_table["cmd"](ctx, arguments)
    command_table["post"](ctx, arguments)

# ==========
# Public API
# ==========

#
##s
proc initializeCommandPrompt*(): CmdPrompt = 
  let cast_noop_callback = cast[CmdCallback](builtinNoOpCommand)
  
  let help_command: Table[string, CmdCallback] = {
    "cmd": cast[CmdCallback](builtinHelpCommand), 
    "help": cast_noop_callback, 
    "pre": cast_noop_callback, 
    "post": cast_noop_callback
  }.toTable
  
  let quit_command: Table[string, CmdCallback] = {
    "cmd": cast[CmdCallback](builtinQuitCommand), 
    "help": cast[CmdCallback](builtinQuitCommand_help), 
    "pre": cast_noop_callback, 
    "post": cast_noop_callback
  }.toTable

  let default_commands: Table[string, Table[string, CmdCallback]] = {
    "help": help_command, 
    "quit": quit_command
  }.toTable
  
  let additional_commands = tables.initTable[string, Table[string, CmdCallback]]()
  result = CmdPrompt(defaultCommands: default_commands, additionalCommands: additional_commands, promptString: "(Cmd) ", activePrompt: true)

#
##
proc addCommand*(ctx: var CmdPrompt, cmdKey: string, execCallback: CmdCallback, hooks: Table[string, CmdCallback]): bool = 
  var was_able_to_add_command: bool = false
  let builtin_define_exists = tables.hasKey(ctx.defaultCommands, cmdKey)
  let additional_define_exists = tables.hasKey(ctx.additionalCommands, cmdKey)

  if not builtin_define_exists and not additional_define_exists:
    let help_hook = if tables.hasKey(hooks, "help"): hooks["help"] else: builtinNoOpCommand
    let pre_hook  = if tables.hasKey(hooks, "pre" ): hooks["pre" ] else: builtinNoOpCommand
    let post_hook = if tables.hasKey(hooks, "post"): hooks["post"] else: builtinNoOpCommand
    for key in tables.keys(hooks):
      if not (key in CommandHookNames):
        echo("Unknown hook with name '" & key & "' found, ignoring!")
    let new_command_hooks = {
      "cmd": execCallback, 
      "help": help_hook,
      "pre": pre_hook, 
      "post": post_hook
    }.toTable
    
    ctx.additionalCommands[cmdKey] = new_command_hooks
    was_able_to_add_command = true
  else:
    echo("Error, a command with name '" & cmdKey & "' already exists!")
  result = was_able_to_add_command

#
##
proc runPrompt*(ctx: var CmdPrompt): void = 
  while ctx.activePrompt:
    drawPrompt(ctx)
    let raw_input = readLine(stdin)
    let input = strutils.split(raw_input)
    executeCommandInput(ctx, input)
