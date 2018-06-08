# ruby っぽいがrubyではないなにか(いい感じにシンタックスハイライトされてしまうのでつい…)
#　一番簡単には 1->2->3 ...->n 命令を埋め込む
# 最初は if / loop なしで(愚直に命令列を埋め込む)
# 続いて if loop ありで 最後に関数あり
# 変数の使用 / for などは解析を工夫すれば可能なはず
# if :: 0 のみ通さない((直前にnotされていなければ) not not する)
### 特別
# op2 n => push n ; op2
# outs "Even" # push 'n' ; outc ; ... ; push 'E' ; outc ;
### 構文
# if op n: | loop: | break | next |
### 疑似マクロ定義
swap = roll 1 2
incpop = inc;pop
is x = push x ; sub ; not
# A
main:
  inn
  inn
  inn
  add
  add
  outn
  incpop
  loop:
    inc
    dup
    if is '\n':
      terminate
    outc
# B
main:
  inn
  inn
  mul
  if mod 2:
    outs "Even"
    terminate
  outs "Odd"

# C
main:
  inc
  sub '0'
  inc
  sub '0'
  inc
  sub '0'
  add
  add
  outn

# D
main:
  inn
  incpop
  for: # 解析してスタックの増減サイズを固定にさせる ?
    # 8 -> 3
    inn
    push 0
    swap
    loop: # [8,0] -> [0,8]->[1,4]->[2,2]->[3,1]->[3]
      div 2
      dup
      if mod 2:  # [0,4,0]
        pop
        break
      swap
      add 1
      swap
    swap
    sub 1
    dup
    if is 0:
      break
  loop:
    min # ? [b,a] -gt>
    if onlyone : # ?
      outn
      terminate
# E
main:
  inn
  inn
  inn
  inn
  roll 1 4 # X A B C
  # 頑張って A B C X A B C にする or もう一つのスタックを実装する ?
  for:
    for:
      for:


