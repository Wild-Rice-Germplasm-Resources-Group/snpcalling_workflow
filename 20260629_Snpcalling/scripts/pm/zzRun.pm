#!/usr/bin/perl
package zzRun;

use strict;
use warnings;
use MCE::Loop;
use List::Util 'any';
no warnings 'experimental::smartmatch';

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
            zzRun
            zzsystem
        )
    ]
);

@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT    = qw(zzRun zzsystem);


sub zzsystem {
    my @in = @_;
    confess 'arg more than 1' unless scalar @in == 1;
    foreach my $t (@in) {
        #confess "Error! zzsystem with single quote cmds !" if $t=~/'/;
        #$t=~s/'/\\'/g;
    }
    my $shell = '/bin/zsh';
    my @cmd = ($shell, '-c', $in[0]);
    system @cmd;
}


sub zzRun {
    my %opts = @_;
    my $help = <<'EOF';
zzRun usage: zzRun(c=>\@cmds, [t=>1], [m=>'2G'] , [n=>\@nodes], [paralle=>0], [p=>undef])
 p: using parallel rather than srun
 n: Only for parallel, use these nodes with '-S'
 t: threads
EOF
    my $cmds = $opts{c} or confess $help;
    confess $help unless ref $cmds eq 'ARRAY';
    my $num_thread = $opts{t} // 1;
    my $mem = $opts{m} // '2G';
    my $use_parallel = $opts{parallel} // 0;
    my $srun_param = $opts{p} // '';
    my $nodes = $opts{n} // undef;
    my $cmd_count = scalar @$cmds;
    if ($use_parallel==0) {
        #zzRun_srun($cmds, $num_thread, $srun_param);
        zzRun_sbatch_py($cmds, $num_thread, $mem, $srun_param);
    } else {
        $num_thread=$cmd_count+1 if $num_thread > $cmd_count;
        my $cmd = "parallel ";
        if ( defined $nodes ) {
            if (ref($nodes) eq 'ARRAY') {
                $cmd .= "--sshlogin $_ " foreach @$nodes;
            } else {
                confess $help;
            }
        }
        $cmd .= "-j $num_thread";
        my $R;
        ($num_thread==1 and !defined $nodes) ? open($R,"| sh") : open($R,"| $cmd");
        say $R $_ foreach @$cmds;
    }
}

sub zzRun_sbatch_py {
    my ($cmds, $thread, $mem, $param) = @_;
    my $jobs_beforesub = &get_current_jobs();
    #my $cmd_run = "python3 /data/00/slurm.10.buildJob.py -d -c $thread --mem $mem -i - $param ";
    my $cmd_run = "python3 /share/home/yzwl_zhengzy/bin/csub_build_job.py -d -c $thread -i - $param";
    open(my $R, "| $cmd_run");
    say $R $_ foreach @$cmds;
    close $R;
    my $jobs_aftersub = &get_current_jobs();
    my @jobs_sub;
    foreach my $job ( @$jobs_aftersub ) {
        push @jobs_sub, $job unless ( any {$_ eq $job} @$jobs_beforesub );
    }
    &check_sbatch(\@jobs_sub, 5);
}

sub check_sbatch {
    my ($jobs, $wait) = @_;
    my %jobs;
    $jobs{$_}++ foreach @$jobs;
    while (1) {
        my $jobs_current= &get_current_jobs();
        my @k = keys %jobs;
        foreach my $job (@k) {
            delete $jobs{$job} unless ( any{$_ eq $job} @$jobs_current);
        }
        return unless %jobs;
    }
}

sub prase_jobs_aip {
    my ($ret) = @_;
    my @job_ids;
    foreach my $line (@$ret) {
        chomp $line;
        my @F = split(/\s+/, $line);
        next if $F[0] eq 'JOBID';
        push @job_ids, $F[0];
    }
    return \@job_ids;
}

sub get_current_jobs {
    my $user = $ENV{USER};
    #my $cmd = "squeue -o '%A' -h -u $user";
    my $cmd = "aip job info -u $user --status run";
    my @ret = `$cmd`;
    chomp @ret;
    #return \@ret;
    return &prase_jobs_aip(\@ret);
}

sub zzRun_srun {
    my ($cmds, $thread, $param) = @_;
    #my $cmd_run = "srun $param sh";
    my $cmd_run = "csub $param sh";
    MCE::Loop::init {max_workers =>$thread, chunk_size =>1};
    #foreach (@$cmds) {
    mce_loop {
        my $cmd = $_;
        open(my $R, "| $cmd_run");
        say $R $cmd;
        close $R;
    } (@$cmds);
}

1;
