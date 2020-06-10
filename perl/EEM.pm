# !/usr/bin/perl;

use strict;
use warnings;
#use DBI;
use MyMath;


###home dir###
my $HOME = $ENV{HOME}."/GSEAparallel";

sub set_environment{
    my $isN =  ($ENV{HOSTNAME}=~/^n/)?1:0;
    chomp(my @lib = `ls  $HOME/java/lib`);
    my $javapath = "/usr/local/package/java/current6/bin";
    my $rpath = $isN?"/usr/local/package/r/current/bin":"/usr/local/package/r/2.15.1_gcc/bin";
    unless(grep {$_ eq $javapath} split(":", $ENV{PATH})){
	$ENV{PATH} = $javapath.":".$ENV{PATH};
    }
    unless(grep {$_ eq $rpath} split(":", $ENV{PATH})){
	$ENV{PATH} = $rpath.":".$ENV{PATH};
    }
    $ENV{CLASSPATH} = $HOME."/java/bin:$HOME/java/lib/".join(":".$HOME."/java/lib/",@lib);   
    $ENV{R_LIBS} = $HOME."/R";
    $ENV{PERL5LIB} = $HOME."/perl";
}


sub get_home_dir{
    return $HOME;                                 
}                                                                                                    
       

sub get_script_dir{
    require Cwd;
    my $tmp =  Cwd::abs_path($0);
    $0 =~ /[^\/]+$/;
    my $tmp2 = $&;
    $tmp =~ /(.*)\/$tmp2/;
    return $1;
}


sub get_filename_without_suffix{
    if($_[0] =~ /^([^.\/]+)([^\/]*)$/){
        return $1;
    }elsif($_[0] =~ /((.*?\/)*([^.]+))/){
        return $3;
    }else{
	return;
    }
}

sub get_dir_and_filename_without_suffix{
    if($_[0] =~ /^([^.\/]+)([^\/]*)$/){
        return $1;
    }elsif($_[0] =~ /((.*?\/)*([^.]+))/){
        return $&;
    }else{
	return;
    }
}

sub print_SGE_script_for_R{
  my $Rscript = shift;
  my $Rvariable = shift; # ref of hash;
  my $fh;
  my @env = grep {defined($ENV{$_})} qw(PATH PERL5LIB R_LIBS CLASSPATH LD_LIBRARY_PATH BOWTIE_INDEXES);
  my @out = (
      '#!/usr/bin/perl',
      '#$ -S /usr/bin/perl',
      '#$ -v '.join (",",map {$_."=".$ENV{$_}} @env),
      'warn "R: '. $Rscript.'\n";',
      'warn "start time: ".scalar(localtime)."\n";',
      );
  push(@out, 'open(OUT, ">tmp${$}.R");');
  foreach my $k (keys %$Rvariable){
      my $v = $Rvariable->{$k};
      if($v =~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/){
	  push(@out, 'print OUT "'.$k.'<-'.$v.'\n";');
      }else{
	  push(@out, 'print OUT "'.$k.'<-\"'.$v.'\"\n";');
      }
  }
  #push(@out, 'print OUT "source(\"'.$Rscript.'\")\n";');
  push(@out, 'close(OUT);');
  push(@out, '`cat '.$Rscript.'  >>  tmp${$}.R`;');
  #push(@out, '`R --vanilla >& /dev/null  < tmp${$}.R`;');
  push(@out, '`R --vanilla  < tmp${$}.R`;');
  push(@out, '`rm tmp${$}.R`;');
  push(@out, 'warn "end time: ".scalar(localtime)."\n";');
  if(@_){
    open($fh, ">$_[0]");
    print $fh join("\n",@out)."\n";
  }else{
    print  join("\n",@out)."\n";
  }
}



#print_SGE_script($command, $fileName);
sub print_SGE_script{
  my $command = shift;
  my $fh;
  my @env = grep {defined($ENV{$_})} qw(PATH PERL5LIB R_LIBS CLASSPATH LD_LIBRARY_PATH BOWTIE_INDEXES);
  my @out = (
      '#! /usr/bin/perl',
      '#$ -S /usr/bin/perl',
      #'#$ -v '.join (",",map {$_."=".$ENV{$_}} @env),
      );
  foreach(@env){
      push(@out , '$ENV{'.$_.'}="'.$ENV{$_}.'";');
  }
  push(@out, (
           'warn "command : '. $command.'\n";',
           'warn "started @ ".scalar(localtime)."\n";',
           "if(system (\"$command\" )){",
           'die "failed @ ".scalar(localtime)."\n";',
           "}else{",
           'warn "ended @ ".scalar(localtime)."\n";',
	   "}"
       ));
  
  if(@_){
    open($fh, ">$_[0]");
    print $fh join("\n",@out)."\n";
    `chmod a+x $_[0]`;
  }else{
    print  join("\n",@out)."\n";
  }
}

sub print_SGE_script2{
    my $command = shift;
    my $fh;
    my @out = (
	'#!/usr/local/bin/nosh',
	'#$ -S /usr/local/bin/nosh',
	"export LANG='C'",
	"echo start@| tr -d '\\n' ; date",
	$command,
	"echo end@| tr -d '\\n' ; date"
	);
    if(@_){
	open($fh, ">$_[0]");
	print $fh join("\n",@out)."\n";
	`chmod a+x $_[0]`;
    }else{
	print  join("\n",@out)."\n";
    }
}


# %hash = mysql($db, $table, $key_field, $value_field);
sub mysql2hash{
  my $dbh = connect_to_mysql($_[0]);
  my @data = @{$dbh->selectall_arrayref("select $_[2] , $_[3] from $_[1]")};
  my %hash;
  foreach(@data){
    defined($_->[0]) or next; 
    $hash{$_->[0]} = $_->[1];
  }
  return %hash;
}

# %hash = mysql($db, $table, $key_field, $value_field);
sub mysql2hash_of_arrayref{
  my $dbh = connect_to_mysql($_[0]);
  my @data = @{$dbh->selectall_arrayref("select $_[2] , $_[3] from $_[1]")};
  my %hash;
  foreach(@data){
    defined($_->[0]) or next; 
    push(@{$hash{$_->[0]}}, $_->[1]);
  }
  return %hash;
}



sub read_hash_of_arrayref{
  my $fh;
  open($fh, $_[0]);
  my %hash;
  while(<$fh>){
    chomp;
    my @tmp = split("\t");
    my $key = shift(@tmp);
    $hash{$key} = \@tmp;
  }
  return %hash;
}

sub read_hash{
  my $fh;
  open($fh, $_[0]);
  my %hash;
  while(<$fh>){
    chomp;
    my @tmp = split("\t");
    $hash{$tmp[0]} = $tmp[1];
  }
  return %hash;
}




sub paste_files{
  my @files = @_;
  if(@files == 1){
    my $pat = shift @files;
    my $ls = `ls *`;
    my @ls = split(/\s+/, $ls);
    @files = grep {/$pat/} @ls;
  }
  
  my @tmp;
  my $max = 0;
  foreach(@files){
    chomp(my @tmp2 = `cat $_`);
    push(@tmp,[@tmp2]);
    if($max < @tmp2){
      $max = @tmp2;
    }
  }
  
  my @out;
  for(my $i = 0; $i < $max; $i++){
    my @tmp2;
    foreach(@tmp){
      push(@tmp2,$_->[$i]);
    }
    push(@out, join("\t", @tmp2)."\n");
  }
  return join("\n", @out)."\n";
} 

# split and write a infile to n outfiles Args: infile name, the number of outfiles, outfile name
sub split_file{
  my $file = shift;
  my $n = shift;
  my $split = shift;
  $split or $split = $file;
  if($n == 1){
    system("cp $file ${split}0");
    return;
  }
  `wc $file` =~ /\d+/;
  my $l = $&;
  my $m = $l/$n;
  unless($m == int($m)){
    if(int($m) >  $m){
      $m = int($m);
    }else{
      $m = int($m) + 1;
    }
  }
  my $i = 0;
  my $j = 0;
  my $fhout;
  my $fhin;
  open($fhout, ">${split}$j");
  open($fhin, $file);
  while(<$fhin>){
    if($i <  $m){
      print $fhout $_;
      $i++
    }else{
      $i = 0;
      $j++;
      open($fhout, ">${split}$j");
      print $fhout $_;
      $i++;
    }
  }
}



sub ps_grep_kill{
  my @pat = @_;
  @pat or return;
  my @ps = `ps -elf`;
  shift(@ps);
  my @kill;
 L:foreach my $ps (@ps){
    foreach(@pat){
      $ps =~ /$_/ or  next L;
    }
    my @tmp = split(/\s+/, $ps);
    push(@kill, $tmp[3]);
  } 
  return system("kill -KILL @kill");
}  



#get mysql DB handle  Args: datanase name  Returns: DB handle

sub connect_to_mysql {
  my $connect = "dbi:mysql:$_[0];host=mysql5.hgc.jp;port=3500;mysql_local_infile=1";
  chomp(my $host = `hostname`);
  return DBI->connect($connect, "niiyan", "jw6gv89m");
}



# immport_to_mysql($db, $table, $file);
sub immport_to_mysql {
  my $db = shift or return;
  my $table = shift or return;
  my $file = shift or return;
  system("mv  $file  ${table}.sub${$}");
  my $h = "mysql5.hgc.jp";
  chomp(my $host = `hostname`);
  system("mysqlimport -h $h -L  $db ${table}.sub${$}"); 
  system("mv  ${table}.sub${$} $file");
}



sub print_hash{
  my %hash = %{shift(@_)};
  my $filename = shift;
  use IO::File;
  my $fh;
  $filename and $fh = IO::File->new(">$filename");
  foreach( keys %hash ){
    if($fh){
      print $fh "$_\t".$hash{$_}."\n";
    }else{
      print  "$_\t".$hash{$_}."\n";
    }
  }
}



#sleep until  chidren finish Args: a command, the number of chidren  allowed to be runinng
sub wait_for_children_finishing{
  my $command = shift;
  my $n = shift;
  $n or $n = 1;
  while(1){
    my @wc =`ps -elf`;
    my $m = 0;
    foreach(@wc){
      /$command/ and $m++;
    }
    if($m <   $n){
      return;
    }
    sleep(10);
  }
}


sub  wait_for_SGE_finishing{
  my $script = shift;
  my $cutoff;
  if(@_){
    $cutoff = shift;
  }else{
    $cutoff = 1;
  }
  $script = substr($script,0,10);
  while(1){
    while(system("qstat > /dev/null") != 0){
      sleep(10);
    }
    my $out = `qstat| grep $script | wc`;
    $out =~ /\d+/;
    if($& < $cutoff ){
      return;
    }else{
      sleep(10);
    }
  }
}

 #parse command line options  Args: a ref to hash of flags to a scalar ref, a help message
sub get_options {
  my $hashref = shift;
  my @flag = keys %{$hashref};
  my $help = shift;
  while(defined($ARGV[0]) and $ARGV[0] =~ /^-([A-Za-z]+)/){
    if(grep {$_ eq $1} @flag){
      shift @ARGV;
      my $f = $1;
      if((defined($ARGV[0]) and $ARGV[0] =~ /^-([A-Za-z]+)/) or !(defined($ARGV[0]))){
	${$hashref->{$f}} = 1;
      }else{
	${$hashref->{$f}} = shift @ARGV;
      }
    }else{
      if($help){
	die $help;
      }else{
	return;
      }
    }
  }
  return 1;
}
  
sub split_array {
  my @array = @{shift(@_)};
  my $n = shift;
  $n or $n = @array;
  $n <= @array or $n = @array;
  if($n == 1){
    if(wantarray()){
      return \@array;
    }else{
      return [[@array]];
    }
  }
  my $m = @array/$n;
  unless($m == int($m)){
    if(int($m) >  $m){
      $m = int($m);
    }else{
      $m = int($m) + 1;
    }
  }
  my $ret;
  my $i = 0;
  my $j = 0;
  foreach(@array){
    if($i < $m){
      $ret->[$j][$i] = $_;
      $i++;
    }else{
      $i = 0;
      $j++;
      $ret->[$j][$i] = $_;
      $i++
    }
  }
  if(wantarray()){
    return @$ret;
  }else{
    return $ret;
  }
}




