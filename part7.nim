import strformat
import strutils

type
  Symbol = string
  SymTab = seq[Symbol]

const KWlist: seq[Symbol] = @[
  "", "IF", "ELSE", "ENDIF", "END",
]
const KWcode: string = "xilee"

var
  Look: char
  LCount: int
  Token: char
  Value: string

proc Lookup(t: SymTab, s: string): int =
  var i = t.len - 1
  while i > 0:
    if s == t[i]:
      return i
    i -= 1
  return 0

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

proc Match(x: char) =
  if Look == x:
    GetChar()
  else:
    Expected(fmt"'{x}'")

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

proc Fin =
  if Look == '\r':
    GetChar()
  if Look == '\n':
    GetChar()

proc GetName: char =
  while Look in ['\r', '\n']:
    Fin()
  if not IsAlpha(Look):
    Expected("Name")
  result = Look.toUpperAscii
  GetChar()
  SkipWhite()

proc GetNum: char =
  if not IsDigit(Look):
    Expected("Integer")
  result = Look
  GetChar()
  SkipWhite()

proc NewLabel: string =
  result = fmt"L{LCount}"
  LCount += 1

proc PostLabel(label: string) =
  echo fmt"{label}:"

proc Emit(s: string) =
  stdout.write(fmt"{'\t'}{s}")

proc EmitLn(s: string) =
  Emit(s)
  echo ""

proc Ident =
  let name = GetName()
  if Look == '(':
    Match('(')
    Match(')')
    EmitLn(fmt"BSR {name}")
  else:
    EmitLn(fmt"MOVE {name}(PC),D0")

proc Expression

proc Factor =
  if Look == '(':
    Match('(')
    Expression()
    Match(')')
  elif IsAlpha(Look):
    Ident()
  else:
    EmitLn(fmt"MOVE {GetNum()},D0")

proc SignedFactor =
  let s = Look == '-'
  if Look in ['+', '-']:
    GetChar()
    SkipWhite()
  Factor()
  if s:
    EmitLn("NEG D0")

proc Multiply =
  Match('*')
  Factor()
  EmitLn("MULS (SP)+,D0")

proc Divide =
  Match('/')
  Factor()
  EmitLn("MOVE (SP)+,D0")
  EmitLn("EXS.L D0")
  EmitLn("DIVS D1,D0")

proc Term1 =
  while Look in ['*', '/']:
    EmitLn("MOVE D0,-(SP)")
    case Look:
    of '*':
      Multiply()
    of '/':
      Divide()
    else:
      discard

proc Term =
  Factor()
  Term1()

proc FirstTerm =
  SignedFactor()
  Term1()

proc Add =
  Match('+')
  Term()
  EmitLn("ADD (SP)+,D0")

proc Subtract =
  Match('-')
  Term()
  EmitLn("SUB (SP)+,D0")
  EmitLn("NEG D0")

proc Expression =
  FirstTerm()
  while Look in ['+', '-']:
    EmitLn("MOVE D0,-(SP)")
    case Look:
    of '+':
      Add()
    of '-':
      Subtract()
    else:
      discard

proc Condition =
  EmitLn("<condition>")

proc Block

proc DoIf =
  Match('i')
  Condition()
  let l1 = NewLabel()
  var l2 = l1
  EmitLn(fmt"BEQ {l1}")
  Block()
  if Look == 'l':
    Match('l')
    l2 = NewLabel()
    EmitLn(fmt"BRA {l2}")
    PostLabel(l1)
    Block()
  PostLabel(l2)
  Match('e')

proc Assignment =
  let name = GetName()
  Match('=')
  Expression()
  EmitLn(fmt"LEA {name}(PC),A0")
  EmitLn("MOVE D0,(A0)")

proc Block =
  while not(Look in ['e', 'l']):
    case Look:
    of 'i':
      DoIf()
    of '\r', '\n':
      while Look in ['\r', '\n']:
        Fin()
    else:
      Assignment()

proc DoProgram =
  Block()
  if Look != 'e':
    Expected("END")
  EmitLn("END")

proc Init =
  LCount = 0
  GetChar()

when isMainModule:
  Init()
  DoProgram()
