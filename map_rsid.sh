#!/bin/bash

map_dir=/user/work/vc23656/proteins/rsid
inst=/user/work/vc23656/proteins/cis_pqtl_instruments_all_clean.csv
out=/user/work/vc23656/proteins/cis_pqtl_instruments_with_rsid.csv

awk '
BEGIN {FS=OFS=","}

# First load mapping files (tab-separated)
FILENAME ~ /olink_rsid_map/ {
    if (FNR>1) {
        split($0,a,"\t")
        map[a[1]] = a[4]   # ID -> rsid
    }
    next
}

# Now process instruments file
FNR==1 {print $0,"rsid"; next}

{
    id=$4
    print $0,(id in map ? map[id] : "")
}
' ${map_dir}/olink_rsid_map_mac5_info03_b0_7_chr*_patched_v2.tsv $inst > $out

echo "Finished: $out"
