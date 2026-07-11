#!/usr/bin/bash
#invoke with `bash gen.sh` if this isn't your bash location
#by Eric Gullufsen

work_dir=./gopher_files
mkdir -p $work_dir
function cleanup {
	rm -rf ${work_dir}
}
#trap cleanup EXIT

# get environment if necessary (it isn't for this API - )
#source .env

#files and endpoints - global vars
standings_file_al=${work_dir}/standings_j_al.json
standings_tbldef_file_al_west=${work_dir}/standings_al_west.tbldef
standings_tbl_file_al_west=${work_dir}/standings_al_west.tbl
mlb_final=./mlb_final.txt

baseUrl="https://statsapi.mlb.com/api/v1/standings"
al_string="?leagueId=103"
sleep 2
standings_endpoint_al="${baseUrl}${al_string}"

echo "standings_endpoint is: ${standings_endpoint_al}"
curl --location --request GET $standings_endpoint_al > $standings_file_al

#cat test.json > $standings_file_al

function begin_tbldef_standings {
cat << EHERE2 > $1
.TS
tab(;),allbox;
css
ccc.
$2
TEAM;WINS;LOSSES
EHERE2
}

echo "got here 1"

begin_tbldef_standings $standings_tbldef_file_al_west "AMERICAN LEAGUE WEST"

echo "got here 2"

sorted_al_west="${work_dir}/sorted_al.json"
jq '[ .records[2].teamRecords ] | sort_by(.[].divisionRank)' $standings_file_al > $sorted_al_west

echo "got here 3"

function generate_standings {
	jq -rc '.[].[]' $1 | while read s; do
        #echo $s
		d=`echo $s | jq -rc .team.name,.wins,.losses`
		da=($d)
		da_len=${#da[@]}
        echo "hi"
		echo "${da[0]};${da[1]};${da[2]}" >> $2
	done
	echo ".TE" >> $2
}

echo "got here 4"

generate_standings $sorted_al_west $standings_tbldef_file_al_west

groff -t -Tascii $standings_tbldef_file_al_west > $standings_tbl_file_al_west

sed -i.bak '/^[[:space:]]*$/d' $standings_tbl_file_al_west

cat $standings_tbl_file_al_west > $mlb_final
date >> $mlb_final
cat $mlb_final

exit
