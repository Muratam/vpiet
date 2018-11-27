# FAQ
- codel size :: 1
- utf-8 support
- undefined behaviour (error)
  - divide by zero
  - modulo by zero
  - negative depth roll
  - greater than stack size roll
- IN(Number) / IN(Char) example:
  - inn inc at `100 a` -> [100,20(=SPACE)]
  - inn inn at `100 200` -> [100,200]

# PASM (Piet Assembly)
```
文法:
基本命令:
  push n
  pop add sub mul div mod not greater dup roll outn outc inn inc terminate
  <label>:
  go <label>
  go <label> <label> 条件に応じてジャンプ(jne / not not するのでトップは消える)
応用命令:
コメント: #
```