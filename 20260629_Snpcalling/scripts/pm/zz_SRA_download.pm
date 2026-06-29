#!/usr/bin/env perl
#!/usr/bin/perl
package zz_SRA_download;

#use strict;
#use warnings;

require Exporter;
use Carp;
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
            zz_SRA_download
        )
    ]
);

@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT    = qw(zz_SRA_download );




sub zz_SRA_download {
    my $aria2c = '/share/org/YZWL/yzwl_zhengzy/built/bin/aria2c';
    my $prefetch = '/share/org/YZWL/yzwl_zhengzy/software/sratoolkit/sratoolkit.3.2.1-ubuntu64/bin/prefetch';
    #my $prefetch = '/data/00/software/SRAtoolkit/sratoolkit.3.0.2-centos_linux64/bin/prefetch';
    #my $prefetch = '/data/00/user/user101/software/sratoolkit.2.9.6-1-centos_linux64/bin/prefetch';
    #my $ascp_path = '/data/00/user/user101/.aspera/connect/bin/ascp|/data/00/user/user101/.aspera/connect/etc/asperaweb_id_dsa.openssh';
    my $ascp_path = 'singularity exec -B /share --cleanenv ~/software/singularity/ubuntu ~/.aspera/connect/bin/ascp';
    my $verb = 0;

    my ($out_dir, @sras) = @_;
    $out_dir //= '/share/home/yzwl_zhengzy/ncbi/public/sra/';
    die "zz_SRA_download usage: zz_SRA_download('out_dir','SRA1','SRA2' ...) " unless @sras;
    die "can not use '~' in zz_SRA_download() " if $out_dir =~ /~/;
    my @ret;
    foreach my $sra (@sras) {
        # SRR5861725
        my $out_file = "$out_dir/$sra.sra";
        push @ret, $out_file;
        my $err_file = "$out_file.download.err";
        my $cmd6 = qq+ $prefetch --max-size 1024G -o $out_file -vvv -f all $sra +;
        #my $cmd6 = qq+ $prefetch --ascp-path '$ascp_path' --max-size 1024G -o $out_file -vvv -f all $sra +;
        # --output-directory ?  --output-directory $out_dir
        #die $cmd6;
        if (-e $out_file and ! -e $err_file and ! -e "$out_file.aria2") {
            print STDERR "pass download $sra in $out_dir \n";
            next;
        } else {
            print STDERR "SRA need to download! : $out_file \n" if $verb;
            #die;
        }
        print STDERR "downloading $sra to $out_dir \n";
        `date >> $err_file`;
        `rm -f $out_file.lock`;
        my $DL_PID = open(my $DL , "$cmd6  2>&1  | tee $err_file |") ;
        my $not_ascp = 0;
        my $http_web;
        while(my $l = <$DL>) {
            print "$l\n" if $verb;
            if ($l=~/Downloading via HTTP/) {
            #if ($l=~/Downloading via http[s]/) {
                $not_ascp++;
            } elsif($l=~/failed to open file for (http\S+)/) {
                $http_web = $1;
                close $DL;
                kill(9, $DL_PID);
                print  "http: $http_web\n" if $verb;
                last;
            }elsif($not_ascp>0 and $l=~/(http[s]:\S+)\s+->/) {
                $http_web = $1;
                close $DL;
                kill(9, $DL_PID);
                print  "http: $http_web\n" if $verb;
                last;
            } elsif($not_ascp>0) {
                #print "??????????\n";
                #die $l;
            }
        }
        close $DL;
        my $ret = 0;# zzsystem("$cmd6 2>&1 | tee $err_file");
        if ($not_ascp) {
            die unless defined $http_web;
            #$http_web =~ s/sra-downloadb.be-md.ncbi.nlm.nih.gov/sra-download.ncbi.nlm.nih.gov/; # fast_mirror
            print STDERR "cleaning prefetch files\n" if $verb;
            `rm -f $out_dir/$sra.sra.tmp.*.tmp`;
            `rm -f $out_dir/$sra.sra.lock`;
            print STDERR "https fetching using aria2c: $http_web\n";
            my $cmd5 = qq+ $aria2c --split=16 --max-concurrent-downloads=16 --min-split-size=10M --continue=true --max-connection-per-server=16 --out=$sra.sra --dir=$out_dir '$http_web'+; #  --file-allocation=falloc --lowest-speed-limit=20K
            print STDERR "$cmd5\n" if $verb;
            #die $cmd5;
            #$ret = system("$cmd5 > $err_file 2>&1 ");
            open(my $L, ">> $err_file") or die;
            open(my $P, "$cmd5 2>&1 |");
            while(<$P>) {
                print STDERR $_;
                print $L $_;
            }
            $ret = $?;
        } else {
            #die "??";
        }
        if ($ret==0) {
            unlink $err_file;
        } else {
            print STDERR "Download fail !! \n";
            `echo -n 'err!  code=$ret  ' >> $err_file`;
            `date >> $err_file`;
        }
    }
    return @ret;
}
