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

proc getChar =
  Look = stdin.readChar

proc error(s: string) =
  echo ""
  echo fmt"Error: {s}."

proc abort(s: string) =
  error(s)
  quit(1)

proc expected(s: string) =
  abort(fmt"{s} Expected")

proc undefined(name: string) =
  abort(fmt"Undefined Identifier {name}")

proc inTable(n: Symbol): bool =
  Lookup(ST, n) != 0

proc addEntry(n: Symbol, t: char) =
  if inTable(n):
    abort(fmt"Duplicate Identifier {n}")
  ST.add(n)
  SType.add(t)

proc isAlpha(c: char): bool =
  c.toUpperAscii in 'A'..'Z'

proc isDigit(c: char): bool =
  c in '0'..'9'

proc isOrOp(c: char): bool =
  c in ['|', '~']

proc isRelOp(c: char): bool =
  c in ['=', '#', '<', '>']

proc isWhite(c: char): bool =
  c in [' ', '\t']

proc isAlNum(c: char): bool =
  isAlpha(c) or isDigit(c)

proc skipWhite =
  while isWhite(Look):
    getChar()

proc newLine =
  while Look in ['\r', '\n']:
    getChar()
    if Look == '\n':
      getChar()
    skipWhite()

proc getName =
  newLine()
  if not isAlpha(Look):
    expected("Name")
  Value = ""
  while isAlNum(Look):
    Value.add(Look.toUpperAscii)
    getChar()
  skipWhite()

proc getNum: int =
  newLine()
  if not isDigit(Look):
    expected("Integer")
  result = 0
  while isDigit(Look):
    result = 10 * result + ord(Look) - ord('0')
    getChar()

proc scan =
  getName()
  Token = KWcode[Lookup(KWlist, Value)]

proc match(x: char) =
  newLine()
  if Look == x:
    getChar()
  else:
    expected(fmt"'{x}'")

proc matchString(x: string) =
  if Value != x:
    expected(fmt"'{x}'")

proc emit(s: string) =
  stdout.write(fmt"{'\t'}{s}")

proc emitLn(s: string) =
  emit(s)
  echo ""

proc newLabel: string =
  result = fmt"L{LCount}"
  LCount += 1

proc postLabel(label: string) =
  echo fmt"{label}:"

proc init =
  ST = @[]
  SType = @[]
  getChar()
  scan()

proc header =
  echo "section .data"

proc prologue =
  echo "section .text"
  emitLn("global main")
  postLabel("main")

proc clear =
  emitLn("XOR rax,rax")

proc epilogue =
  clear()
  emitLn("RET")

proc negate =
  emitLn("NEG rax")

proc loadConst(n: int) =
  emitLn(fmt"MOV rax,{n}")

proc loadVar(name: Symbol) =
  if not inTable(name):
    undefined(fmt"{name}")
  emitLn(fmt"MOV rax,{name}")

proc push =
  emitLn("PUSH rax")

proc notIt =
  emitLn("NOT rax")

proc popAdd =
  emitLn("POP rbx")
  emitLn("ADD rax,rbx")

proc popSub =
  emitLn("POP rbx")
  emitLn("SUB rax,rbx")
  negate()

proc popMul =
  emitLn("POP rbx")
  emitLn("IMUL rax,rbx")

proc popDiv =
  emitLn("MOV rsi,rax")
  emitLn("POP rax")
  emitLn("CDQ")
  emitLn("IDIV rsi")

proc popAnd =
  emitLn("POP rbx")
  emitLn("AND rax,rbx")

proc popOr =
  emitLn("POP rbx")
  emitLn("OR rax,rbx")

proc popXor =
  emitLn("POP rbx")
  emitLn("XOR rax,rbx")

proc popCompare =
  emitLn("POP rbx")
  emitLn("CMP rax,rbx")

template comparisonToBool =
  emitLn("MOVZX rax,al")
  emitLn("DEC rax")

proc setEqual =
  emitLn("SETNE al")
  comparisonToBool()

proc setNotEqual =
  emitLn("SETE al")
  comparisonToBool()

proc setGreater =
  emitLn("SETLE al")
  comparisonToBool()

proc setLess =
  emitLn("SETGE al")
  comparisonToBool()

proc setLessOrEqual =
  emitLn("SETG al")
  comparisonToBool()

proc setGreaterOrEqual =
  emitLn("SETL al")
  comparisonToBool()

proc branch(label: string) =
  emitLn(fmt"JMP {label}")

proc branchFalse(label: string) =
  emitLn("TEST rax,rax")
  emitLn(fmt"JE {label}")

proc store(name: Symbol) =
  if not inTable(name):
    undefined(fmt"{name}")
  emitLn(fmt"MOV QWORD [{name}],rax")

proc alloc(n: Symbol) =
  if inTable(n):
    abort(fmt"Duplicate Variable Name {n}")
  addEntry(n, 'v')
  stdout.write(fmt"{n}{'\t'}DQ ")
  if Look == '=':
    match('=')
    if Look == '-':
      stdout.write(Look)
      match('-')
    echo getNum()
  else:
    echo "0"

proc decl =
  getName()
  alloc(Value)
  while Look == ',':
    getChar()
    alloc(Value)

proc topDecls =
  newLine()
  scan()
  while Token != 'b':
    case Token:
    of 'v':
      decl()
    else:
      abort(fmt"Unrecognized Keyword '{Look}'")
    newLine()
    scan()

proc boolExpression

proc factor =
  if Look == '(':
    match('(')
    boolExpression()
    match(')')
  elif isAlpha(Look):
    getName()
    loadVar(Value)
  else:
    loadConst(getNum())

proc negFactor =
  match('-')
  if isDigit(Look):
    loadConst(-getNum())
  else:
    factor()
    negate()

proc firstFactor =
  case Look:
  of '+':
    match('+')
    factor()
  of '-':
    negFactor()
  else:
    factor()

proc multiply =
  match('*')
  factor()
  popMul()

proc divide =
  match('/')
  factor()
  popDiv()

proc term1 =
  while Look in ['*', '/']:
    push()
    case Look:
    of '*': multiply()
    of '/': divide()
    else: discard

proc term =
  factor()
  term1()

proc firstTerm =
  firstFactor()
  term1()

proc add =
  match('+')
  term()
  popAdd()

proc subtract =
  match('-')
  term()
  popSub()

proc expression =
  newLine()
  firstTerm()
  while Look in ['+', '-']:
    push()
    case Look:
    of '+': add()
    of '-': subtract()
    else: discard
    newLine()

proc lessOrEqual =
  match('=')
  expression()
  popCompare()
  setLessOrEqual()

proc greaterOrEqual =
  match('=')
  expression()
  popCompare()
  setGreaterOrEqual()

proc equals =
  match('=')
  expression()
  popCompare()
  setEqual()

proc notEquals =
  match('#')
  expression()
  popCompare()
  setNotEqual()

proc less =
  match('<')
  case Look:
  of '=': lessOrEqual()
  of '>': notEquals()
  else:
    expression()
    popCompare()
    setLess()

proc greater =
  match('>')
  if Look == '=':
    greaterOrEqual()
  else:
    expression()
    popCompare()
    setGreater()

proc relation =
  expression()
  if isRelOp(Look):
    push()
    case Look:
    of '=': equals()
    of '#': notEquals()
    of '<': less()
    of '>': greater()
    else: discard

proc notFactor =
  if Look == '!':
    match('!')
    relation()
    notIt()
  else:
    relation()

proc boolTerm =
  newLine()
  notFactor()
  while Look == '&':
    push()
    match('&')
    notFactor()
    popAnd()
    newLine()

proc boolOr =
  match('|')
  boolTerm()
  popOr()

proc boolXor =
  match('~')
  boolTerm()
  popXor()

proc boolExpression =
  newLine()
  boolTerm()
  while isOrOp(Look):
    push()
    case Look:
    of '|': boolOr()
    of '~': boolXor()
    else: discard
    newLine()

proc assignment =
  let Name = Value
  match('=')
  boolExpression()
  store(Name)

proc doBlock

proc doIf =
  boolExpression()
  let l1 = newLabel()
  var l2 = l1
  branchFalse(l1)
  doBlock()
  if Token == 'l':
    l2 = newLabel()
    branch(l2)
    postLabel(l1)
    doBlock()
  postLabel(l2)
  matchString("ENDIF")

proc doWhile =
  let l1 = newLabel()
  let l2 = newLabel()
  postLabel(l1)
  boolExpression()
  branchFalse(l2)
  doBlock()
  matchString("ENDWHILE")
  branch(l1)
  postLabel(l2)

proc doBlock =
  newLine()
  scan()
  while not (Token in ['e', 'l']):
    case Token:
    of 'i': doIf()
    of 'w': doWhile()
    else: assignment()
    newLine()
    scan()

proc main =
  matchString("BEGIN")
  prologue()
  doBlock()
  matchString("END")
  epilogue()

proc program =
  matchString("PROGRAM")
  header()
  topDecls()
  main()
  match('.')

when isMainModule:
  init()
  program()
  if not (Look in ['\r', '\n']):
    abort("Unexpected data after '.'")
