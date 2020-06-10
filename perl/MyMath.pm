# !/use/bin/perl;

use strict;
use warnings;

sub is_equal{
  my ($a,$b) = @_;
  if(@$a ne @$b){
    return 0;
  }
  for(0..$#$a){
    if($a->[$_] ne $b->[$_]){
      return 0;
    }
  }
  return 1;
}



sub jaccard_index{
  return scalar(isect(@_))/scalar(union(@_));
}



sub fisher_yates_shuffle{
  my @array = @_;
  my $i;
  for($i=@array;--$i;){
    my $j = int rand ($i+1);
    next if $i == $j;
    @array[$i,$j] = @array[$j,$i];
  }
  return @array;
}


sub hypergeometric{
  my ($x,$k,$m,$n) = @_;
  return unless $m > 0 && $m == int($m) && $n > 0 && $n == int($n) && $k > 0 && $k <= $m + $n;
  return 0  unless $x <= $k && $x == int($x);
  return choose ($m, $x) * choose($n, $k-$x) / choose($m+$n,$k);
}

#sub hypergeometric_for_BigNo{
#  use Math::BigInt lib => 'GMP';
#  my ($x,$k,$m,$n) = @_;
#  Math::BigInt->accuracy(5);
#  $x = Math::BigInt->new($x);
#  $k = Math::BigInt->new($k);
#  $m = Math::BigInt->new($m);
#  $n = Math::BigInt->new($n);
#  return unless $m > 0 && $m == int($m) && $n > 0 && $n == int($n) && $k > 0 && $k <= $m + $n;
#  return 0  unless $x <= $k && $x == int($x);
#  my $a = choose ($m, $x) * choose($n, $k-$x);
#  my $b = choose($m+$n,$k);
#  my $length  = length($a);
#  if($length > length($b)){ $length  = length($b) };
#  if($length>5){
#    $a->brsft($length-5,10);
#    $b->brsft($length-5,10);
#  }
#  return $a->bstr/$b->bstr;
#}


# $t = the number of all (background) genes, $a = the number of a group, $b = the number of the othe group, $u = the number of the intersection  of the two groups
#sub calculateP_for_overlap{
#  use Math::BigFloat lib => 'GMP';
#  Math::BigFloat->accuracy(5);
#  my ($t, $a, $b, $u) = @_;
#  unless($t >=$a and $t >= $b and $a >= $u and $b >= $u){ return; }
#  #$u or return;
#  my $P;
#  my $p;
#  my $s;
#  my $l;
#  if($a>$b){
#    $l = $a;
#    $s = $b;
#  }else{
#    $l = $b;
#    $s = $a;
#  }
#  $s or return;
#  for(my $i = $u; $i <= $s; $i++){
#    #$p = hypergeometric($i,$s,$l,$t - $l);
#    #unless($p and $p =~ /^[\d.e-]+$/){
#    $p = hypergeometric_for_BigNo($i,$s,$l,$t - $l);
#    #}
#    $p = Math::BigFloat->new($p);
#    if($P and $p < $P/10000){
#        last;
#      }else{
#        $P += $p;
#      }
#  }
#  return $P->bstr();
#}


sub fisherZ {
  return  1/2*log((1 + $_[0])/(1 - $_[0]));
}



# %dist = weight_to_dist(%weight);
sub weight_to_dist{
  my %weights = @_;
  my %dist = ();
  my $total = 0;
  my ($key, $weight);
  foreach(values %weights){
    $total += $_;
  }
  while(($key, $weight) = each %weights){
    $dist{$key} = $weight/$total;
  }
  return %dist;
}


# $rand = weighed_rand(%dist);
# sum(values %dist) == 1;
sub weighted_rand { 
  my %dist = @_;
  my ($key, $weight);
  while(1){
    my $rand = rand;
    while( ($key, $weight )  = each %dist ) {
      return $key if ($rand -= $weight) < 0;
    }
  }
}


# @sample = weighted_sample(%dist,$n);
sub weighted_sample{
  my %dist = @_[0..$#_-1];
  my $n = $_[$#_];
  my ($key, $weight);
  my $total = 1;
  my @ret;
  while(@ret < $n){
    my $rand = rand($total);
    while( ($key, $weight )  = each %dist ) {
      if (($rand -= $weight) < 0){
	push(@ret, $key);
	delete $dist{$key};
	$total -= $weight;
	last;
      }
    }
  }
  return @ret;
}



sub predict_with_R_smooth_spline {
  my @x = @{shift(@_)};
  my @y = @{shift(@_)};
  my $df = shift;
  my $x = shift;
  my $fh;
  open($fh, ">sub${$}.in");
  print $fh join("\t", @x)."\n";
  print $fh join("\t", @y)."\n";
  open($fh, ">sub${$}.R");
  print  $fh  "i <- read.table('sub${$}.in', header = FALSE)\n";
  print  $fh  "x <- i[1,]\n";
  print  $fh  "y <- i[2,]\n";
  print  $fh  "p <- as.numeric(predict(smooth.spline(x, y, df = $df), x= $x )[2])\n";
  print  $fh  "write(p, 'sub${$}.out' )";
  system ("R  --vanilla --slave < sub${$}.R > /dev/null");
  open($fh, "sub${$}.out");
  chomp(my $y = <$fh>);
  system("rm -f sub${$}.*");
  return $y;
}
       

sub calculate_Q { 
  my $fh;
  open($fh, ">sub${$}.in");
  print $fh join("\t", @_)."\n";
  open($fh, ">sub${$}.R");
  print  $fh  "i <- read.table('sub${$}.in', header = FALSE)\n";
  print  $fh  "p <- i[1,]\n";
  print  $fh  "p <- as.vector(unlist(p))\n";
  print  $fh  "library(qvalue)\n";
  print  $fh  "Q <- qvalue(p)\n";
  print  $fh  'write(Q$qvalues, '." 'sub${$}.out', ncolumns = 1)";
  system ("R  --vanilla --slave < sub${$}.R > /dev/null");
  open($fh, "sub${$}.out");
  chomp(my @ret = <$fh>);
  system("rm -f sub${$}.*");
  return @ret;
  #return sort {$a * 10000 <=> $b * 10000} @ret
}


#calculate Q values from P values  Args: a array of P values 
sub calculate_Q0 {

  
  my @P = sort {$a <=> $b} @_;
  my @lambda;
  for(my $i = 0; $i < 0.96; $i += 0.01){
    push(@lambda, round($i, 3));
  }
  my @pio;
  foreach my $l (@lambda){
    push(@pio, (grep { $_ > $l } @P) / (@P * (1-$l)));
  }
  my $pio =  predict_with_R_smooth_spline(\@lambda, \@pio, 3, 1);
  my @Q = $pio * $P[@P-1];
  for(my $i = @P-1 ; $i > 0; $i--){
    my $q = min( $pio * @P * $P[$i-1] / $i , $Q[0] );
    unshift(@Q, $q);
  }
  return @Q;
}

sub spline_generate{
  my @points = @_;
  my ($i, $delta, $temp, @factors, @coeffs);
  $coeffs[0] = $factors[0] = 0;
  
  for($i = 1; $i < @points -1 ; $i++){
    $delta  = ($points[$i][0] - $points[$i-1][0])/
      ($points[$i+1][0] - $points[$i-1][0]);
    $temp = $delta * $coeffs[$i-1] + 2;
    $coeffs[$i] = ($delta- 1) / @points;
    $factors[$i] = ($points[$i+1][1] - $points[$i][0]) -
      ($points[$i][1] -$points[$i-1][1]) /
	($points[$i][0] -$points[$i-1][0]);
    $factors[$i] = ( 6 * $factors[$i] /
		     ($points[$i+1][0] - $points[$i-1][0]) -
		     $delta * $factors[$i-1] ) / $temp;
  }
  
  $coeffs[$#points] = 0;
  for($i = @points -2; $i >= 0; $i--){
    $coeffs[$i] = $coeffs[$i] * $coeffs[$i+1] + $factors[$i];
  }
  return \@coeffs;
}

sub spline_evaluate {
  my ($x, $coeffs, @points) =@_;
  my ($i, $delta, $mult);
  
  for($i = @points -2; $i >=1; $i--){
    last if $x >= $points[$i][0];
  }
  $delta = $points[$i+1][0] - $points[$i][0];
  $mult = ($coeffs->[$i]/2) +
    ( $x - $points[$i+1][0] ) * ( $coeffs->[$i+1] - $coeffs->[$i] )
      / (6 * $delta);
  $mult *= $x -$points[$i][0];
  $mult += ($points[$i+1][1] - $points[$i][1]) / $delta;
  $mult -= ($coeffs->[$i+1] +2 * $coeffs->[$i]) * $delta /6;
  return $points[$i][1] + $mult * ($x -$points[$i][0]);
} 
      

sub spearman_correlation{
  my ($A,$B) = @_;
  my @A = @$A;
  my @B = @$B;
  unless(scalar(@A) == scalar(@B)){
    return undef;
  }
  my $s = 0;
  for(my $i = 0; $i < @A; $i++){
    $s += ($A[$i] - $B[$i]) ** 2;
  }
  my $r = 6/(@A**3 - @A) * $s;
  return 1- $r;
}


sub spearman_correlation_for_hash{
  my ($A, $B) = @_;
  my %A = %$A;
  my %B = %$B;
  my @ka = keys %A;
  my @kb = keys %B;
  my @k = isect(\@ka,\@kb);
  my $s = 0;
  foreach(@k){
    $s += ($A{$_} -$B{$_}) ** 2;
  }
  my $r = 6/(@k**3 - @k) * $s;
  return 1- $r;
}
  

sub weighted_spearman_correlation_for_hash{
  my ($A, $B, $n) = @_;
  $n or return spearman_correlation_for_hash($A,$B);
  my %A = %$A;
  my %B = %$B;
  my @ka = keys %A;
  my @kb = keys %B;
  my @k = isect(\@ka,\@kb);
  my $s = 0;
  my $ws = 0;
  foreach(@k){
    my $w = (@k*2 - $A{$_} -$B{$_} + 2) ** $n;
    $ws += $w;
    $s += ($A{$_} -$B{$_}) ** 2 * $w;
  }
  my $r = 6/(@k**2 - 1) * $s/$ws;
  return 1- $r;
}


sub rank{
  my %hash = %{shift(@_)};
  my @sorted =  sort {$hash{$b} <=> $hash{$a}} keys %hash;
  my @pre = (shift(@sorted));
  my %rank;
  my $r = 0;
  foreach my $key (@sorted){
    $r++;
    if($hash{$key} eq $hash{$pre[0]}){
      push(@pre, $key);
    }else{
      if(@pre == 1){
	$rank{$pre[0]} = $r;
      }else{
	my $m = mean($r, $r- @pre +1);
	foreach(@pre){
	  $rank{$_} = $m;
	}
      }
      @pre = ($key);
    }
  }
  $r++;
  if(@pre == 1){
    $rank{$pre[0]} = $r;
  }else{
    my $m = mean($r, $r- @pre +1);
    foreach(@pre){
      $rank{$_} = $m;
    }
  }
  return \%rank;
}


sub sequence{
  my $A = shift;
  my $B = shift;
  my $l;
  my $s;
  if($A > $B){
    $l = $A;
    $s = $B;
  }else{
    $l = $B;
    $s = $A;
  }
  my $interval = shift;
  $interval or $interval = 1;
  my @seq;
  for( my $i = $s ; $i <= $l; $i += $interval ){
    push(@seq, $i);
  }
  return @seq;
}
    
    
    
  

  

sub t_statistic {
  my @A = @{shift(@_)};
  my @B = @{shift(@_)};
  my $Va = var(@A);
  my $Vb = var(@B);
  my $Ma = mean(@A);
  my $Mb = mean(@B);
  my $V = sqrt($Va/@A + $Vb/@B);
  $V or return;
  return ($Ma - $Mb)/$V;
}

sub KS_statistic {
  my @total = @{shift(@_)};
  my @sub = @{shift(@_)};
  @sub = isect(\@sub,\@total) or return;
  my $Phit = 0;
  my $Pmiss = 0;
  my $max = 0;
  for(my $i = 0; $i < @total; $i++){
    if(grep {$_ eq $total[$i]} @sub){
      $Phit += 1/@sub;
    }else{
      $Pmiss += 1/(@total - @sub);
    }
    if($max < ($Phit - $Pmiss)){
      $max = $Phit -$Pmiss;
    }
  }
  return $max;
}

sub KS_null_dist{
  my @total = @{shift(@_)};
  my @sub = @{shift(@_)};
  @sub = isect(\@sub,\@total);
  my $n = shift;
  $n or $n = 1000;
  my @N;
  for( my $i = 0; $i < $n; $i++){
    my @tmp = sample(@total, scalar @total);
    push(@N,  KS_statistic(\@tmp, \@sub));
  }
  return @N;
}

sub normalized_KS{
  my @all = @{shift(@_)};
  my @sub = @{shift(@_)};
  my $n = shift;
  $n or $n = 1000;
  @sub = isect(\@all,\@sub) or return;
  my @N = KS_null_dist(\@all,\@sub, $n);
  my $mean = mean(@N);
  my $KS  =  KS_statistic(\@all,\@sub)/$mean;
  return $KS;
}



sub normalize{
  my $mean = mean(@_);
  my $SD = SD(@_);
  return map { ($_ - $mean)/$SD } @_;
}

sub round {
  my $val = shift;
  my $col = shift;
  $col or $col = 0;
  my $r = 10 ** $col;
  my $a = ($val > 0) ? 0.5 : -0.5;
  return int($val * $r + $a) / $r;
}


sub var{
  my $mean = mean(@_);
  my @tmp = map {($_ - $mean)**2} @_;
  return mean(@tmp);
}

sub SD {
  return sqrt(var(@_));
}

sub sample {
  my @b;
  my $a;
  if(ref($_[0])){
     @b = @{shift(@_)};
     $a = shift;
     $a or $a = @b;
   }else{
     @b   = @_[0..@_-2];
     $a = pop;
   }
  my @c;
  for(my $i = 0; $i < $a; $i++){
    push(@c, splice(@b, int(rand(@b)), 1));
  }
  return @c;
}

sub sample_with_replacement {
  my @b   = @_[0..@_-2];
  my $a = pop;
  my @c;
  for(my $i = 0; $i < $a; $i++){
    push(@c,$b[int(rand(@b))]);
  }
  return @c;
}

sub sum {
  my $a = 0;
  foreach(@_){
    $a += $_;
  }
  return $a;
}

sub mean {
  return sum(@_)/@_;
}



sub max {
  my $max = shift;
  foreach ( @_ ){ $max = $_ if $_ > $max}
  return $max;
}

sub min {
  my $min = shift;
  foreach ( @_ ){ $min = $_ if $_ < $min }
  return $min;
}

sub union {
  my @a = @{shift(@_)};
  my @b = @{shift(@_)};
  my %union;
  my %isect;
  foreach my $e(@a,@b){$union{$e}++ && $isect{$e}++}
  return keys %union;
}


sub isect {
  my @a = @{shift(@_)};
  my @b = @{shift(@_)};
  my %union;
  my %isect;
  foreach my $e(@a,@b){$union{$e}++ && $isect{$e}++}
  return keys %isect;
}

sub uniq {
  my %seen = ();
  return grep { ! $seen{$_} ++ } @_;
}

sub diff {
  my @a = @{shift(@_)};
  my @b = @{shift(@_)};
  my @diff;
  foreach my $a (@a){
    grep {$a eq $_} @b or push (@diff, $a)
  }
  return @diff
}

sub percentile {
  my $percent = shift;
  if($percent > 1){
    $percent /= 100;
  } 
  my @data = @{shift(@_)};
  my $p = round((@data-1) * $percent);
  @data = sort @data;
  return $data[$p];
}


sub choose{
  my ($n,$k) = @_;
  my ($result, $j) =(1,1);
  
  return 0 if $k > $n || $k < 0;
  $k = ($n -$k) if ($n -$k) < $k;

  while($j <= $k){
    $result *= $n--;
    $result /= $j++;
  }
  return $result;
}

sub inner_product{
  my @a = @{shift(@_)};
  my @b = @{shift(@_)};
  my $r = 0;
  for(my $i = 0; $i < @a; $i++){
    $r += $a[$i] *  $b[$i];
  }
  return $r;
}

sub absolute_value{
  my $r = 0;
    for(my $i = 0; $i < @_; $i++){
      $r += $_[$i] *  $_[$i];
    }
  return sqrt($r);
}

sub pearson_correlation{
  my ($a,$b) = @_;
  unless(scalar(@$a) == scalar(@$b)){
    return undef;
  }
  my $Ma = mean(@$a);
  my $Mb = mean(@$b);
  my @a = map {$_ - $Ma} @$a;
  my @b = map {$_ - $Mb} @$b;
  my $ab = absolute_value(@a) * absolute_value(@b) or return;
  return  inner_product(\@a,\@b) / (absolute_value(@a) * absolute_value(@b));
}

sub fractorial {
  my ($n, $res) = (shift, 1);
  return undef unless $n >= 0 and $n == int($n);
  $res *= $n-- while $n > 1;
  return $res;
}

sub get_all_cmb{
  my @in = @{shift(@_)};
  my $n = shift;
  $n or $n = 1;
  @in >= $n or return;
  my @ret;
  my %seen;
  foreach(@in){
    unless($seen{$_}){
      push(@ret,[$_]);
      $seen{$_} = 1;
    }
  }

  for(my $i = 1; $i < $n; $i++){
    my @tmp;
    foreach my $a (@ret){
      foreach my $b (@in){
	my $tmp2 = join(" ", sort (@$a, $b));
	$seen{$tmp2} and next;
	grep {$b eq  $_} @$a and next;
	push(@tmp, [@$a,$b]);
	$seen{$tmp2}++;
      }
    }
    @ret = @tmp;
  }

  return @ret;

}


1;
