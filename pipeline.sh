#!/bin/bash

# -----------------------------
# Directories
# -----------------------------
BASE=/bp1/mrcieu1/data/UKB-PPP/UKB-PPP_pGWAS_summary_statistics/European_discovery
OUT=/user/work/vc23656/proteins
TMP=$OUT/tmp
GENE_TSS=/user/work/vc23656/proteins/gene_tss_hg38.tsv

mkdir -p "$OUT"
mkdir -p "$TMP"

LOG=$OUT/run_serial_noclust.log
echo "Started $(date)" > "$LOG"

# -----------------------------
# Output CSV
# -----------------------------
BATCH=10
COUNT=0
PART=1
OUTFILE=$OUT/cis_pqtl_instruments_part_${PART}.csv
echo "protein,CHROM,GENPOS,ID,ALLELE0,ALLELE1,A1FREQ,BETA,SE,LOG10P,P" > "$OUTFILE"

# -----------------------------
# Loop over protein tarballs
# -----------------------------
for TAR in $BASE/*.tar; do

    PROT=$(basename "$TAR" .tar)
    GENE=$(echo "$PROT" | cut -d '_' -f1)

    echo "Processing $PROT (gene $GENE)" | tee -a "$LOG"

    # Lookup gene TSS — take only the first transcript
    LOOKUP=$(grep -w "^$GENE" "$GENE_TSS" | head -n1)

    if [[ -z "$LOOKUP" ]]; then
        echo "  Gene not found in TSS table: $GENE" | tee -a "$LOG"
        continue
    fi

    # Extract chromosome and TSS safely
    CHR=$(echo "$LOOKUP" | awk '{print $2}' | tr -d '\r' | sed 's/chr//')
    TSS=$(echo "$LOOKUP" | awk '{print $3}' | tr -d '\r' | awk '{print int($1)}')

    # Map numeric sex chromosomes if needed
    [[ "$CHR" == "23" ]] && CHR="X"
    [[ "$CHR" == "24" ]] && CHR="Y"

    # Define cis window ±500 kb
    START=$((TSS-500000))
    END=$((TSS+500000))
    (( START < 0 )) && START=0

    # Temp GWAS cis file
    GWAS=$TMP/${PROT}_cis.txt

    # -----------------------------
    # Extract cis region directly from tar
    # -----------------------------
    CHRFILE=$(tar -tf "$TAR" | grep -E "discovery_chr${CHR}_")
    if [[ -z "$CHRFILE" ]]; then
        echo "  Chromosome file not found for $PROT (chr $CHR)" | tee -a "$LOG"
        continue
    fi

    tar -xOf "$TAR" "$CHRFILE" | gunzip -c | \
    awk -v chr="$CHR" -v start="$START" -v end="$END" '
    BEGIN{OFS="\t"}
    NR==1{print $1,$2,$3,$4,$5,$6,$9,$10,$11,$13}
    NR>1 && $1==chr && $2>=start && $2<=end{print $1,$2,$3,$4,$5,$6,$9,$10,$11,$13}
    ' > "$GWAS"

    # -----------------------------
    # Add P column
    # -----------------------------
    awk 'NR==1{print $0,"\tP"} NR>1{p=10^(-$10); print $0,p}' OFS="\t" "$GWAS" > "$TMP/gwas_p.txt"

    # -----------------------------
    # Filter by p-value (default 5e-8)
    # -----------------------------
    awk -v prot="$PROT" 'NR==1{print "protein,CHROM,GENPOS,ID,ALLELE0,ALLELE1,A1FREQ,BETA,SE,LOG10P,P"} 
        NR>1 && $11 < 5e-8 {OFS=","; print prot,$1,$2,$3,$4,$5,$6,$7,$8,$9,$11}' "$TMP/gwas_p.txt" >> "$OUTFILE"

    # Cleanup
    rm -f "$GWAS" "$TMP/gwas_p.txt"

    # -----------------------------
    # Checkpoint every BATCH proteins
    # -----------------------------
    COUNT=$((COUNT+1))
    if (( COUNT % BATCH == 0 )); then
        PART=$((PART+1))
        OUTFILE=$OUT/cis_pqtl_instruments_part_${PART}.csv
        echo "protein,CHROM,GENPOS,ID,ALLELE0,ALLELE1,A1FREQ,BETA,SE,LOG10P,P" > "$OUTFILE"
    fi

done

echo "Finished $(date)" >> "$LOG"