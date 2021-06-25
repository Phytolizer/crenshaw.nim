import strformat
import strutils

var
  Look: char
  LCount: int

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

proc NewLabel: string =
  result = fmt"L{LCount}"
  LCount += 1

proc PostLabel(label: string) =
  echo fmt"{label}:"

proc IsAlpha(c: char): bool =
  c.toUpperAscii in 'A'..'Z'

proc IsDigit(c: char): bool =
  c in '0'..'9'

proc IsBoolean(c: char): bool =
  c in ['T', 'F']

proc IsRelop(c: char): bool =
  c in ['=', '#', '<', '>']

proc Fin =
  if Look == '\r':
    GetChar()
  if Look == '\n':
    GetChar()

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
  LCount = 0
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


proc Block(label: string)

proc If(label: string) =
  Match('i')
  let label1 = NewLabel()
  var label2 = label1
  BoolExpression()
  EmitLn(fmt"BEQ {label1}")
  Block(label)
  if Look == 'l':
    Match('l')
    label2 = NewLabel()
    EmitLn(fmt"BRA {label2}")
    PostLabel(label1)
    Block(label)
  Match('e')
  PostLabel(label2)

proc While =
  Match('w')
  let label1 = NewLabel()
  let label2 = NewLabel()
  PostLabel(label1)
  BoolExpression()
  EmitLn(fmt"BEQ {label2}")
  Block(label2)
  Match('e')
  EmitLn(fmt"BRA {label1}")
  PostLabel(label2)

proc Loop =
  Match('p')
  let label1 = NewLabel()
  let label2 = NewLabel()
  PostLabel(label1)
  Block(label2)
  Match('e')
  EmitLn(fmt"BRA {label1}")
  PostLabel(label2)

proc Repeat =
  Match('r')
  let label1 = NewLabel()
  let label2 = NewLabel()
  PostLabel(label1)
  Block(label2)
  Match('u')
  BoolExpression()
  EmitLn(fmt"BEQ {label1}")
  PostLabel(label2)

proc For =
  Match('f')
  let label1 = NewLabel()
  let label2 = NewLabel()
  let name = GetName()
  Match('=')
  Expression()
  EmitLn("SUBQ #1,D0")
  EmitLn(fmt"LEA {name}(PC),A0")
  EmitLn("MOVE D0,(A0)")
  Expression()
  EmitLn("MOVE D0,-(SP)")
  PostLabel(label1)
  EmitLn(fmt"LEA {name}(PC),A0")
  EmitLn("MOVE (A0),D0")
  EmitLn("ADDQ #1,D0")
  EmitLn("MOVE D0,(A0)")
  EmitLn("CMP (SP),D0")
  EmitLn(fmt"BGT {label2}")
  Block(label2)
  Match('e')
  EmitLn(fmt"BRA {label1}")
  PostLabel(label2)
  EmitLn("ADDQ #2,SP")

proc Do =
  Match('d')
  let label1 = NewLabel()
  let label2 = NewLabel()
  Expression()
  EmitLn("SUBQ #1,D0")
  PostLabel(label1)
  EmitLn("MOVE D0,-(SP)")
  Block(label2)
  EmitLn("MOVE (SP)+,D0")
  EmitLn(fmt"DBRA D0,{label1}")
  EmitLn("SUBQ #2,SP")
  PostLabel(label2)
  EmitLn("ADDQ #2,SP")

proc Break(label: string) =
  Match('b')
  if label != "":
    EmitLn(fmt"BRA {label}")
  else:
    Abort("No loop to break from")

proc Assignment =
  let name = GetName()
  Match('=')
  BoolExpression()
  EmitLn(fmt"LEA {name}(PC),A0")
  EmitLn("MOVE D0,(A0)")

proc Block(label: string) =
  while not (Look in ['e', 'l', 'u']):
    Fin()
    case Look:
    of 'b':
      Break(label)
    of 'd':
      Do()
    of 'f':
      For()
    of 'i':
      If(label)
    of 'p':
      Loop()
    of 'r':
      Repeat()
    of 'w':
      While()
    else:
      Assignment()
    Fin()

proc Program =
  Block("")
  if Look != 'e':
    Expected("End")
  EmitLn("END")

when isMainModule:
  Init()
  Program()
