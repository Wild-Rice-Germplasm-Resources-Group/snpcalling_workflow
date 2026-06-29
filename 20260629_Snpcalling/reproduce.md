 #复现流程时，scripts/中的脚本/文件应放到以下目录
Snakefile	/share/appspace_data/shared_groups/caas_zhengxm04_share_software/public_pipeline/snp_calling_lsf/
profiles	/share/appspace_data/shared_groups/caas_zhengxm04_share_software/public_pipeline/snp_calling_lsf/
pl	/share/appspace_data/shared_groups/caas_zhengxm04_share_software/bin/
pm	/share/appspace_data/shared_groups/caas_zhengxm04_share_software/bin/

 #环境 mma snp_calling_py311
 
 #准备文件：config.yaml,samples.tsv
 
 
 #如果文件来自 Windows，先去掉换行符
sed -i 's/\r$//' samples.tsv

 #检查 FASTQ 是否存在
while IFS=$'\t' read -r sid r1 r2; do
    [[ -f "$r1" ]] || echo "缺少 R1: $sid $r1"
    [[ -f "$r2" ]] || echo "缺少 R2: $sid $r2"
done < samples.tsv
 #没有输出说明路径正常。

 
 #测试运行命令
snp_calling_lsf \
  --configfile config.yaml \
  --set-threads \
    filter_fq=4 \
    bwa_mem=32 \
    gen_gc_stat=1 \
    callSNP_gatk4=2 \
    CombineGVCFs=2 \
    GenotypeGVCFs=2 \
    split_snp_indel=2 \
    filter_vcf_snps_indels=4 \
    merge_vcf=2 \
  --rerun-incomplete \
  -n -p
  
 #正式运行命令
snp_calling_lsf \
  --configfile config.yaml \
  --jobs 30 \
  --set-threads \
    filter_fq=8 \
    bwa_mem=32 \
    gen_gc_stat=1 \
    callSNP_gatk4=4 \
    CombineGVCFs=2 \
    GenotypeGVCFs=2 \
    split_snp_indel=4 \
    filter_vcf_snps_indels=8 \
    merge_vcf=4 \
  --rerun-incomplete
 #注意：
--jobs 30 \
 #此处设置了允许同时提交30个任务到集群