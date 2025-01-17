rule fastp:
    input:
        sample=["results/reads/{sample}_1.fastq.gz", "results/reads/{sample}_2.fastq.gz"]
    output:
        trimmed=["results/reads/trimmed/{sample}_1.fastq.gz", "results/reads/trimmed/{sample}_2.fastq.gz"],
        html="results/fastp_reports/{sample}.html",
        json="results/fastp_reports/{sample}.json",
    log:
        "logs/fastp/{sample}.log"
    threads: 4
    wrapper:
        "v1.25.0/bio/fastp"

rule multiQC:
    input:
        expand("results/fastp_reports/{sample}.html", sample=samples),
        expand("results/fastp_reports/{sample}.json", sample=samples),
        expand("results/alignments/bamStats/{sample}.flagstat", sample=samples),
        expand("results/coverage/{sample}.per-base.bed.gz", sample=samples),
        expand("results/wholegenome/coverage/windowed/{sample}.regions.bed.gz", sample=samples),
        expand("results/vcfs/stats/{dataset}.merged.vcf.txt", dataset=dataset)
    output:
        "results/multiqc/multiqc_report.html"
    log:
        "logs/multiqc/multiqc.log"
    wrapper:
        "v1.25.0/bio/multiqc"

rule targetedCoverage:
  """
  Target per-base coverage with mosdepth
  """
    input:
        bam="results/alignments/{sample}.bam",
        idx="results/alignments/{sample}.bam.bai"
    output:
        "results/coverage/{sample}.per-base.bed.gz"
    log:
        "logs/coverage/{sample}.log"
    threads:4
    conda:
        "../envs/AmpSeeker-cli.yaml"
    params:
        prefix="results/coverage/{sample}",
        regions = config['bed']
    shell:
        """
        mosdepth {params.prefix} {input.bam} --by {params.regions} --fast-mode --threads {threads} 2> {log}
        """

rule windowedCoverage:
  """
  300 bp windowed coverage with mosdepth
  """
    input:
        bam="results/alignments/{sample}.bam",
        idx="results/alignments/{sample}.bam.bai"
    output:
        "results/wholegenome/coverage/windowed/{sample}.regions.bed.gz"
    log:
        "logs/coverage/windowed_{sample}_wholegenome.log"
    conda:
        "../envs/AmpSeeker-cli.yaml"
    threads:4
    params:
        prefix="results/wholegenome/coverage/windowed/{sample}",
    shell:
        """
        mosdepth {params.prefix} {input.bam} --by 300 -n --fast-mode --threads {threads} 2> {log}
        """

rule BamStats:
  """
  Calculate mapping statistics with samtools flagstat
  """
    input:
        bam = "results/alignments/{sample}.bam",
        idx = "results/alignments/{sample}.bam.bai"
    output:
        stats = "results/alignments/bamStats/{sample}.flagstat"
    conda:
        "../envs/AmpSeeker-cli.yaml"
    log:
        "logs/BamStats/{sample}.log"
    shell:
        """
        samtools flagstat {input.bam} > {output} 2> {log}
        """

# qualimap analysis for alignment QC 
rule qualimap:
    input:
        bam="results/alignments/{sample}.bam",
    output:
        directory("results/qualimap/{sample}"),
    log:
        "logs/qualimap/bamqc/{sample}.log",
    wrapper:
        "v1.25.0/bio/qualimap/bamqc"

rule vcfStats:
    input:
        vcf = "results/vcfs/{dataset}.merged.vcf"
    output:
        stats = "results/vcfs/stats/{dataset}.merged.vcf.txt"
    log:
        "logs/vcfStats/{dataset}.log"
    conda:
        "../envs/AmpSeeker-cli.yaml"
    shell:
        """
        bcftools stats {input.vcf} > {output.stats} 2> {log}
        """