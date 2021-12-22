#!/usr/local/bin/bash
#invoke with `bash gen.sh` if this isn't your bash location
#by Eric Gullufsen

work_dir=./gopher_files
mkdir -p $work_dir
function cleanup {
	rm -rf ${work_dir}
}
trap cleanup EXIT

#files and endpoints - global vars
base_url="http://data.nba.net/10s"
links_endp="/prod/v1/today.json"
standings_endp="/prod/v1/current/standings_conference.json"
info_file=${work_dir}/info_j.json
scores_file=${work_dir}/scores_j.json
standings_file=${work_dir}/standings_j.json
scores_tbldef_file=${work_dir}/scores.tbldef
standings_tbldef_file_west=${work_dir}/standings_west.tbldef
standings_tbldef_file_east=${work_dir}/standings_east.tbldef
standings_jqfile_west=./west.jq
standings_jqfile_east=./east.jq
scores_tbl_file_nroff=${work_dir}/scores.nroff.tbl
scores_tbl_file_handroll=${work_dir}/scores.handroll.tbl
standings_tbl_file_west=${work_dir}/standings_west.tbl
standings_tbl_file_east=${work_dir}/standings_east.tbl
nba_final=./nba_final.txt

#Grab Base data.nba.net JSON w/ links we need (endpoints)
curl --silent ${base_url}${links_endp} > $info_file
tdate=$(jq --raw-output --compact-output .links.currentDate $info_file)
gdate=$(date)

#Extract todayScoreboard Endpoint (URL)
# using -r (--raw-output)
today_endp=`jq --raw-output .links.todayScoreboard $info_file`
#form full scores endpoint URL
scores_url=$base_url$today_endp
#RETRIEVE SCOREBOARD JSON DATA (3)
curl -s $scores_url > $scores_file
#RETRIEVE STANDINGS JSON DATA (4)
curl -s $base_url$standings_endp > $standings_file

#this is a 'table definition' for tbl and nroff
cat << EHERE0 > $scores_tbldef_file
.TS
tab(@),allbox;
csss
cscs
cccc.
NBA SCOREBOARD
AWAY@HOME
EHERE0

# originally I hand-rolled the table, so to speak...
cat << EHERE3 > $scores_tbl_file_handroll
_____________________
|  NBA SCOREBOARD   |
=====================
|   HOME  |  AWAY   |
=====================
EHERE3

function begin_tbldef_standings {
cat << EHERE2 > $1
.TS
tab(@),allbox;
css
ccc.
$2
EHERE2
}

begin_tbldef_standings $standings_tbldef_file_east "EAST"
begin_tbldef_standings $standings_tbldef_file_west "WEST"

function generate_standings {
	jq -rc -f $1 $standings_file | while read s; do
		tn=$(echo $s | jq -rc '.teamSitesOnly.teamName')
		tw=$(echo $s | jq -rc '.win')
		tl=$(echo $s | jq -rc '.loss')
		#ta=($t)
		ta_len=${#da[@]}
		echo "${tn}@${tw}@${tl}" >> $2
	done
	echo ".TE" >> $2
}

generate_standings $standings_jqfile_east $standings_tbldef_file_east
generate_standings $standings_jqfile_west $standings_tbldef_file_west

jq -rc '.games | .[]' $scores_file | while read s; do
	d=`echo $s | jq -rc .vTeam.triCode,.vTeam.score,.hTeam.triCode,.hTeam.score`
	da=($d)
	da_len=${#da[@]} 
	if [[ $da_len -eq 2 ]]
	then
		echo "| ${da[0]}  -  | ${da[1]}  -  |" >> $scores_tbl_file_handroll
		echo "${da[0]}@-@${da[1]}@-" >> $scores_tbldef_file
	elif [[ $da_len -eq 4 ]]
	then
		vts=`printf '%3s' "${da[1]}"`
		hts=`printf '%3s' "${da[3]}"`
		echo "| ${da[0]} $vts | ${da[2]} $hts |" >> $scores_tbl_file_handroll
		echo "${da[0]}@${da[1]}@${da[2]}@${da[3]}" >> $scores_tbldef_file
 	else
		echo "bad game data" >> $scores_tbl_file_handroll
		echo "bad@game@data@here" >> $scores_tbldef_file
		
	fi
done

echo "=====================" >> $scores_tbl_file_handroll

echo ".TE" >> $scores_tbldef_file

tbl $scores_tbldef_file | nroff -Tascii >> $scores_tbl_file_nroff
tbl $standings_tbldef_file_east | nroff -Tascii > $standings_tbl_file_east
tbl $standings_tbldef_file_west | nroff -Tascii > $standings_tbl_file_west
#on BSD sed wants "" as first arg, not so on Linux
#using sed to remove blank lines coming out of tbl/nroff
sed -i.bak '/^[[:space:]]*$/d' $scores_tbl_file_nroff
sed -i.bak '/^[[:space:]]*$/d' $standings_tbl_file_east
sed -i.bak '/^[[:space:]]*$/d' $standings_tbl_file_west
#sed -i "" '/^[[:space:]]*$/d' $scores_tbl_file_nroff
paste -d' ' $standings_tbl_file_east $standings_tbl_file_west $scores_tbl_file_nroff > $nba_final
echo "Game Date: ${tdate:4:2}-${tdate:6:2}-${tdate:0:4}" >> $nba_final
echo "Standings/Scoreboard Generated: ${gdate}" >> $nba_final
cat $nba_final
