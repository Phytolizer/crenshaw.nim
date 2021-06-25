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

proc IsBoolean(c: char): bool =
  c in ['T', 'F']

proc IsRelop(c: char): bool =
  c in ['=', '#', '<', '>']

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

proc GetBoolean: bool =
  if not IsBoolean(Look):
    Expected("Boolean Literal")
  result = Look.toUpperAscii == 'T'
  GetChar()

proc Emit(s: string) =
  stdout.write(fmt"{'\t'}{s}")

proc EmitLn(s: string) =
  Emit(s)
  echo ""

proc Init =
  GetChar()

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

proc Equals =
  Match('=')
  Expression()
  EmitLn("CMP (SP)+,D0")
  EmitLn("SEQ D0")

proc NotEquals =
  Match('#')
  Expression()
  EmitLn("CMP (SP)+,D0")
  EmitLn("SNE D0")

proc Less =
  Match('<')
  Expression()
  EmitLn("CMP (SP)+,D0")
  EmitLn("SGE D0")

proc Greater =
  Match('>')
  Expression()
  EmitLn("CMP (SP)+,D0")
  EmitLn("SLE D0")

proc Relation =
  Expression()
  if IsRelop(Look):
    EmitLn("MOVE D0,-(SP)")
    case Look:
    of '=':
      Equals()
    of '#':
      NotEquals()
    of '<':
      Less()
    of '>':
      Greater()
    else:
      discard
  EmitLn("TST D0")

proc BoolFactor =
  if IsBoolean(Look):
    if GetBoolean():
      EmitLn("MOVE #-1,D0")
    else:
      EmitLn("CLR D0")
  else:
    Relation()

proc NotFactor =
  if Look == '!':
    Match('!')
    BoolFactor()
    EmitLn("EOR #-1,D0")
  else:
    BoolFactor()

proc BoolTerm =
  NotFactor()
  while Look == '&':
    EmitLn("MOVE D0,-(SP)")
    Match('&')
    NotFactor()
    EmitLn("AND (SP)+,D0")

proc BoolOr =
  Match('|')
  BoolTerm()
  EmitLn("OR (SP)+,D0")

proc BoolXor =
  Match('~')
  BoolTerm()
  EmitLn("EOR (SP)+,D0")

proc BoolExpression =
  BoolTerm()
  while Look in ['|', '~']:
    EmitLn("MOVE D0,-(SP)")
    case Look:
    of '|':
      BoolOr()
    of '~':
      BoolXor()
    else:
      discard

when isMainModule:
  Init()
  BoolExpression()
