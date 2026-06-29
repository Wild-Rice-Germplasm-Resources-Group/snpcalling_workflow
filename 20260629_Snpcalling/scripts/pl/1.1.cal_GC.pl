#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename;
use Parallel::ForkManager;
use v5.10;
use Getopt::Long;
use Getopt::Std;
use Parallel::ForkManager;
use Cwd 'abs_path';
use IPC::Open2;
use zzIO;

my $samtools='samtools';


my ($file,$outfile,$genomeSize)=@ARGV or die "usage: perl $0 bam_file outGCfile genomeSize\n";
my $id;
#if($file=~m/(.*\/)(\S+)\.(realn|sort|rehead)\.bam$/){
my $base = basename $file;
if ($base=~/^([^.]+)/){
    $id=$1;
}else{
    die "$file\n";
}

=old
my $sites=0;
my $depth=0;
my ($F,$O);
open($F,"$samtools depth $file |");
while(<$F>){
    chomp;
    next if(/^\s*$/);
    my @a=split("\t",$_);
    next if $a[2] == 0;
    $sites++;
    $depth+=$a[2];
}
close($F);
my $gc=$sites/$genomeSize;
my $ed=$depth/$genomeSize;

my $aln=0;
open($F, "$samtools view $file |");
while(<$F>){
    chomp;
    next if(/^\@SQ/);
    my @a=split(/\s+/);
    my $flag=$a[1];
    next if($flag & 4);
    next if($flag > 255);
    $aln++;
}
close $F;
=cut

open(my $in, " $samtools view -h $file | ") or die;
open2( my $dp_out, my $dp_in, qq+ $samtools depth - | + .
                            q&perl -a -lne 'BEGIN{$dp=1; $sites=1}
                                                next if $F[2]==0; $sites++; $dp+=$F[2];
                                                END{print "$sites - $dp"} ' & );
open2( my $vi_out ,my $vi_in, q#perl -a -lne 'BEGIN{$aln=1; $all=1}
                                                next if(/^\\@/); $all++; my $flag=$F[1];  next if($flag & 4);
                                                next if($flag > 255); $aln++;
                                                END{print "$aln - $all"} ' #);
binmode($in);
while( read($in, my $buffer, 1024) ) {
    # say $buffer;
    print $dp_in $buffer;
    print $vi_in $buffer;
}
close $dp_in; close $vi_in; close $in;

my $vi_out_result = <$vi_out>; chomp $vi_out_result;
my ($aln, $all_reads) = split( ' - ', $vi_out_result);

#my $aln=<$vi_out>; chomp $aln;

my $dp_out_result = <$dp_out>; chomp $dp_out_result;
my ($sites, $depth) = split( ' - ', $dp_out_result);
my $gc=$sites/$genomeSize;
my $ed=$depth/$genomeSize;


my $O = open_out_fh($outfile);
#open(my $O,'>',"$outfile") or die "$!";
print $O  "#ID\tAllReads\tMappedReads\tMappedPrecent\tCoveredSites\tSumDepth\tGenomeCoverage\tEffectiveDepth\n";
print $O join "\t", $id,$all_reads, $aln, $aln/$all_reads, $sites,$depth,$gc,$ed; print $O "\n";
close $O;
