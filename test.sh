try(){
  nimr src/graph.nim $1  > ./nimcache/piet.dot && \
  # dot -Tpng ./nimcache/piet.dot -o ./nimcache/pietgraph.png && open ./nimcache/pietgraph.png && \cp $1 ./nimcache/pietbase.png && open ./nimcache/pietbase.png && \
  echo "ANS:" $3
  echo $2 | ./nimcache/piet.out && \
}
## Test
# try "tests/apple.png" "" "piet"
# try "tests/C_HelloWorld.png" "" " "
# try "tests/kokoro.png" "" "ああ〜心がぴょんぴょんするんじゃ〜"
## HARD Test (???)
# try "tests/htmlserver.png" # core:o / emu:x
# try "tests/sachiko.png" # wrong ?
## Base
# try ../images/base/2018-a.png "1\n2 3\ntest" "6 test"
# try ../images/base/2018-b.png "3 4" "Even"
# try ../images/base/2018-c.png "101" "2"
# ### D
# try ../images/base/2018-d.png "3\n8 12 40" "2"
# try ../images/base/2018-d.png "4\n5 6 8 10" "0"
# try ../images/base/2018-d.png "6\n382253568 723152896 37802240 379425024 404894720 471526144" "8"
# ### F
# try ../images/base/2018-f.png "20 2 5" "84"
# try ../images/base/2018-f.png "10 1 2" "13"
# try ../images/base/2018-f.png "100 4 16" "4554"
# ### H INVALID IMAGE
# try ../images/base/2018-h.png "4\n10\n8\n8\n6" "3"
# ### I INVALID IMAGE
# try ../images/base/2018-i.png "9 45000" "4 0 5"
# ### J INVALID IMAGE
# try ../images/base/2018-j.png "erasedream" "YES"
# ### K
# try ../images/base/2018-k.png "2\n3 1 2\n6 1 1" "Yes"
# try ../images/base/2018-k.png "1\n2 100 100" "No"
# try ../images/base/2018-k.png "2\n5 1 1\n100 1 1" "No"
# ### 2015-K partial-wrong(maybe long long)
# try ../images/base/2015-2prob.png "1 9" "2"
# try ../images/base/2015-2prob.png "40 49" "10"
# try ../images/base/2015-2prob.png "1 1000" "488"
# try ../images/base/2015-2prob.png "1 1000000000000000000" "981985601490518016"
