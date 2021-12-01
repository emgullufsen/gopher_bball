#!/usr/bin/bash

base_url="http://data.nba.net/10s"
links_endp="/prod/v1/today.json"
info_file=info_j.json
scores_file=scores_j.json
results_file=results.txt

#using -s (--silent)
curl -s ${base_url}${links_endp} > $info_file

# using -r (--raw-output)
today_endp=`jq -r .links.todayScoreboard $info_file`

scores_url=$base_url$today_endp

#echo $scores_url

curl -s $scores_url > $scores_file

rm -f $results_file

jq -rc '.games | .[]' $scores_file | while read s; do
	vT=`echo $s | jq -rc .vTeam.triCode,.vTeam.score,.hTeam.triCode,.hTeam.score`
	vTarr=($vT)
	vTarr_len=${#vTarr[@]} 
	if [[ $vTarr_len -eq 2 ]]
	then
		echo "${vTarr[0]} @ ${vTarr[1]}" >> $results_file
	elif [[ $vTarr_len -eq 4 ]]
	then
		echo "${vTarr[0]} ${vTarr[1]} @ ${vTarr[2]} ${vTarr[3]}" >> $results_file 
 	else
		echo "funky data for that game" >> $results_file
	fi

	#echo $vTarr_len
	#echo `${vTarr[0]} ${vTarr[1]} @ ${} ${}
done
