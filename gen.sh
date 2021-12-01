#!/usr/local/bin/bash

base_url="http://data.nba.net/10s"
links_endp="/prod/v1/today.json"
standings_endp="/prod/v1/current/standings_conference.json"
info_file=info_j.json
scores_file=scores_j.json
standings_file=standings_j.json
results_file=results.txt
scores_tbldef_file=scores.tbldef
standings_tbldef_file=standings.tbldef
scores_tbl_file_nroff=scores.nroff.tbl
scores_tbl_file_ascii=scores.ascii.tbl

#using -s (--silent)
curl -s ${base_url}${links_endp} > $info_file

# using -r (--raw-output)
today_endp=`jq -r .links.todayScoreboard $info_file`

scores_url=$base_url$today_endp

#echo $scores_url

curl -s $scores_url > $scores_file

rm -vf $results_file

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
_______________________
|   NBA SCOREBOARD    |
=======================
|    HOME  |  AWAY    |
=======================
EHERE

jq -rc '.games | .[]' $scores_file | while read s; do
	vT=`echo $s | jq -rc .vTeam.triCode,.vTeam.score,.hTeam.triCode,.hTeam.score`
	vTarr=($vT)
	vTarr_len=${#vTarr[@]} 
	if [[ $vTarr_len -eq 2 ]]
	then
		echo "|  ${vTarr[0]}  |  ${vTarr[1]}  |" >> $scores_tbl_file_ascii
		echo "${vTarr[0]}@-@${vTarr[1]}@-" >> $scores_tbldef_file
	elif [[ $vTarr_len -eq 4 ]]
	then
		echo "| ${vTarr[0]} - ${vTarr[1]} | ${vTarr[2]} - ${vTarr[3]} |" >> $scores_tbl_file_ascii
		echo "${vTarr[0]}@${vTarr[1]}@${vTarr[2]}@${vTarr[3]}" >> $scores_tbldef_file
 	else
		echo "bad game data" >> $scores_tbl_file_ascii
		echo "bad@game@data@here" >> $scores_tbldef_file
		
	fi

	#echo $vTarr_len
	#echo `${vTarr[0]} ${vTarr[1]} @ ${} ${}
done

cat $scores_tbl_file_ascii

echo ".TE" >> $scores_tbldef_file
tbl $scores_tbldef_file | nroff > $scores_tbl_file_nroff
sed -i "" '/^[[:space:]]*$/d' $scores_tbl_file_nroff

cat $scores_tbl_file_nroff
