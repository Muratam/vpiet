# ruby っぽいがrubyではないなにか
# if :: 0 のみ通さない
# A
main:
  inn
  inn
  inn
  add
  add
  outn
  incpop # inc;pop
  loop:
    inc
    dup
    if is '\n': # push '\n' ; sub ; not
      terminate
    outc
# B
main:
  inn
  inn
  mul
  if mod 2: # push 2 ; mod ;
    outs "Even" # push 'n' ; outc ; ... ; push 'E' ; outc ;
    terminate
  outs "Odd"

# C
main:
  inc
  sub '0' # push '0' ; sub
  inc
  sub '0' # push '0' ; sub
  inc
  sub '0' # push '0' ; sub
  add
  add
  outn

# D
main:
  inn
  inc;pop
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
    swap #roll 1 2
    sub 1
    dup
    if is 0: # push 0 ; sub
      break
  loop:
    min #
    if onlyone : #
      outn
      terminate
