# 機能
- pietcore : Pietを実行可能
- topiet : vpiet形式からPiet画像を生成.
- steganopiet : ステガノっぽいPietを生成



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
