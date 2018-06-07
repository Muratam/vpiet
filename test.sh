try(){
  nimr src/graph.nim $1  > ./nimcache/piet.dot && \
  dot -Tpng ./nimcache/piet.dot -o ./nimcache/pietgraph.png && \
  open ./nimcache/pietgraph.png && \
  \cp $1 ./nimcache/pietbase.png && open ./nimcache/pietbase.png && \
  echo $2 | ./nimcache/piet.out
}
# try "tests/apple.png"
# try "tests/C_HelloWorld.png"
# try "tests/kokoro.png" " "
# try "tests/htmlserver.png" # core:o / emu:x
# try "tests/sachiko.png" # wrong ?
# try ../images/base/2018-a.png "1\n2 3\niikanji"
# try ../images/base/2018-b.png "5 9"
# try ../images/base/2018-c.png "001"
