import std/[
  strformat,
  strutils,
]

type
  Symbol = string
  SymTab = seq[Symbol]

var
  Look: char
  LCount: int
  Token: char
  Value: string
  ST: seq[Symbol]
  SType: seq[char]

const
  KWlist = @[
    "IF", "ELSE", "ENDIF", "WHILE", "ENDWHILE", "VAR", "BEGIN", "END",
    "PROGRAM",
  ]
  KWcode = "xilewevbep"

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

proc Undefined(name: string) =
  Abort(fmt"Undefined Identifier {name}")

proc InTable(n: Symbol): bool =
  Lookup(ST, n) != 0

proc AddEntry(n: Symbol, t: char) =
  if InTable(n):
    Abort(fmt"Duplicate Identifier {n}")
  ST.add(n)
  SType.add(t)

proc IsAlpha(c: char): bool =
  c.toUpperAscii in 'A'..'Z'

proc IsDigit(c: char): bool =
  c in '0'..'9'

proc IsOrop(c: char): bool =
  c in ['|', '~']

proc IsRelop(c: char): bool =
  c in ['=', '#', '<', '>']

proc IsWhite(c: char): bool =
  c in [' ', '\t']

proc IsAlNum(c: char): bool =
  IsAlpha(c) or IsDigit(c)

proc SkipWhite =
  while IsWhite(Look):
    GetChar()

proc NewLine =
  while Look in ['\r', '\n']:
    GetChar()
    if Look == '\n':
      GetChar()
    SkipWhite()

proc GetName =
  NewLine()
  if not IsAlpha(Look):
    Expected("Name")
  Value = ""
  while IsAlNum(Look):
    Value.add(Look.toUpperAscii)
    GetChar()
  SkipWhite()

proc GetNum: int =
  NewLine()
  if not IsDigit(Look):
    Expected("Integer")
  result = 0
  while IsDigit(Look):
    result = 10 * result + ord(Look) - ord('0')
    GetChar()

proc Scan =
  GetName()
  Token = KWcode[Lookup(KWlist, Value)]

proc Match(x: char) =
  NewLine()
  if Look == x:
    GetChar()
  else:
    Expected(fmt"'{x}'")

proc MatchString(x: string) =
  if Value != x:
    Expected(fmt"'{x}'")

proc Emit(s: string) =
  stdout.write(fmt"{'\t'}{s}")

proc EmitLn(s: string) =
  Emit(s)
  echo ""

proc NewLabel: string =
  result = fmt"L{LCount}"
  LCount += 1

proc PostLabel(label: string) =
  echo fmt"{label}:"

proc Init =
  ST = @[]
  SType = @[]
  GetChar()
  Scan()

proc Header =
  echo "section .data"

proc Prolog =
  echo "section .text"
  EmitLn("global main")
  PostLabel("main")

proc Clear =
  EmitLn("XOR rax,rax")

proc Epilog =
  Clear()
  EmitLn("RET")

proc Negate =
  EmitLn("NEG rax")

proc LoadConst(n: int) =
  EmitLn(fmt"MOV rax,{n}")

proc LoadVar(name: Symbol) =
  if not InTable(name):
    Undefined(fmt"{name}")
  EmitLn(fmt"MOV rax,{name}")

proc Push =
  EmitLn("PUSH rax")

proc NotIt =
  EmitLn("NOT rax")

proc PopAdd =
  EmitLn("POP rbx")
  EmitLn("ADD rax,rbx")

proc PopSub =
  EmitLn("POP rbx")
  EmitLn("SUB rax,rbx")
  Negate()

proc PopMul =
  EmitLn("POP rbx")
  EmitLn("IMUL rax,rbx")

proc PopDiv =
  EmitLn("MOV rsi,rax")
  EmitLn("POP rax")
  EmitLn("CDQ")
  EmitLn("IDIV rsi")

proc PopAnd =
  EmitLn("POP rbx")
  EmitLn("AND rax,rbx")

proc PopOr =
  EmitLn("POP rbx")
  EmitLn("OR rax,rbx")

proc PopXor =
  EmitLn("POP rbx")
  EmitLn("XOR rax,rbx")

proc PopCompare =
  EmitLn("POP rbx")
  EmitLn("CMP rax,rbx")

proc SetEqual =
  EmitLn("SETNE al")
  EmitLn("MOVZX rax,al")
  EmitLn("DEC rax")

proc SetNEqual =
  EmitLn("SETE al")
  EmitLn("MOVZX rax,al")
  EmitLn("DEC rax")

proc SetGreater =
  EmitLn("SETLE al")
  EmitLn("MOVZX rax,al")
  EmitLn("DEC rax")

proc SetLess =
  EmitLn("SETGE al")
  EmitLn("MOVZX rax,al")
  EmitLn("DEC rax")

proc SetLessOrEqual =
  EmitLn("SETG al")
  EmitLn("MOVZX rax,al")
  EmitLn("DEC rax")

proc SetGreaterOrEqual =
  EmitLn("SETL al")
  EmitLn("MOVZX rax,al")
  EmitLn("DEC rax")

proc Branch(label: string) =
  EmitLn(fmt"JMP {label}")

proc BranchFalse(label: string) =
  EmitLn("TEST rax,rax")
  EmitLn(fmt"JE {label}")

proc Store(name: Symbol) =
  if not InTable(name):
    Undefined(fmt"{name}")
  EmitLn(fmt"MOV QWORD [{name}],rax")

proc Alloc(n: Symbol) =
  if InTable(n):
    Abort(fmt"Duplicate Variable Name {n}")
  AddEntry(n, 'v')
  stdout.write(fmt"{n}{'\t'}DQ ")
  if Look == '=':
    Match('=')
    if Look == '-':
      stdout.write(Look)
      Match('-')
    echo GetNum()
  else:
    echo "0"

proc Decl =
  GetName()
  Alloc(Value)
  while Look == ',':
    GetChar()
    Alloc(Value)

proc TopDecls =
  NewLine()
  Scan()
  while Token != 'b':
    case Token:
    of 'v':
      Decl()
    else:
      Abort(fmt"Unrecognized Keyword '{Look}'")
    NewLine()
    Scan()

proc BoolExpression

proc Factor =
  if Look == '(':
    Match('(')
    BoolExpression()
    Match(')')
  elif IsAlpha(Look):
    GetName()
    LoadVar(Value)
  else:
    LoadConst(GetNum())

proc NegFactor =
  Match('-')
  if IsDigit(Look):
    LoadConst(-GetNum())
  else:
    Factor()
    Negate()

proc FirstFactor =
  case Look:
  of '+':
    Match('+')
    Factor()
  of '-':
    NegFactor()
  else:
    Factor()

proc Multiply =
  Match('*')
  Factor()
  PopMul()

proc Divide =
  Match('/')
  Factor()
  PopDiv()

proc Term1 =
  while Look in ['*', '/']:
    Push()
    case Look:
    of '*': Multiply()
    of '/': Divide()
    else: discard

proc Term =
  Factor()
  Term1()

proc FirstTerm =
  FirstFactor()
  Term1()

proc Add =
  Match('+')
  Term()
  PopAdd()

proc Subtract =
  Match('-')
  Term()
  PopSub()

proc Expression =
  NewLine()
  FirstTerm()
  while Look in ['+', '-']:
    Push()
    case Look:
    of '+': Add()
    of '-': Subtract()
    else: discard
    NewLine()

proc LessOrEqual =
  Match('=')
  Expression()
  PopCompare()
  SetLessOrEqual()

proc GreaterOrEqual =
  Match('=')
  Expression()
  PopCompare()
  SetGreaterOrEqual()

proc Equals =
  Match('=')
  Expression()
  PopCompare()
  SetEqual()

proc NotEqual =
  Match('#')
  Expression()
  PopCompare()
  SetNEqual()

proc Less =
  Match('<')
  case Look:
  of '=': LessOrEqual()
  of '>': NotEqual()
  else:
    Expression()
    PopCompare()
    SetLess()

proc Greater =
  Match('>')
  if Look == '=':
    GreaterOrEqual()
  else:
    Expression()
    PopCompare()
    SetGreater()

proc Relation =
  Expression()
  if IsRelop(Look):
    Push()
    case Look:
    of '=': Equals()
    of '#': NotEqual()
    of '<': Less()
    of '>': Greater()
    else: discard

proc NotFactor =
  if Look == '!':
    Match('!')
    Relation()
    NotIt()
  else:
    Relation()

proc BoolTerm =
  NewLine()
  NotFactor()
  while Look == '&':
    Push()
    Match('&')
    NotFactor()
    PopAnd()
    NewLine()

proc BoolOr =
  Match('|')
  BoolTerm()
  PopOr()

proc BoolXor =
  Match('~')
  BoolTerm()
  PopXor()

proc BoolExpression =
  NewLine()
  BoolTerm()
  while IsOrop(Look):
    Push()
    case Look:
    of '|': BoolOr()
    of '~': BoolXor()
    else: discard
    NewLine()

proc Assignment =
  let Name = Value
  Match('=')
  BoolExpression()
  Store(Name)

proc Block

proc DoIf =
  BoolExpression()
  let l1 = NewLabel()
  var l2 = l1
  BranchFalse(l1)
  Block()
  if Token == 'l':
    l2 = NewLabel()
    Branch(l2)
    PostLabel(l1)
    Block()
  PostLabel(l2)
  MatchString("ENDIF")

proc DoWhile =
  let l1 = NewLabel()
  let l2 = NewLabel()
  PostLabel(l1)
  BoolExpression()
  BranchFalse(l2)
  Block()
  MatchString("ENDWHILE")
  Branch(l1)
  PostLabel(l2)

proc Block =
  NewLine()
  Scan()
  while not (Token in ['e', 'l']):
    case Token:
    of 'i': DoIf()
    of 'w': DoWhile()
    else: Assignment()
    NewLine()
    Scan()

proc Main =
  MatchString("BEGIN")
  Prolog()
  Block()
  MatchString("END")
  Epilog()

proc Prog =
  MatchString("PROGRAM")
  Header()
  TopDecls()
  Main()
  Match('.')

when isMainModule:
  Init()
  Prog()
  if not (Look in ['\r', '\n']):
    Abort("Unexpected data after '.'")
