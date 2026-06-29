#zzVCF:
my $vcf_obj = new zzVCF($vcf_file);
$vcf_obj->get_id_count;
$vcf_obj->get_ids; #\@array
$vcf_obj->get_header; #\@array
$vcf_obj->get_commits; #\@array without \n and header
while($vcf_obj->next_pos) {}

#zzVCF::line:
my $line_obj = $vcf_obj->next_pos;
# my $line_obj = new zzVCF::line(line=>$line);
$line_obj->get_line;
$line_obj->get_split;
$line_obj->get_chr; #0
$line_obj->get_pos; #1
$line_obj->get_id; #2
$line_obj->get_ref; #3
$line_obj->get_alts; #4 #\@array
$line_obj->get_qual; #5
$line_obj->get_filter; #6
$line_obj->get_pos_info; #7 #\%hash=(DP=>30);
$line_obj->get_id_info_format; #8 #\@array
$line_obj->get_id_info; #9 #\@array #$array[0]=\%hash=\(SB=>'3/4');
$line_obj->get_alleles; #9 #\@array #$array[0]=\@array $array[0]=(0,1);

set....

$line_obj->get_fix_line;


zzIO:
my $fh = open_in_fh(file);
my $fh = open_out_fh(file);


zzRun:
zzRun(\@nodes,$num_thread,\@cmds);


zzSTAT:
my $stat = new zzSTAT(30, \$chr, \$pos); # interval, \$item1, \$item2
$stat->start;
$stat->stop;


zzReadRefdict:
my %ref_chr2len = zzReadRefdict($ref_file); # $hash{$chr}=$len;


zzToolkit:
#t_test();
my @list = read_list($file);


