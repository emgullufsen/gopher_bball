#!/usr/bin/bash
#invoke with `bash gen.sh` if this isn't your bash location
#by Eric Gullufsen

work_dir=./gopher_files
mkdir -p $work_dir
function cleanup {
	rm -rf ${work_dir}
}
trap cleanup EXIT

# get environment if necessary (it isn't for this API - )
#source .env

#files and endpoints - global vars
standings_file_al=${work_dir}/standings_j_al.json
standings_file_nl=${work_dir}/standings_j_nl.json
standings_tbldef_file_al=${work_dir}/standings_al.tbldef
standings_tbldef_file_nl=${work_dir}/standings_nl.tbldef
standings_tbl_file_west=${work_dir}/standings_al.tbl
standings_tbl_file_east=${work_dir}/standings_nl.tbl
nba_final=./nba_final.txt

baseUrl="https://statsapi.mlb.com/api/v1/standings"
al_string="?leagueId=103"
nl_string="?leagueId=104"
sleep 2
standings_endpoint_al="${baseUrl}${al_string}"
standings_endpoint_nl="${baseUrl}${nl_string}"

echo "standings_endpoint is: ${standings_endpoint_al}"
curl --location --request GET $standings_endpoint_al > $standings_file_al

function begin_tbldef_standings {
cat << EHERE2 > $1
.TS
tab(@),allbox;
css
ccc.
$2
EHERE2
}

begin_tbldef_standings $standings_tbldef_file_al "AMERICAN LEAGUE"
begin_tbldef_standings $standings_tbldef_file_nl "NATIONAL LEAGUE"

sorted_west="${work_dir}/sorted_west.json"
jq '[ .conferences[0].divisions[].teams[] ] | sort_by(.calc_rank.conf_rank)' $standings_file > $sorted_west

sorted_east="${work_dir}/sorted_east.json"
jq '[ .conferences[1].divisions[].teams[] ] | sort_by(.calc_rank.conf_rank)' $standings_file > $sorted_east

function generate_standings {
	jq -rc '.[]' $1 | while read s; do
		d=`echo $s | jq -rc .name,.wins,.losses`
		da=($d)
		da_len=${#da[@]}
		if [ ${da[0]} == "Trail" ] 
		then
			echo "${da[0]} ${da[1]}@${da[2]}@${da[3]}" >> $2
		else
			echo "${da[0]}@${da[1]}@${da[2]}" >> $2
		fi
	done
	echo ".TE" >> $2
}

generate_standings $sorted_east $standings_tbldef_file_east
generate_standings $sorted_west $standings_tbldef_file_west

groff -t -Tascii $standings_tbldef_file_east > $standings_tbl_file_east
groff -t -Tascii $standings_tbldef_file_west > $standings_tbl_file_west

sed -i.bak '/^[[:space:]]*$/d' $standings_tbl_file_east
sed -i.bak '/^[[:space:]]*$/d' $standings_tbl_file_west

paste -d'*' $standings_tbl_file_east $standings_tbl_file_west $scores_tbl_file_nroff > $nba_final
date >> $nba_final
cat $nba_final

exit
