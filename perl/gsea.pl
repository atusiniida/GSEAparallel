#!/usr/bin/perl

use strict;
use warnings;

if($0 =~ /.*(\/){0,1}perl/){
  unshift(@INC, $&);
}

require EEM;
require MyMath;


my $HOME = get_home_dir();
#set_environment();

my $help = qq($0 [-o outDir] expFile(*.tab)  geneSetFile(*.gmt) sampleLableFile(*.tab)
);

my $outDir = "";
my $argv = join(" ",@ARGV);
if($argv =~ s/-o\s+(\S+)//){
  $outDir = $1;
}
@ARGV = split(" ", $argv);

my @expFile;
my @geneSetFile;
my @sampleLabelFile;

my $f = 0;
foreach(@ARGV){
  if($f == 0 and /\.tab$/){
    push(@expFile, $_);
  }elsif(/\.gmt$/){
    push(@geneSetFile, $_);
    $f = 1;
  }elsif($f== 1 and /\.tab$/){
    push(@sampleLabelFile, $_);
  }
}

@expFile or die $help;
@geneSetFile or die $help;
@sampleLabelFile or die $help;


my $genePermutationCutoff = 3;

#my $gseaDir = get_home_dir()."/GSEA/";
my $gseaDir = get_home_dir()."/GSEA_4.0.3/";
if(!-d $gseaDir){
  die "cannot find GSEA_4.0.3!\n";
}

#my $command =  "/usr/local/package/java/10_2018-03-20/bin/java -Xmx2048m -XX:CompressedClassSpaceSize=256m -cp ${gseaDir}gsea2-2.07.jar xtools.gsea.Gsea";
my $command =   "sh  ${gseaDir}gsea-cli.sh GSEA  ";

my $sgeMem = 8;
my $sgeMemArg = "-l s_vmem=${sgeMem}G,mem_req=${sgeMem}G,os7";

my ($d,$m,$y) = (localtime(time))[3,4,5];
$m += 1;
if(length($m)==1){
  $m = "0".$m;
}
if(length($d)==1){
  $d = "0".$d;
}
$y += 1900;
$y =~ s/^\d\d//;

if($outDir eq ""){
  $outDir = "Gsea".$y.$m.$d;
}

my $outDir2 = "$m$d";
my $outDir3 = "$m".($d+1);
if(-d $outDir2){
  $outDir2 = "";
}
if(-d $outDir3){
  $outDir3 = "";
}

my %finish;
if(-d $outDir){
  chomp(my @ls = `ls $outDir`);
  @ls =  grep{/\.Gsea\.\d+/} @ls;
  foreach(@ls){
    if(open(IN, "$outDir/$_/index.html")){
      s/\.Gsea\.\d+//;
      $finish{$_} = 1;
    }else{
      `rm -r $outDir/$_`;
    }
  }
}


my $prefix = "tmp${$}";
my $k = 0;
my $retry = 1;
while($retry){
  foreach my $expFile (@expFile){
    chomp(my $tmp = `head -1 $expFile`);
    my @colname = split("\t", $tmp);
    shift(@colname);
    chomp(my @rowname = `cut -f 1 $expFile`);
    shift(@rowname);
    $expFile =~ /(.*?\/)*([^.]+)/;
    my $expFile2 = $2;
    foreach my $sampleLabelFile(@sampleLabelFile){
      chomp(my $tmp = `head -1 $sampleLabelFile`);
      my @colname2 = split("\t", $tmp);
      shift(@colname2);
      chomp(my @rowname2 = `cut -f 1 $sampleLabelFile`);
      shift(@rowname2);

      my @colnameIsect;
      my $infh;
      if(@colnameIsect = isect(\@colname, \@colname2)){
        open($infh,$sampleLabelFile);
      }elsif(@colnameIsect = isect(\@colname, \@rowname2)){
        open(IN,$sampleLabelFile);
        my @in;
        while(<IN>){
          chomp;
          push(@in, [split("\t")]);
        }
        open(OUT, ">$prefix.annot.tab");
        for(my $i = 0; $i < @{$in[0]}; $i++){
          my @tmp;
          for(my $j = 0; $j < @in; $j++){
            push(@tmp, defined($in[$j][$i])?$in[$j][$i]:"");
          }
          print OUT join("\t", @tmp)."\n";
        }
        close(OUT);
        open($infh, "$prefix.annot.tab");
      }else{
        next;
      }

      my %colnameIsect;
      map {$colnameIsect{$_} = 1} @colnameIsect;

      my %colnameIsect2expIndex;

      chomp($tmp = <$infh>);
      my @colnameSampleLabel = split("\t",$tmp);
      shift(@colnameSampleLabel);

      while(<$infh>){
        chomp;
        my ($id, @value) = split("\t");

        my %colnameSampleLabel2value;
        for(my $i=0; $i<@value; $i++){
          if(!defined($value[$i]) or $value[$i] eq "" or $value[$i] eq "na" or  $value[$i] eq "NA"){
            next;
          }elsif ($colnameIsect{$colnameSampleLabel[$i]}){
            $colnameSampleLabel2value{$colnameSampleLabel[$i]} = $value[$i];
          }
        }

        my @colnameSampleLabel2 = sort {$colnameSampleLabel2value{$a} <=> $colnameSampleLabel2value{$b}} keys %colnameSampleLabel2value;
        my @value2 = map {$colnameSampleLabel2value{$_} } @colnameSampleLabel2;
        my $numeric = 0;
        my $useGenePermutation = 0;
        open(OUT, ">$prefix.${expFile2}.${id}.cls");
        my @valueUniq = uniq(@value2);
        if(@valueUniq  < 3){
          print OUT join(" ", (scalar(@value2), scalar(@valueUniq), 1))."\n";
          print OUT join(" ", ("#", @valueUniq))."\n";
          for my $v (@valueUniq){
            if(scalar(grep {$v eq $_} @value2) <= $genePermutationCutoff){
              $useGenePermutation = 1;
            }
          }
        }else{
          $numeric = 1;
          print OUT "#numeric\n";
          print OUT "#${id}\n";
        }

        print OUT join(" ", @value2)."\n";

        open(IN2, $expFile);
        chomp(my $tmp = <IN2>);
        my @colnameExp = split("\t",$tmp);
        shift(@colnameExp);
        my %colnameExp2index;
        map {$colnameExp2index{$colnameExp[$_]}=$_} (0..$#colnameExp);
        my @index = map {$colnameExp2index{$_}} @colnameSampleLabel2;
        open(OUT, ">$prefix.$expFile2.${id}.gct");

        print OUT "#1.2\n";
        print OUT join("\t", (scalar(@rowname), scalar(@index)))."\n";
        print OUT join("\t", ("NAME", "Description",@colnameExp[@index]))."\n";
        while(<IN2>){
          chomp;
          my ($id, @value) = split("\t");
          print OUT join("\t", ($id, "na", (@value[@index])))."\n";
        }

        foreach my $geneSetFile(@geneSetFile){
          $geneSetFile =~ /(.*?\/)*([^.]+)/;
          my $geneSetFile2 = $2;
          if($finish{"${expFile2}.${geneSetFile2}.${id}"}){
            next;
          }
          my $command2 = $command." -rpt_label ${expFile2}.${geneSetFile2}.${id}  -gmx $geneSetFile  -collapse false   -res $prefix.$expFile2.${id}.gct -out $outDir -cls $prefix.${expFile2}.${id}.cls";
          if($numeric){
            $command2 .= "#$id -metric Pearson "
          }
          if($useGenePermutation){
            $command2 .= " -permute gene_set ";
          }
          $k++;
          #wait_for_SGE_finishing("$prefix.", 10);
          print_SGE_script2($command2,"$prefix.${expFile2}.${geneSetFile2}.${id}.sh");
          while(system("qsub  $sgeMemArg   -cwd  -o $prefix.${expFile2}.${geneSetFile2}.${id}.err2 -e $prefix.${expFile2}.${geneSetFile2}.${id}.err  $prefix.${expFile2}.${geneSetFile2}.${id}.sh") != 0){
            sleep(10);
          }
          $finish{"${expFile2}.${geneSetFile2}.${id}"} = 0
        }
      }
    }
  }

  wait_for_SGE_finishing("$prefix.");


  my @ids = keys %finish;
  foreach my $id (@ids){
    chomp(my @ls = `ls $outDir`);
    @ls =  grep{/$id\.Gsea\.\d+/} @ls;
    @ls or next;
    foreach my $ls (@ls){
      if(open(IN, "$outDir/$ls/index.html")){
        $finish{$id} = 1;
      }else{
        `rm -r $outDir/$ls`;
      }
    }
  }
  if(grep {$finish{$_} == 0} @ids){
    $retry = 1;
  }else{
    $retry = 0;
  }
}


open(OUT, ">$outDir/index.html");

print OUT "<HTML>\n";
print OUT "<HEAD>\n";
print OUT "<TITLE>GSEA result</TITLE>\n";
print OUT "</HEAD>\n";
print OUT "<BODY>\n";
print OUT "<UL>\n";

my @ids = sort keys %finish;
chomp(my @ls = `ls $outDir`);
for my $id (@ids){
  my @ls2 =  grep{/$id\.Gsea\.\d+/} @ls;
  open(IN, "$outDir/$ls2[0]/index.html");
  undef($/);
  my $in = <IN>;
  $/ = "\n";
  $in =~ /\d+ \/ (\d+) gene sets are upregulated/;
  my $total = $1;
  my $significant = 0;
  while($in =~ /(\d+) gene sets are significant at FDR/g){
    $significant += $1;
  }
  while($in =~ /(\d+) gene sets are significantly enriched at FDR/g){
    $significant += $1;
  }
  print OUT "<LI><A href=\"$ls2[0]/index.html\">$id</A> ($significant/$total are significantly enriched at FDR < 25%)\n";
}
print OUT "</UL>\n";
print OUT "</BODY>\n";
print OUT "</HTML>\n";

if($outDir2 and -d $outDir2){
  `rm -r $outDir2`;
}
if($outDir3 and -d $outDir3){
  `rm -r $outDir3`;
}
`rm $prefix.*`;
my @core = `ls`;
if(grep {/^core\./} @core){
  `rm core.*`;
}
chomp(my @emp = `find . -maxdepth 1  -type d -empty`);
if(@emp){
  map {`rm -r $_`} @emp;
}
