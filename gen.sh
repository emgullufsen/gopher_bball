#!/usr/local/bin/bash
#invoke with `bash gen.sh` if this isn't your bash location
work_dir=./gopher_files
mkdir -p $work_dir
function cleanup {
	rm -rf ${work_dir}
}
trap cleanup EXIT
base_url="http://data.nba.net/10s"
links_endp="/prod/v1/today.json"
standings_endp="/prod/v1/current/standings_conference.json"
info_file=${work_dir}/info_j.json
scores_file=${work_dir}/scores_j.json
standings_file=${work_dir}/standings_j.json
results_file=score_results.txt
scores_tbldef_file=${work_dir}/scores.tbldef
standings_tbldef_file=${work_dir}/standings.tbldef
scores_tbl_file_nroff=${work_dir}/scores.nroff.tbl
scores_tbl_file_ascii=${work_dir}/scores.ascii.tbl

#GRAB BASE NBA JSON DATA (LINKS) (1)
#using -s (--silent)
curl -s ${base_url}${links_endp} > $info_file

#GET SCOREBOARD ENDPOINT FROM RETRIEVED JSON (FROM 1) (2)
# using -r (--raw-output)
today_endp=`jq -r .links.todayScoreboard $info_file`
#form full scores endpoint URL
scores_url=$base_url$today_endp
#RETRIEVE SCOREBOARD JSON DATA (3)
curl -s $scores_url > $scores_file
#RETRIEVE STANDINGS JSON DATA (4)
curl -s $base_url$standings_endp > $standings_file

cat << EHERE0 > $scores_tbldef_file
.TS
tab(@),allbox;
csss
cscs
cccc.
NBA SCOREBOARD
AWAY@HOME
EHERE0

cat << EHERE > $scores_tbl_file_ascii
_____________________
|  NBA SCOREBOARD   |
=====================
|   HOME  |  AWAY   |
=====================
EHERE

jq -rc '.games | .[]' $scores_file | while read s; do
	d=`echo $s | jq -rc .vTeam.triCode,.vTeam.score,.hTeam.triCode,.hTeam.score`
	da=($d)
	da_len=${#da[@]} 
	if [[ $da_len -eq 2 ]]
	then
		echo "|  ${da[0]} -  |  ${da[1]} -  |" >> $scores_tbl_file_ascii
		echo "${da[0]}@-@${da[1]}@-" >> $scores_tbldef_file
	elif [[ $da_len -eq 4 ]]
	then
		vts=`printf '%3s' "${da[1]}"`
		hts=`printf '%3s' "${da[3]}"`
		echo "| ${da[0]} $vts | ${da[2]} $hts |" >> $scores_tbl_file_ascii
		echo "${da[0]}@${da[1]}@${da[2]}@${da[3]}" >> $scores_tbldef_file
 	else
		echo "bad game data" >> $scores_tbl_file_ascii
		echo "bad@game@data@here" >> $scores_tbldef_file
		
	fi
done

echo "=====================" >> $scores_tbl_file_ascii

cat $scores_tbl_file_ascii
cp $scores_tbl_file_ascii $results_file
echo ".TE" >> $scores_tbldef_file
tbl $scores_tbldef_file | nroff > $scores_tbl_file_nroff
#on BSD sed wants "" as first arg, not so on Linux
#using sed to remove blank lines coming out of tbl/nroff
sed -i.bak '/^[[:space:]]*$/d' $scores_tbl_file_nroff
#sed -i "" '/^[[:space:]]*$/d' $scores_tbl_file_nroff
cat $scores_tbl_file_nroff
