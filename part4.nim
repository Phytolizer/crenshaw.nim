import strformat
import strutils

var
  Look: char
  Table: array['A'..'Z', int]

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

proc NewLine =
  if Look in ['\r', '\n']:
    GetChar()
    if Look == '\n':
      GetChar()

proc GetName: char =
  if not IsAlpha(Look):
    Expected("Name")
  result = Look.toUpperAscii
  GetChar()

proc GetNum: int =
  if not IsDigit(Look):
    Expected("Integer")
  result = 0
  while IsDigit(Look):
    result = 10 * result + ord(Look) - ord('0')
    GetChar()

proc Emit(s: string) =
  stdout.write(fmt"{'\t'}{s}")

proc EmitLn(s: string) =
  Emit(s)
  echo ""

proc InitTable =
  for i in 'A'..'Z':
    Table[i] = 0

proc Init =
  InitTable()
  GetChar()

proc Expression: int

proc Factor: int =
  if Look == '(':
    Match('(')
    result = Expression()
    Match(')')
  elif IsAlpha(Look):
    result = Table[GetName()]
  else:
    result = GetNum()

proc Term: int =
  result = Factor()
  while Look in ['*', '/']:
    case Look:
    of '*':
      Match('*')
      result *= Factor()
    of '/':
      Match('/')
      result = result div Factor()
    else:
      discard

proc Expression: int =
  if Look in ['+', '-']:
    result = 0
  else:
    result = Term()
  while Look in ['+', '-']:
    case Look:
    of '+':
      Match('+')
      result += Term()
    of '-':
      Match('-')
      result -= Term()
    else:
      discard

proc Assignment =
  let Name = GetName()
  Match('=')
  Table[Name] = Expression()

proc Input =
  Match('?')
  Table[GetName()] = ord(stdin.readChar) - ord('0')

proc Output =
  Match('!')
  echo Table[GetName()]

when isMainModule:
  Init()
  while true:
    case Look:
    of '?':
      Input()
    of '!':
      Output()
    else:
      Assignment()
    NewLine()
    if Look == '.':
      break
