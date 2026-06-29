#
#===============================================================================
#
#         FILE: tabix_vcf.pm
#
#  DESCRIPTION: 
#
#        FILES: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Zeyu Zheng (LZU), zhengzy2014@lzu.edu.cn
# ORGANIZATION: 
#      VERSION: 1.0
#      CREATED: 12/08/2021 03:45:19 PM
#     REVISION: ---
#===============================================================================

package tabix_vcf;
use strict;
use warnings;
use v5.24;
use Bio::SeqIO;
use zzIO;
use List::Util qw/max min/;
use File::Basename;
use MCE::Loop;

require Exporter;

use vars qw(
  @ISA
  %EXPORT_TAGS
  @EXPORT_OK
  @EXPORT
);

@ISA = qw(Exporter);

%EXPORT_TAGS = (
    'all' => [
        qw(
            read_vcfs_chrs
        )
    ]
);

@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT    = qw(read_vcfs_chrs);


sub read_vcfs_chrs {
    my ($files, $threads) = @_;
    MCE::Loop->init(
        max_workers => $threads, chunk_size => 1
    );
    my %sid2chrs = mce_loop {
    #foreach  (sort keys %$files) {
        my $sid = $_;
        my $chrs_now = &_read_vcf_chrs($files);
        MCE->gather($sid, $chrs_now);
        # $sid2chrs{$sid} = $chrs_now;
    } (sort keys %$files);
    MCE::Loop->finish;
    my %chrs;
    foreach my $sid (sort keys %sid2chrs) {
        foreach my $chr (@{$sid2chrs{$sid}}) {
            my $len = $sid2chrs{$sid}{$chr};
            if (my $len_old = $chrs{$chr}) {
                die if $len_old ne $len;
            } else {
                $chrs{$chr} = $len;
            }
        }
    }
    return(\%chrs);
}

sub read_vcfs_one_chr {
    my ($files, $chr, $min_dp, $threads) = @_;
    MCE::Loop->init(
        max_workers => $threads, chunk_size => 1
    );
    my %ret = mce_loop {
    #foreach my $id (sort keys %$files) {
        my $id = $_;
        my $file = $files->{$id};
        my %temp;
        open(my $I, "tabix $file '$chr' |");
        while (<$I>) {
            chomp;
            next unless $_;
            my @F = split(/\t/, $_);
            my $chr = $F[0];
            my $pos = $F[1];
            my @ref_alts = ($F[3], split(/,/, $F[4]));
            $F[7] =~ /DP=(\d+)/ or die;
            my $dp = $1;
            if ($dp < $min_dp) {
                # treated as miss
                $temp{$pos} = undef;
            } else {
                $F[9]=~m#^(\d+)[/|](\d+)# or die;
                $temp{$pos} = [ $ref_alts[$1],  $ref_alts[$2] ];
            }
        }
        MCE->gather($id, \%temp);
        #$ret{$id} = \%temp;
    } (sort keys %$files);
    MCE::Loop->finish;
    return \%ret;
}

sub _read_vcf_chrs {
    my ($file) = @_;
    my %ret;
    open(my $I, "tabix -H $file |");
    while(<$I>) {
        chomp;
        next unless $_;
        next unless /^##contig=<ID=(.+),length=(\s+)>$/;
        my ($chr, $len) = ($1, $2);
        $ret{$chr} = $len;
    }
    return \%ret;
}
