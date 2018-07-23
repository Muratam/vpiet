import common
import pietmap, indexto

type
  OrderWithInfo* = tuple[order:Order,size:int,dp:DP,cc:CC]
  PietProc* = tuple[
    orders:seq[OrderWithInfo],
    nexts:seq[int], # stack-top が 0..
    startCC:CC,
    startDP:DP,
  ]
  # 実行命令列と次に起こりうる遷移Index,
  PietConstantFolder* = ref object
    dp*:DP
    cc*:CC
    stack*:Stack[int]
    nextDPCCIndex*:int # 0 1 2 3 のみに抽象化


proc newPietConstantFolder*(dp:DP,cc:CC):PietConstantFolder =
  new(result)
  result.dp = dp
  result.cc = cc
  result.stack = newStack[int]()
  result.nextDPCCIndex = -1
proc execSteps*(emu:var PietConstantFolder,orders:seq[OrderWithInfo]): bool =
  proc step(self:PietConstantFolder,info:OrderWithInfo) : bool =
    result = true
    self.cc = info.cc
    self.dp = info.dp
    template binaryIt(op) =
      if self.stack.len() < 2 :
        return false
      let a {.inject.}= self.stack.pop()
      let b {.inject.}= self.stack.pop()
      op
    template unaryIt(op) =
      if self.stack.len() < 1 :
        return false
      let it {.inject.} = self.stack.pop()
      op
    self.nextDPCCIndex = 0
    case info.order
    of Add: binaryIt(self.stack.push(b + a))
    of Sub: binaryIt(self.stack.push(b - a))
    of Mul: binaryIt(self.stack.push(b * a))
    of Div: binaryIt(self.stack.push(b div a)) # 0 除算は無視すべき
    of Mod: binaryIt(self.stack.push(b mod a))
    of Greater: binaryIt(self.stack.push(if b > a : 1 else: 0))
    of Push: self.stack.push(info.size)
    of Pop: unaryIt((discard))
    of Not: unaryIt(self.stack.push(if it > 0 : 0 else: 1))
    of Pointer: unaryIt((self.nextDPCCIndex = (((it mod 4) + 4) mod 4)))
    of Switch:  unaryIt((self.nextDPCCIndex = (((it mod 2) + 2) mod 2)))
    of InC: return false
    of InN: return false
    of OutN: unaryIt((discard))
    of OutC: unaryIt((discard))
    of Dup: unaryIt((self.stack.push(it);self.stack.push(it)))
    of Roll: return false
    of Wall:discard
    else:discard
  for order in orders:
    if not emu.step(order): return false
  return true
proc realNexts(self:PietProc):seq[int] =
  result = @[]
  for n in self.nexts:
    if n < 0 : continue
    result.add(n)

proc deleteNeedLessNode(self:var seq[PietProc]) : bool =
  proc deleteImpl(self:seq[PietProc]): seq[PietProc] =
    var isUsed = newSeq[bool](self.len())
    isUsed[0] = true # 0番は絶対使う
    for pp in self:
      for next in pp.realNexts:
        isUsed[next] = true
    var deletedSum = 0
    var deletedSums = newSeq[int](self.len())
    for i in 0..< self.len():
      if not isUsed[i]: deletedSum += 1
      deletedSums[i] = deletedSum
    result = @[]
    for i in 0..< self.len():
      if not isUsed[i] :continue
      result.add(self[i])
      if result[^1].nexts.len() == 0: continue
      for n in 0..<result[^1].nexts.len():
        let next = result[^1].nexts[n]
        if next < 0 : continue
        result[^1].nexts[n] = next - deletedSums[next]
  result = false
  while true:
    let newOne = self.deleteImpl()
    if newOne.len == self.len: return
    self = newOne
    result = true

proc makeGraph(indexTo:IndexTo) :seq[PietProc]=
  type NotDevidedGraph = tuple[pp:PietProc,devideOrderNum:int,endCC:CC,endDP:DP]
  proc `isDevider`(self:NotDevidedGraph) :bool = self.devideOrderNum >= 0
  # 一旦行けるところまでいくグラフを作成
  proc makeNotDevidedGraph(indexTo:IndexTo): seq[NotDevidedGraph] =
    type SearchTrace = tuple[graphIndex,orderNum:int]
    var searched = newSeq[EightDirection[SearchTrace]](indexTo.blockSize.len())
    var graphIndex = 0
    proc search(self:var seq[NotDevidedGraph],startCC:CC,startDP:DP,startIndex:int) : int =
      graphIndex += 1
      result = graphIndex # 予め返り値を保存
      var (cc,dp,index,orders) = (startCC,startDP,startIndex,newSeq[OrderWithInfo]())
      template terminate(nexts :seq[int]= @[]) = self.add(((orders,nexts,startCC,startDP),-1,cc,dp))
      while true:
        if searched[index][cc,dp].graphIndex > 0:
          let pre = searched[index][cc,dp]
          if pre.orderNum == 0: # 先頭なので直接繋げば分割しなくてよい
            # selfを参照する際は1-indexedではない！
            assert cc == self[pre.graphIndex - 1].pp.startcc
            assert dp == self[pre.graphIndex - 1].pp.startdp
            if orders.len() == 0: # 私は空なのでそもそもこの辺はいらなかった
              graphIndex -= 1
              return pre.graphIndex
            terminate(@[pre.graphIndex])
            return
          terminate(@[pre.graphIndex])
          self[^1].devideOrderNum = pre.orderNum
          return
        searched[index][cc,dp] = (graphIndex, orders.len())
        let next = indexTo.nextEdges[index][cc,dp]
        template pushOrder(order:Order=next.order) = orders.add((order,indexTo.blockSize[index],dp,cc))
        case next.order :
        of Switch: # 2方向の可能性に分岐 & 今までの部分をまでをまとめて辺にする
          pushOrder()
          terminate()
          let current = self.len() - 1
          for _ in 0..<2:
            self[current].pp.nexts &= self.search(cc,dp,next.index)
            cc.toggle()
          return
        of Pointer: # 4方向の可能性に分岐
          pushOrder()
          terminate()
          let current = self.len() - 1
          for _ in 0..<4:
            self[current].pp.nexts &= self.search(cc,dp,next.index)
            dp.toggle(1)
          return
        of Wall:
          proc isTerminateWall() : bool =
            result = true
            for i in 0..<8:
              if i mod 2 == 0: cc.toggle()
              else : dp.toggle(1)
              let next = indexTo.nextEdges[index][cc,dp]
              if next.order != Wall: return false
          if isTerminateWall():
            pushOrder(Terminate)
            terminate()
            return
          pushOrder()
        of Terminate:
          pushOrder()
          terminate()
          return
        of Nop:
          index = next.index
        else:
          pushOrder()
          index = next.index
    # 0-indexに合わせる
    proc to0Indexed(self:var seq[NotDevidedGraph]) =
      for i in 0..<self.len():
        for n in 0..<self[i].pp.nexts.len():
          self[i].pp.nexts[n] -= 1
    # impl
    result = newSeq[NotDevidedGraph]()
    discard result.search(newCC(),newDP(),0)
    result.to0Indexed()

  # グラフを分割 & 圧縮
  proc devideGraph(self:var seq[NotDevidedGraph]) : seq[PietProc] =
    # どこで分割したいかを知るために作成
    var to = newSeqWith(self.len(),newSeq[tuple[index:int,orderNum:int]]())
    for i in 0..<self.len():
      if not self[i].isDevider : continue
      let devideGraohIndex = self[i].pp.nexts[0]
      to[devideGraohIndex].add((i,self[i].devideOrderNum))
    # 後ろから見ていくためのソート
    for i in 0..<to.len():
      if to[i].len() == 0 : continue
      to[i].sort((x,y)=> y.orderNum - x.orderNum)
      # echo "{i} <- {to[i]} / {self[i].pp.orders.len()}".fmt()
    # 分割
    var maxIndex = self.len()
    for i in 0..<self.len():
      if to[i].len() == 0 : continue
      let parent = self[i]
      assert(not parent.isDevider)
      var currentDevidePos = -1
      for devider in to[i]:
        var devidePos = devider.orderNum
        var deviderIndex = devider.index
        assert self[deviderIndex].pp.nexts.len == 1
        self[deviderIndex].devideOrderNum = -1
        self[deviderIndex].pp.nexts = @[maxIndex]
        if currentDevidePos == devidePos:
          continue
        currentDevidePos = devidePos
        let midCC = self[deviderIndex].endCC
        let midDP = self[deviderIndex].endDP
        let newer = (parent.pp.orders[devidePos..^1],parent.pp.nexts,midCC,midDP)
        self.add((newer,-1,parent.endCC,parent.endDP))
        self[i].pp.nexts  = @[maxIndex]
        self[i].pp.orders = self[i].pp.orders[0..devidePos-1]
        self[i].endCC = midCC
        self[i].endDP = midDP
        maxIndex += 1
    # 長さ 0 の端点書き換え
    for i in 0..<self.len():
      if self[i].pp.orders.len() > 0 : continue
      if self[i].pp.nexts.len() == 0:
        for j in 0..<self.len():
          self[j].pp.nexts = self[j].pp.nexts.filterIt(it != i)
      else:
        let anotherEdge = self[i].pp.nexts[0]
        for j in 0..<self.len():
          self[j].pp.nexts.applyIt(if it == i : anotherEdge else: it)

    proc deleteWallNode(self:var seq[PietProc]) =
      # nexts: stackTop が {None,0} 1 2 3 ... の順と仮定してよい
      for i in 0..<self.len():
        if self[i].orders.anyIt(it.order != Wall): continue
        if self[i].realNexts.len != 1 : continue
        # i へのノードを先っぽに付け替え
        for j in 0..<self.len():
          for n in 0..<self[j].nexts.len():
            if self[j].nexts[n] != i: continue
            if self[j].nexts[n] <  0: continue
            self[j].nexts[n] = self[i].nexts[0]
      for i in 0..<self.len():
        if self[i].orders.len == 0 : continue
        self[i].orders = self[i].orders.filterIt(it.order != Wall)
    result = self.mapIt(it.pp)
    result.deleteWallNode()
    discard result.deleteNeedLessNode()

  var graph = indexTo.makeNotDevidedGraph()
  return graph.devideGraph()


# 行かないノードを探して削除
proc optimizeNext(self:var seq[PietProc]) =

  proc equals(a,b:OrderWithInfo):bool =
    if a.order != b.order : return false
    if a.order == Push and a.size != b.size : return false
    return true

  proc getIsSameNode(self:var seq[PietProc],pro0Index,pro1Index:int):bool =
    # 命令列が全く同じでリンク先も全く同じで私からしかリンクされていないもの
    let pro0 = self[pro0Index]
    let pro1 = self[pro1Index]
    if pro0.orders.len() != pro1.orders.len() : return false
    if pro0.nexts != pro1.nexts : return false
    return zip(pro0.orders,pro1.orders).allIt(equals(it[0],it[1]))

  proc getIsCyclicSameNode(self:var seq[PietProc],pro0Index,pro1Index:int):bool =
    # 命令列が全く同じでリンク先も全く同じで私からしかリンクされていないもの
    let pro0 = self[pro0Index]
    let pro1 = self[pro1Index]
    if pro0.orders.len() != pro1.orders.len() : return false
    if pro0.nexts != pro1.nexts :
      let pro0Nexts = pro0.realNexts()
      let pro1Nexts = pro1.realNexts()
      if pro0Nexts.len() != pro1Nexts.len() : return false
      if pro0Nexts.len() != 2: return false
      if pro0Nexts[0] == pro1Nexts[0] and
         pro0Nexts[1] == pro1Index and pro1Nexts[1] == pro0Index: discard
      elif pro0Nexts[1] == pro1Nexts[1] and
         pro0Nexts[0] == pro1Index and pro1Nexts[0] == pro0Index: discard
      elif pro0Nexts[0] == pro1Nexts[0] and
         pro0Nexts[1] == pro0Index and pro1Nexts[1] == pro1Index: discard
      elif pro0Nexts[1] == pro1Nexts[1] and
         pro0Nexts[0] == pro0Index and pro1Nexts[0] == pro1Index: discard
      else: return false
    return zip(pro0.orders,pro1.orders).allIt(equals(it[0],it[1]))

  proc execToDetectNeedLessNode(self:var seq[PietProc]) =
    # 向きを変えるだけのDP/CCの分岐を削除
    for i in 0..<self.len():
      let pp = self[i]
      if pp.realNexts.len() <= 1: continue
      var emu = newPietConstantFolder(pp.startDP,pp.startCC)
      if not emu.execSteps(pp.orders): continue
      let newOne = @[self[i].nexts[emu.nextDPCCIndex]]
      self[i].nexts = newOne

  proc execFirstToDetectNeedLessNode(self:var seq[PietProc]) =
    var index = 0
    var emu = newPietConstantFolder(self[index].startDP,self[index].startCC)
    var used = newSeq[bool](self.len())
    var usedEdge = newSeq[tuple[a,b:int]]()
    var onlyUsed = true
    while true:
      used[index] = true
      if not emu.execSteps(self[index].orders):
        onlyUsed = false
        break
      if self[index].realNexts.len() == 0 : break # Terminal
      let nextIndex =
        if self[index].realNexts.len() == 1: self[index].realNexts[0]
        else: self[index].nexts[emu.nextDPCCIndex]
      usedEdge.add((index,nextIndex))
      index = nextIndex
      if used[index] : break
    if not onlyUsed:
      proc search(self:var seq[PietProc],i:int) =
        used[i] = true
        for n in self[i].realNexts:
          if used[n] : continue
          self.search(n)
      self.search(index)
    for i in 0..<self.len():
      if used[i]: continue
      for j in 0..<self.len():
        self[j].nexts = self[j].nexts.mapIt(if it == i: -1 else: it)
    if onlyUsed:
      for i in 0..<self.len():
        self[i].nexts = @[]
      for edge in usedEdge:
        let (a,b) = edge
        self[a].nexts &= b

  proc optimize(self:var seq[PietProc]) =
    # {Not,Greater} pointer などは最適化できる
    for i in 0..<self.len():
      if self[i].orders.len() < 2: continue
      if self[i].orders[^1].order != Pointer: continue
      if not (self[i].orders[^2].order in [Not,Greater]):continue
      if self[i].nexts.len() != 4: continue
      self[i].nexts = @[self[i].nexts[0],self[i].nexts[1]]
    discard self.deleteNeedLessNode()
    # {Push,DP} も最適化できる
    for i in 0..<self.len():
      if self[i].orders.len() < 2: continue
      if not (self[i].orders[^2].order == Push):continue
      if self[i].orders[^1].order != Pointer: continue
      if self[i].nexts.len() != 4: continue
      let n = ((self[i].orders[^2].size + 4) mod 4)
      self[i].nexts = @[self[i].nexts[n]]
    # {Push,CC} も最適化できる
    for i in 0..<self.len():
      if self[i].orders.len() < 2: continue
      if not (self[i].orders[^2].order == Push):continue
      if self[i].orders[^1].order != Switch: continue
      if self[i].nexts.len() != 2: continue
      let n = ((self[i].orders[^2].size + 2) mod 2)
      self[i].nexts = @[self[i].nexts[n]]
    discard self.deleteNeedLessNode()
    # 行き先が全て同じなら一つでよい
    for i in 0..<self.len():
      let nexts = self[i].realNexts()
      if nexts.len() < 1 : continue
      let dep = nexts.deduplicate()
      if dep.len() != 1: continue
      self[i].nexts = dep

  proc merge(self:var seq[PietProc]) =
    # {*} -> b -> c を {*} -> [b+c] にマージ (b,c は一つからのみ)
    # a -> {b1,b2} -> c を a -> c にマージ (全く同じ時のみ)したい
    var tos = newSeq[int](self.len())
    for pp in self:
      for n in pp.realNexts:
        tos[n] += 1
    for i in 0..<self.len():
      let pre = i
      # a6(13)[+3 .. ON] <-> a32(5)[+32..Gt]
      # if tos[pre] > 1: continue # WARN: 実はいらない説
      if self[pre].realNexts().len() == 1 :
        let pro = self[pre].realNexts()[0]
        if pre == pro : continue # やばそう
        self[pre].nexts = self[pro].nexts
        self[pre].orders &= self[pro].orders
      elif self[i].realNexts().len() >= 2:
        # if tos[pre] > 1: continue # WARN: 実はいらない説
        # >= 2 に対しても起こりうる
        if self[i].realNexts().len() == 2:
          let i1 = self[pre].realNexts()[0]
          let i2 = self[pre].realNexts()[1]
          if not self.getIsSameNode(i1,i2): continue
          self[pre].nexts = @[i1]
        elif self[i].realNexts().len() == 4:
          proc searchSame(self:var seq[PietProc]) =
            for i12 in [(0,1),(0,2),(0,3),(1,2),(1,3),(2,3)]:
              let (a,b) = i12
              let i1 = self[pre].realNexts()[a]
              let i2 = self[pre].realNexts()[b]
              if not self.getIsSameNode(i1,i2): continue
              self[pre].nexts[a] = self[pre].nexts[b]
              # return
          self.searchSame()
  proc deleteSameNode(self:var seq[PietProc]) =
    # 全く同じノード(命令が同じで出力先も同じ)も消したい
    # 自己ループも消えてくれそう -> (htmlserver)相互参照型になる
    for i in 0..<self.len():
      for j in (i+1)..<self.len():
        if not self.getIsCyclicSameNode(i,j): continue
        # 自分へのリンクを全てもう片方へと変えればよい
        for k in 0..<self.len():
          for n in 0..<self[k].nexts.len():
            let next = self[k].nexts[n]
            if next < 0 : continue
            if next == i : self[k].nexts[n] = j

  var updated = false
  template normalize() = updated = self.deleteNeedLessNode() or updated
  normalize()
  while true:
    updated = false
    self.optimize()
    normalize()
    self.execToDetectNeedLessNode()
    normalize()
    self.execFirstToDetectNeedLessNode()
    normalize()
    self.merge()
    normalize()
    self.deleteSameNode()
    normalize()
    if not updated: break
# グラフを作成
proc newGraph*(filename:string,optimize:bool=true) : seq[PietProc] =
  let indexTo = filename.newPietMap().newIndexTo()
  result = indexTo.makeGraph()
  if optimize: result.optimizeNext()
