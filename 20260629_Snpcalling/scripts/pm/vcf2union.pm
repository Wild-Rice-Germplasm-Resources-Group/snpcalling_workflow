#
#===============================================================================
#
#         FILE: vcf2union.pm
#
#  DESCRIPTION: 
#
#        FILES: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Zeyu Zheng (LZU), zhengzy2014@lzu.edu.cn
# ORGANIZATION: 
#      VERSION: 1.0
#      CREATED: 12/01/2021 11:10:49 PM
#     REVISION: ---
#===============================================================================

package vcf2union;
use v5.24;
use strict;
use warnings;
use Coro::Generator;
use MCE::Flow;
use MCE::Channel;
use MCE::Candy;
use prase_vcf qw/find_union/;
use zzIO;
use List::Util qw/max min/;
use Carp;
use Data::Dumper;

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
            get_unions
        )
    ]
);

@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT    = qw(get_unions);


sub new {
    my ($class, $args) = @_;
    die unless $$args{vcf};
    die unless $$args{out_union};
    $$args{threads} //= $main::threads;
    $$args{debug} //= $main::debug;
    $$args{verb} //= $main::verb;
    $$args{force} //= 0;
    my $self={
            %$args,
    };
    #die Dumper $self;
    bless($self, $class || ref($class));
    return $self;
}

our $I_VCF;


sub get_unions {
    my ($self) = @_;
    my $vcf = $self->{vcf};
    my $out_union = $self->{out_union};
    my $I_VCF = open_in_fh($vcf);
    $self->{I_VCF} = $I_VCF;
    my $union_flag_file = "$out_union.ok";

    $self->{queue_vcf2union} = MCE::Channel->new( impl => 'Mutex', mp => 0 );
    if ($$self{force}==1 or !-e $union_flag_file) {
        say STDERR "Will cal union";
        $self->{queue_union_save} = MCE::Channel->new( impl => 'Mutex', mp => 1 );
        $self->{O_UNION} = open_out_fh($out_union);
    } else {
        my $unions = load_unions($out_union);
        $self->{unions} = $unions;
        return($unions);
    }
    $self->{queue_for_cal_identity} = MCE::Channel->new( impl => 'Mutex', mp => 0 );

    MCE::Flow->init(
        chunk_size => 1,
        max_workers => [ 1, $main::threads, 1 ],
        task_name => [ 'vcf_reader', 'cal_unions', 'save_unions' ],
        #gather => preserve_order(\@a),
        #gather => MCE::Candy::out_iter_fh( $self->{O_UNION} ),
        task_end  => sub {
            my ($mce, $task_id, $task_name) = @_;
            if ($task_name eq 'cal_unions') {
                `touch $union_flag_file` ;
                $$self{queue_union_save}->end() if $$self{queue_union_save};
                $$self{queue_for_cal_identity}->end();
            }
        }
    );
    mce_flow $self->vcf_reader_producer, $self->cal_unions_producer, $self->save_unions;
    MCE::Flow->finish;
    my $unions = load_unions($out_union);
    #die Dumper $unions;
    # [ [$chr, $min_start, $max_end, \@svids] ]
    $self->{unions} = $unions;
    return($unions);
}


sub cal_identity_2seq {
    my ($seq1, $seq2, $temp_prefile) = @_;
    my $stretcher = $main::stretcher;
    my $stretcher_parm = $main::stretcher_parm;
    my $len1 = length($seq1);
    my $len2 = length($seq2);
    unless ($seq1 and $seq2) {
        return 0;
    }
    my $max_len_diff = 0.5 * max($len1,$len2);
    if ( abs($len2-$len1)<$max_len_diff ) {
        return 0;
    }
    my $tempf1 = "$temp_prefile.1.seq";
    my $tempf2 = "$temp_prefile.2.seq";
    my $O1 = open_out_fh($tempf1);
    say $O1 $seq1;
    close $O1;
    my $O2 = open_out_fh($tempf2);
    say $O2 $seq2;
    close $O2;
    open(my $C, "$stretcher -asequence $tempf1 -bsequence $tempf2 $stretcher_parm |");
    while(<$C>) {
        chomp;
        if ($_=~m`#\s+Identity:\s+(\d+)/(\d+)`) {
            my $identiy = $1/$2;
            close $C;
            unlink $tempf1;
            unlink $tempf2;
            if ($identiy>0.5) {
                return 1;
            } else {
                return 0;
            }
        }
    }
    close $C;
    unlink $tempf1;
    unlink $tempf2;
    die;
}

sub cal_identity_new {
    my ($seqs, $temp_prefile) = @_;
    my $stretcher = $main::stretcher;
    my $stretcher_parm = $main::stretcher_parm;

    my @ids = sort keys %$seqs;
    my $len = scalar(@ids) - 1;
    my %ret;
    #return {"@ids"=>-1} if length( $$seqs{$ids[0]} ) > 1000; ######## DEBUG
    my @groups;
    my %ingroup;
    foreach my $i1 (0..$len) {
        next if exists $ingroup{$i1};
        my $id1 = $ids[$i1];
        my $seq1 = $$seqs{$id1};
        foreach my $i2 (0..$len) {
            next if $i2<=$i1;
            next if exists $ingroup{$i2};
            my $id2 = $ids[$i2];
            my $seq2 = $$seqs{$id2};
            my $is_same = &cal_identity_2seq($seq1, $seq2, "$temp_prefile.$i1.$i2");
            if ($is_same == 1) {
                &add_group(\@groups, $i1, $i2);
                $ingroup{$i1}++;
                $ingroup{$i2}++;
            }
        }
    }
    for my $i (0..$len) {
        next if exists $ingroup{$i};
        push @groups, [$i];
    }
    my @ret;
    foreach my $igroup (0..$#groups) {
        foreach my $i ($groups[$igroup]->@*) {
            my $id = $ids[$i];
            push $ret[$igroup]->@*, $id;
        }
    }
    return \@ret;
}

sub add_group {
    my ($groups, $i1, $i2);
    my $group_imax = scalar(@$groups);
    if ($group_imax == 0) {
        push @$groups, [$i1, $i2];
        return;
    }
    $group_imax -= 1;
    foreach my $igroup (0..$group_imax) {
        if ($i1 ~~ $$groups[$igroup]->@*) {
            push $$groups[$igroup]->@*, $i2;
            return;
        }
    }
    push @$groups, [$i1, $i2];
}

sub cal_identity_from_lines {
    my ($lines, $temp_prefile) = @_;
    my %ref_alt_seqs;
    foreach my $svid (keys %$lines) {
        my $line = $$lines{$svid};
        my @F = split(/\t/, $line);
        my ($chr, $pos, $ref_seq, $alts_seq) = @F[0,1,3,4];
        my @ref_alt_seqs = ( $ref_seq, split(/,/, $alts_seq) );
        foreach my $i (0..$#ref_alt_seqs) {
            $ref_alt_seqs{"$svid:$i"} = $ref_alt_seqs[$i];
        }
    }
    my $groups = &cal_identity_new(\%ref_alt_seqs,  $temp_prefile);
    return $groups;
}


sub save_unions {
    my ($self) = @_;
    my $O_UNION = $self->{O_UNION};
    my $queue_union_save = $self->{queue_union_save};
    return sub {
        return unless defined $queue_union_save;
        #say STDERR "start ";
        while ( my ( $parms ) = $queue_union_save->dequeue() ) {
            #say STDERR "?? " . Dumper $parms;
            my ($chunk_id, $results) = @$parms;
            foreach my $result (@$results) {
                #say STDERR join "\t", @$result;
                say $O_UNION join "\t", @$result;
            }
        }
        close $O_UNION;
    }
}

sub load_unions {
    my ($file) = @_;
    my $I = open_in_fh($file);
    my @unions;
    while(<$I>) {
        chomp;
        next unless $_;
        next if /^#/;
        my ($chr, $min_start, $max_end, @svids) = split(/\t/);
        push @unions, [$chr, $min_start, $max_end, \@svids];
    }
    return \@unions;
}


sub cal_unions_producer {
    my ($self) = @_;
    my $queue_vcf2union = $$self{queue_vcf2union} // undef;
    my $queue_union_save = $$self{queue_union_save} // undef;
    my $queue_for_cal_identity = $self->{queue_for_cal_identity} // undef;
    if (! defined $queue_union_save) { # union already cal;
        die "$$self{out_union} not exists " unless -s $self->{out_union};
        if ( !exists $$self{union_precal} ) {
            say STDERR exists $$self{union_precal} ? "!!" : "??";
            $$self{union_precal} = &load_unions($self->{out_union}) unless exists $$self{union_precal};
        }
    }
    return sub {
        while ( my ( $parms ) = $queue_vcf2union->dequeue() ) {
            my ($chunk_id, $svs) = @$parms;
            last unless ($svs and %$svs);
            unless ($queue_union_save) {
                my $results = &find_union_precal($svs, $$self{union_precal});
                $queue_for_cal_identity->enqueue([$chunk_id, $results, $svs]);
                next;
            }
            my $pos2svid = &cal_pos2svid($svs);
            #say STDERR "pos2svid: " . Dumper $pos2svid;
            #say STDERR "svid2svid: " . Dumper $svid2svid;
            #say STDERR "svs: " . Dumper $svs;
            my ($svid) = %$svs;
            my $chr = $$svs{$svid}[4];
            if ($chunk_id % 1000==0) {
                my $pos = $$svs{$svid}[0];
                say STDERR "Now: $chr:$pos";#, svids: ", join ',', sort {$a<=>$b} keys %$svs;
                say STDERR "svids: ", join ',', sort {$a<=>$b} keys %$svs if ($main::verb==1 or $main::debug==1);
            }
            my $unions = &find_union($svs, $pos2svid, $chr);
            #die Dumper $unions;

            my @results;
            foreach my $union (@$unions) {
                my ($svids, $min_start, $max_end) = @$union;
                push @results, [$chr, $min_start, $max_end, @$svids];
            }
            if (@results) {
                #say STDERR "results: " . Dumper \@results;
                $queue_union_save->enqueue([$chunk_id, \@results]);
                #$queue_for_cal_identity->enqueue([$chunk_id, \@results, $svs]);
            } else {
                # do nothing
            }
        }

    }
}

sub find_union_precal {
    my ($svs, $unions_precal) = @_;
    my %svids;
    $svids{$_}++ foreach sort keys %$svs;
    my @ret;
    A1:foreach my $union (@$unions_precal) {
        foreach my $svid ( $$union[3]->@* ) {
            push @ret, $union if exists $svids{$svid};
        }
    }
    return \@ret;
}



sub cal_pos2svid {
    my ($svs) = @_;
    my %pos2svid;
    foreach my $svid (sort keys %$svs) {
        my ($pos, $maxlen, $ref_len, $alt_max_len, $chr) = $$svs{$svid}->@*;
        my ($min_pos, $max_pos);
        my $max_diff_pos_percent = $main::max_diff_pos_percent;
        if ($max_diff_pos_percent>0 and $max_diff_pos_percent<1) {
            $min_pos = $pos - $maxlen * $max_diff_pos_percent;
            $max_pos = $pos + $maxlen * $max_diff_pos_percent + $maxlen;
        } elsif ($max_diff_pos_percent>=1) {
            $min_pos = $pos - $max_diff_pos_percent;
            $max_pos = $pos + $max_diff_pos_percent + $maxlen;
        } else {
            die;
        }
        my $this_chr_len = $main::ref_seqs_len->{$chr};
        $min_pos = 1 if $min_pos < 1;
        $max_pos = $this_chr_len-1 if $max_pos > $this_chr_len-1;
        for (my $i=int($min_pos); $i<$max_pos; $i++) {
            push $pos2svid{$i}->@*, $svid;
        }
    }
    return(\%pos2svid);
}










sub vcf_reader_producer {
    my ($self) = @_;
    my $queue_vcf2union = $self->{queue_vcf2union};
    my $I = $$self{I_VCF};
    my $iline=1;
    my %svs=();
    my $max_end;
    my $chr_old;
    return sub {
        while (<$I>) {
            chomp;
            next unless $_;
            next if /^#/;
            my ($chr, $pos, undef, $ref_seq, $alt_seqs) = split(/\t/, $_);
            $chr_old = $chr unless defined $chr_old;
            my $svid = $.;
            # my $svid = "$chr:$pos"; # may not unique
            my @alt_seqs = split(/,/, $alt_seqs);
            my $ref_len = length($ref_seq);
            my $alt_max_len = -1;
            foreach my $alt_seq ( @alt_seqs ) {
                my $len = length($alt_seq);
                $alt_max_len = $len if ($len > $alt_max_len);
            }

            my $maxlen = max($alt_max_len, $ref_len);
            next if $maxlen < $main::min_sv_len;
            my $end = $pos + $maxlen * $main::max_diff_pos_percent; # not consider '*'
            $max_end = $end unless defined $max_end;
            if ($chr_old ne $chr or $max_end + 3 < $pos) {
                $queue_vcf2union->enqueue([$iline, \%svs]);
                $iline++;
                $max_end = $pos;
                $chr_old = $chr;
                %svs=();
                redo;
            }
            $max_end = $end if $end > $max_end;
            $svs{$svid} = [$pos, $maxlen, $ref_len, $alt_max_len, $chr, [ $ref_seq, @alt_seqs] ];
            #die Dumper \%svs;
        }
        say "!!!";
        $queue_vcf2union->enqueue([$iline, \%svs]) if %svs;
        $queue_vcf2union->end();
    }
}




=old
sub cal_identity {
    my ($seqs, $temp_prefile) = @_;
    my $stretcher = $main::stretcher;
    my $stretcher_parm = $main::stretcher_parm;

    my @ids = sort keys %$seqs;
    my $len = scalar(@ids) - 1;
    my %ret;
    #return {"@ids"=>-1} if length( $$seqs{$ids[0]} ) > 1000; ######## DEBUG
    foreach my $i1 (0..$len) {
        my $id1 = $ids[$i1];
        my $seq1 = $$seqs{$id1};
        my $len1 = length($seq1);
        my $tempf1 = "$temp_prefile.zpan.t$i1";
        my $O1 = open_out_fh($tempf1);
        say $O1 $seq1;
        close $O1;
        foreach my $i2 (0..$len) {
            my $tempf2 = "$temp_prefile.zpan.t$i2";
            next if $i2<=$i1;
            my $id2 = $ids[$i2];
            my $seq2 = $$seqs{$id2};
            my $max_len_diff = 0.5 * max($len1,$len2);
            #$max_len_diff = 10 if $max_len_diff<10;
            my $len2 = length($seq2);
            #say STDERR "get_identity2 : $id1 $id2";
            my $O2 = open_out_fh($tempf2);
            say $O2 $seq2;
            close $O2;
            if ($seq1 and $seq2) {
                if ( abs($len2-$len1)<$max_len_diff ) {
                    open(my $C, "$stretcher -asequence $tempf1 -bsequence $tempf2 $stretcher_parm |");
                    while(<$C>) {
                        chomp;
                        if ($_=~m`#\s+Identity:\s+(\d+)/(\d+)`) {
                            my $identiy = $1/$2;
                            $ret{"$id1&$id2"} = $identiy;
                            last;
                        }
                    }
                    die unless defined $ret{"$id1&$id2"};
                    close $C;
                } else {
                    $ret{"$id1:$id2"} = 0;
                }
            } elsif ($seq1 eq '' and $seq2 eq '') {
                say STDERR "WARN: seq for $id1 and $id2 Both empty, identity set to 1";
                $ret{"$id1&$id2"} = 1;
            } else {
                say STDERR "WARN: seq for $id1 or $id2 is empty! identity set to 0";
                $ret{"$id1&$id2"} = 0;
            }
            unlink $tempf2;
        }
        unlink $tempf1;
    }
    return \%ret;
}
=cut


1;

