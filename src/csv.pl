#!/usr/bin/perl
#
use strict;
use warnings;

if ( ! -d "$ARGV[0]" ) {
  print "$ARGV[0] does not exist\n";
}
if ( ! -f "./search25_10.txt" || ! -f "./template25_10.txt" || ! -f "$ARGV[0]/search25_10.txt" || ! -f "$ARGV[0]/template25_10.txt") {
  print "Usage: csv.pl dir\n";
  print "    Opens ./search25_10.txt, ./template25_10.txt and the same files \n";
  print "    in dir. Creates csv file with statistics on each sample.\n";
  exit(1);
}

open(my $base, "-|","grep -h \"^F[OA][UI][NL]\" search25_10.txt template25_10.txt") || die "open base files failed: $!";
open(my $tune, "-|","grep -h \"^F[OA][UI][NL]\" $ARGV[0]/search25_10.txt $ARGV[0]/template25_10.txt") || die "open tune files failed: $!";

my @srcvocab=(
"+s",
"-s",
"*s",
"/s",
"is",
"ns",
"+v",
"-v",
"*v",
"nv",
"f1s",
"f1v",
"f2s",
"f2v",
"f3s",
"f3v",
"f4s",
"f4v",
"f5s",
"f5v",
"g1s",
"g1v",
"g2s",
"g2v",
"g3s",
"g3v",
"g4s",
"g4v",
"g5s",
"g5v",
"h1s",
"h1v",
"h2s",
"h2v",
"h3s",
"h3v",
"h4s",
"h4v",
"h5s",
"h5v",
"u1s",
"u1v",
"u2s",
"u2v",
"u3s",
"u3v",
"u4s",
"u4v",
"u5s",
"u5v",
"v1s",
"v1v",
"v2s",
"v2v",
"v3s",
"v3v",
"v4s",
"v4v",
"v5s",
"v5v",
"=",
"===",
";",
"s01",
"s02",
"s03",
"s04",
"s05",
"s06",
"s07",
"s08",
"s09",
"s10",
"s11",
"s12",
"s13",
"s14",
"s15",
"s16",
"s17",
"s18",
"s19",
"s20",
"s21",
"s22",
"s23",
"s24",
"s25",
"s26",
"s27",
"s28",
"s29",
"s30",
"v01",
"v02",
"v03",
"v04",
"v05",
"v06",
"v07",
"v08",
"v09",
"v10",
"v11",
"v12",
"v13",
"v14",
"v15",
"v16",
"v17",
"v18",
"v19",
"v20",
"v21",
"v22",
"v23",
"v24",
"v25",
"v26",
"v27",
"v28",
"v29",
"v30",
"0s",
"1s",
"0v");

my @tgtvocab=(
"Cancel",
"Noop",
"Double",
"Commute",
"Multzero",
"Distribleft",
"Distribright",
"Factorleft",
"Factorright",
"Assocleft",
"Assocright",
"Flipleft",
"Flipright",
"Newtmp",
"Deletestm",
"Swapprev",
"Usevar",
"Inline",
"Multone",
"Divone",
"Addzero",
"Subzero",
"Rename",
"s01",
"s02",
"s03",
"s04",
"s05",
"s06",
"s07",
"s08",
"s09",
"s10",
"s11",
"s12",
"s13",
"s14",
"s15",
"s16",
"s17",
"s18",
"s19",
"s20",
"s21",
"s22",
"s23",
"s24",
"s25",
"s26",
"s27",
"s28",
"s29",
"s30",
"v01",
"v02",
"v03",
"v04",
"v05",
"v06",
"v07",
"v08",
"v09",
"v10",
"v11",
"v12",
"v13",
"v14",
"v15",
"v16",
"v17",
"v18",
"v19",
"v20",
"v21",
"v22",
"v23",
"v24",
"v25",
"v26",
"v27",
"v28",
"v29",
"v30",
"N",
"Nl",
"Nr",
"Nll",
"Nlr",
"Nrl",
"Nrr",
"Nlll",
"Nllr",
"Nlrl",
"Nlrr",
"Nrll",
"Nrlr",
"Nrrl",
"Nrrr",
"Nllll",
"Nlllr",
"Nllrl",
"Nllrr",
"Nlrll",
"Nlrlr",
"Nlrrl",
"Nlrrr",
"Nrlll",
"Nrllr",
"Nrlrl",
"Nrlrr",
"Nrrll",
"Nrrlr",
"Nrrrl",
"Nrrrr",
"stm1",
"stm2",
"stm3",
"stm4",
"stm5",
"stm6",
"stm7",
"stm8",
"stm9",
"stm10",
"stm11",
"stm12",
"stm13",
"stm14",
"stm15",
"stm16",
"stm17",
"stm18",
"stm19",
"stm20");

print "Create,A,B,A,B,Base,Tune,Num,Sclr,Vctr,Total,Max,Generated,Base,Tune",",ProgA"x scalar @srcvocab,",Gen'd"x scalar @tgtvocab,",Base"x scalar @tgtvocab,",Tune"x scalar @tgtvocab,"\n";
print "Method,Tokens,Tokens,#Stm,#Stm,Pass,Pass,Inputs,Outs,Outs,Vars,Depth,Axioms,Axioms,Axioms,",join (",",@srcvocab),",",join (",",@tgtvocab),",",join (",",@tgtvocab),",",join (",",@tgtvocab),"\n";

my $method="AxiomGen";
while (<$base>) {
  my $tune_ln=<$tune> || die "tune files ended early";
  /^(F\w+): (.*; )to (.*; )(bestguess|with) +(\S.*)Target path: (.*)$/ || die "bad syntax in base line: $_";
  print "$method,";
  ($.==1000) && ($method="Template");
  my $found=$1;
  my $progA=$2;
  my $progB=$3;
  my $baseproof=$5;
  my $tgt=$6;
  $tune_ln=~/^(F.*): \Q${progA}to ${progB}\E(bestguess|with) +(\S.*)Target path: $tgt$/ || die "bad syntax in tuned line: $tune_ln Base line: $_";
  my $tune_found=$1;
  my $tuneproof=$3;
  if ($found=~/FOUND/) {
    $found=1;
  } else {
    $found=0;
    $baseproof="";
  }
  if ($tune_found=~/FOUND/) {
    $tune_found=1;
  } else {
    $tune_found=0;
    $tuneproof="";
  }

  my @tokA=split /[;() ]+/,$progA;
  my @tokGen=split / /,$tgt;
  my @tokBase=split / /,$baseproof;
  my @tokTune=split / /,$tuneproof;

  printf "%d,%d,%d,%d,",
         (scalar @tokA),
         (scalar split /[;() ]+/,$progB),
         int(grep { /=/ } split / /,$progA),
         int(grep { /=/ } split / /,$progB);
  printf "%d,%d,",$found,$tune_found;
  my $inp=0;
  my $nvar=0;
  my $sout=0;
  my $vout=0;
  for (my $i=1; $i<=30; $i++) {
    my $var=sprintf "s%02d",$i;
    if ($progA=~/^.*?$var (.)/) {
      if ($1 ne "=") {
        $inp++;
      }
      if (/$var ===/) {
        $sout++;
      }
      $nvar++;
    }
    $var=sprintf "v%02d",$i;
    if ($progA=~/^.*?$var (.)/) {
      if ($1 ne "=") {
        $inp++;
      }
      if (/$var ===/) {
        $vout++;
      }
      $nvar++;
    }
  }
  my $progTmp=$progA;
  $progTmp=~s/[^()]//g;
  while ($progTmp =~s/\)\(//g) {};
  printf "%d,%d,%d,%d,%d,",$inp,$sout,$vout,$nvar,length($progTmp)/2+1;

  print int(grep { /stm\d/ } @tokGen),",";
  print int(grep { /stm\d/ } @tokBase),",";
  print int(grep { /stm\d/ } @tokTune);

  foreach my $tok (@srcvocab) {
    print ",",int(grep { /^\Q$tok\E$/ } @tokA);
  }
  foreach my $tok (@tgtvocab) {
    print ",",int(grep { /^\Q$tok\E$/ } @tokGen);
  }
  foreach my $tok (@tgtvocab) {
    print ",",int(grep { /^\Q$tok\E$/ } @tokBase);
  }
  foreach my $tok (@tgtvocab) {
    print ",",int(grep { /^\Q$tok\E$/ } @tokTune);
  }
  print "\n";
}

