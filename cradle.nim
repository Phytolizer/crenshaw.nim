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

proc Match(x: char) =
  if Look == x:
    GetChar()
  else:
    Expected(fmt"'{x}'")

proc IsAlpha(c: char): bool =
  c.toUpperAscii in 'A'..'Z'

proc IsDigit(c: char): bool =
  c in '0'..'9'

proc GetName: char =
  if not IsAlpha(Look):
    Expected("Name")
  result = Look.toUpperAscii
  GetChar()

proc GetNum: char =
  if not IsDigit(Look):
    Expected("Integer")
  result = Look
  GetChar()

proc Emit(s: string) =
  stdout.write(fmt"{'\t'}{s}")

proc EmitLn(s: string) =
  Emit(s)
  echo ""

proc Init =
  GetChar()

when isMainModule:
  Init()
