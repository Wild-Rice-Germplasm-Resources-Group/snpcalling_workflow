zzsra="ERR13765380"
proxychains4 perl -Mzz_SRA_download -e "zz_SRA_download('.', '$zzsra')"
~/software/sratoolkit/sratoolkit.3.2.1-ubuntu64/bin/fasterq-dump --threads 80 --progress --temp /dev/shm $zzsra.sra
pigz -p88 ${zzsra}_1.fastq
pigz -p88 ${zzsra}_2.fastq

