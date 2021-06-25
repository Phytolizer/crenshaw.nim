import strformat
import strutils

var
  Look: char

proc GetChar =
  Look = stdin.readChar

proc Error(s: string) =
  echo ""
  echo fmt"Error: {s}."

proc Abort(s: string) =
  Error(s)
  quit(1)

proc Expected(s: string) =
  Abort(fmt"{s} Expected")

proc IsAlpha(c: char): bool =
  c.toUpperAscii in 'A'..'Z'

proc IsDigit(c: char): bool =
  c in '0'..'9'

proc IsAlNum(c: char): bool =
  IsAlpha(c) or IsDigit(c)

proc IsWhite(c: char): bool =
  c in [' ', '\t']

proc SkipWhite =
  while IsWhite(Look):
    GetChar()

proc Match(x: char) =
  if Look == x:
    GetChar()
    SkipWhite()
  else:
    Expected(fmt"'{x}'")

proc GetName: string =
  if not IsAlpha(Look):
    Expected("Name")
  result = ""
  while IsAlNum(Look):
    result.add(Look.toUpperAscii)
    GetChar()
  SkipWhite()

proc GetNum: string =
  if not IsDigit(Look):
    Expected("Integer")
  result = ""
  while IsDigit(Look):
    result.add(Look)
    GetChar()
  SkipWhite()

proc Emit(s: string) =
  stdout.write(fmt"{'\t'}{s}")

proc EmitLn(s: string) =
  Emit(s)
  echo ""

proc Init =
  GetChar()
  SkipWhite()

proc Prolog =
  echo "section .text"
  EmitLn("global main")
  echo "main:"

proc Epilog =
  EmitLn("ret")

proc Ident =
  let name = GetName()
  if Look == '(':
    Match('(')
    Match(')')
    EmitLn(fmt"CALL {name}")
  else:
    EmitLn(fmt"MOV rax,[{name}]")

proc Expression

proc Factor =
  if Look == '(':
    Match('(')
    Expression()
    Match(')')
  elif IsAlpha(Look):
    Ident()
  else:
    EmitLn(fmt"MOV rax,{GetNum()}")

proc Multiply =
  Match('*')
  Factor()
  EmitLn("POP rbx")
  EmitLn("IMUL rax,rbx")

proc Divide =
  Match('/')
  Factor()
  EmitLn("POP rbx")
  EmitLn("IDIV rbx")

proc Term =
  Factor()
  while Look in ['*', '/']:
    EmitLn("PUSH rax")
    case Look:
    of '*':
      Multiply()
    of '/':
      Divide()
    else:
      discard

proc Add =
  Match('+')
  Term()
  EmitLn("POP rbx")
  EmitLn("ADD rax,rbx")

proc Subtract =
  Match('-')
  Term()
  EmitLn("POP rbx")
  EmitLn("SUB rax,rbx")
  EmitLn("NEG rax")

proc Expression =
  if Look in ['+', '-']:
    EmitLn("XOR rax,rax")
  else:
    Term()
  while Look in ['+', '-']:
    EmitLn("PUSH rax")
    case Look:
    of '+':
      Add()
    of '-':
      Subtract()
    else:
      discard

proc Assignment =
  let name = GetName()
  Match('=')
  Expression()
  EmitLn(fmt"LEA rax,[{name}]")

when isMainModule:
  Init()
  Prolog()
  Assignment()
  Epilog()
