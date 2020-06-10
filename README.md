## HGCスパコン上でのGSEA解析
### インストール

```
git clone https://atusiniida@github.com/atusiniida/GSEAparallel.git
```

または

```
wget https://github.com/atusiniida/GSEAparallel/archive/master.zip
unzip  master.zip
rm master.zip
mv GSEAparallel-master GSEAparallel
```

https://www.gsea-msigdb.org/gsea/downloads.jsp \
よりGSEA v4.0.3 for thecommand line (all platforms)を取得、解凍\
GSEAparallelディレクトリにGSEA_4.0.3ディレクトリをおく

### GSEAを実行
発現データA.tab、遺伝子セットデータB.gmt、サンプルラベルデータC.tabに適用
```
perl GSEAparallel/perl/gsea.pl  A.tab B.gmt C.tab
```
A.tabは以下のような行列形式のフォーマット
>[tab]sample1[tab]sample2[tab]sample3[tab]sample4[tab]sample5\
gene1[tab]1.0[tab]1.0[tab]2.0[tab]3.0[tab]-1.0\
gene2[tab]5.0[tab]1.0[tab]6.0[tab]-3.0[tab]-2.0\
gene3[tab]5.0[tab]-2.0[tab]-1.0[tab]4.0[tab]3.0

B.gmtのフォーマットは以下を参照
http://software.broadinstitute.org/cancer/software/genepattern/file-formats-guide#GMT

C.tabは以下のような行列形式のフォーマット\
行、列が逆でも良い。\
サンプル名はA.tabとの積集合をとって解析を行うので全部同じにする必要はない。\
二種類の数字、文字列をめば二群比較、二種類以上の数値は連続値との相関解析となる。\
'na', ''を含めば当該サンプルに対する当該サンプルラベルは省いて解析する。\
二群比較の場合どちらかのグループのサンプル数が二以下の場合はgene-wise permutationを使う。

>[tab]sample1[tab]sample2[tab]sample3[tab]sample4[tab]sample5\
group[tab]1[tab]1[tab]0[tab]0[tab]0[tab]1[tab]0[tab]1[tab]na[tab]0\
factor[tab]-2.0[tab]3.0[tab]2.0[tab]1.0[tab]0.0


テストデータを使うと
```
 perl GSEAparallel/perl/gsea.pl GSEAparallel/data/coadExp3000.tab  EEM2.0/data/hallmark.gmt　GSEAparallel/sampleLabel.tab
```
GseaXXXXXXができ(XXXXXXは日付)その中のindex.htmlをブラウザで開けば結果見える。

A.tab、B.gmt、C.tabそれぞれは複数ファイル指定可能。
その場合、全ての組み合わせで解析を行う。
