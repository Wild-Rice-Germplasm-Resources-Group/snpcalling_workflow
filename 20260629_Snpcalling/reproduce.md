# SNP calling 流程复现说明

## 1. 脚本与文件放置位置

复现流程时，`scripts/` 中的脚本或文件应放到以下目录：

| 文件/目录 | 放置位置 |
|---|---|
| Snakefile | `/share/appspace_data/shared_groups/caas_zhengxm04_share_software/public_pipeline/snp_calling_lsf/` |
| profiles | `/share/appspace_data/shared_groups/caas_zhengxm04_share_software/public_pipeline/snp_calling_lsf/` |
| pl | `/share/appspace_data/shared_groups/caas_zhengxm04_share_software/bin/` |
| pm | `/share/appspace_data/shared_groups/caas_zhengxm04_share_software/bin/` |

## 2. 环境

```bash
mma snp_calling_py311
```

## 3. 准备文件

需要准备以下两个文件：

```text
config.yaml
samples.tsv
```

## 4. 如果文件来自 Windows，先去掉换行符

```bash
sed -i 's/\r$//' samples.tsv
```

## 5. 检查 FASTQ 是否存在

```bash
while IFS=$'\t' read -r sid r1 r2; do
    [[ -f "$r1" ]] || echo "缺少 R1: $sid $r1"
    [[ -f "$r2" ]] || echo "缺少 R2: $sid $r2"
done < samples.tsv
```

没有输出说明路径正常。

## 6. 测试运行命令

```bash
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
```

其中：

```bash
-n -p
```

表示只进行 dry-run 测试，不正式提交任务。

## 7. 正式运行命令

```bash
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
```

注意：

```bash
--jobs 30
```

表示允许同时提交 30 个任务到集群。