# 機能
命令パターンを変えたり白の扱いを変えたりする可能性がある.
それに対して手軽に変更できるようにしておきたい.

- pietbase : dpcc + order + 色空間
  - (白黒はそのままでよい)
  - 3x6 であることや, その対応命令は容易に変更しうる
  - (Orderとの一対一対応をする必要はないので,Orderはゆるくて良い)
  - img.getPietColor() を変更すればよいだけだが…?
- topiet : vpiet形式からPiet画像を生成.
  - PietColorとか結構依存している
- steganopiet : ステガノっぽいPiet

- (pietmap : 画像 → PietColor化+グループ化+index付)
- (indexto : [index->[index,order]] に変換)
  - (White を Piet08 はここで別にやる感じ)
  - (pietbase.decideOrder で命令を決定している)
- (pietcore : 順に実行(抽象化されている(by pietbase.Order)))


# vpiet
1. can execute Piet on CUI ! (high speed !! big png file supported !!)
2. can edit Piet on CUI ! (Cool!!)

# Install
```
### install nim
$ curl https://nim-lang.org/choosenim/init.sh -sSf | sh
$ echo 'export PATH=~/.nimble/bin:$PATH' >> ~/.bashrc
### install vpiet
$ git clone git@github.com:Muratam/vpiet.git
$ cd vpiet
$ nimble install
```

# Usage
```
$ vpiet <filename>     # edit
$ vpiet -e <filename>  # execute
```

# Cool!!
![](./images/iikanji.gif)
![](./images/exec.png)


# FAQ
- codel size -> always 1
- unicode -> utf-8
- divide by zero / modulo by zero -> error (undefined behaviour)
- negative depth roll /  greater than stack size roll -> error (undefined behaviour)
- inn inc at `100 a` -> [100,20(SPACE)]
- inn inn at `100 200` -> [100,200]
