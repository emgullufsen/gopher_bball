#!/usr/bin/bash
#invoke with `bash gen.sh` if this isn't your bash location
#by Eric Gullufsen

work_dir=./gopher_files
mkdir -p $work_dir
function cleanup {
	rm -rf ${work_dir}
}
trap cleanup EXIT

# get environment (esp. variable SPORTRADAR_API_KEY) from secret file
source .env

#files and endpoints - global vars
scores_file=${work_dir}/scores_j.json
standings_file=${work_dir}/standings_j.json
scores_tbldef_file=${work_dir}/scores.tbldef
standings_tbldef_file_west=${work_dir}/standings_west.tbldef
standings_tbldef_file_east=${work_dir}/standings_east.tbldef
scores_tbl_file_nroff=${work_dir}/scores.nroff.tbl
standings_tbl_file_west=${work_dir}/standings_west.tbl
standings_tbl_file_east=${work_dir}/standings_east.tbl
nba_final=./nba_final.txt

baseUrl="https://api.sportradar.us/nba/trial/v7"
locale="en"
tzone="America/New_York"

# create m, d, and Y variables containing date info
read -r m d Y <<< "$(TZ='America/New_York' date +'%m %d %Y')"
games_endpoint="/${locale}/games/${Y}/${m}/${d}/schedule.json"
key_pararm="?api_key=${SPORTRADAR_API_KEY}"

# NOTE: status of games is 'scheduled', 'inprogress', or 'closed'
#       if status=='inprogress' or 'closed', then 
#       the game entry has home_points and away_points members
# ok, get games for today
# example: # https://api.sportradar.us/nba/trial/v7/en/games/2023/01/08/schedule.json?api_key=<KEY>

curl --location --request GET ${baseUrl}${games_endpoint}${key_pararm} > $scores_file

# cat $scores_file

# jq -rc '.games | .[]' $scores_file

#this is a 'table definition' for tbl and nroff
cat << EHERE0 > $scores_tbldef_file
.TS
tab(@),allbox;
cssss
cscsc
ccccc.
NBA SCOREBOARD
AWAY@HOME@
EHERE0

jq -rc '.games | .[]' $scores_file | while read s; do
	status=`echo $s | jq -rc .status`
	if [ "$status" = "closed" ] || [ "$status" = "inprogress" ]
	then
		d=`echo $s | jq -rc .away.alias,.home.alias,.id,.scheduled`
		da=($d)
		scores_endpoint="/${locale}/games/${da[2]}/boxscore.json"
		game_filename="${work_dir}/game-${da[2]}.json"
		sleep 2
		curl --location --request GET ${baseUrl}${scores_endpoint}${key_pararm} > $game_filename
		s=`jq -rc '.quarter,.clock_decimal,.away.points,.home.points' $game_filename`
		sa=($s)
		echo "${da[0]}@${sa[2]}@${da[1]}@${sa[3]}@${sa[0]}Q ${sa[1]}" >> $scores_tbldef_file
	elif [ "$status" = "scheduled" ]
	then
		d=`echo $s | jq -rc .away.alias,.home.alias,.id,.scheduled`
		da=($d)
		scheduled_edited=`TZ=$tzone date -d ${da[3]} +'%I:%M'`
		echo "${da[0]}@-@${da[1]}@-@${scheduled_edited}" >> $scores_tbldef_file
	else
		echo "bad@game@data@here@boyee" >> $scores_tbldef_file
	fi
done

echo ".TE" >> $scores_tbldef_file

tbl $scores_tbldef_file | nroff -Tascii >> $scores_tbl_file_nroff
sed -i.bak '/^[[:space:]]*$/d' $scores_tbl_file_nroff

cat $scores_tbl_file_nroff

# DONE WITH SCORES FILE
# | jq '[ .conferences[0].divisions[].teams[] ] | sort_by(.calc_rank.conf_rank)'
# {{baseUrl}}/:locale/seasons/:year/:season_type/standings.{{format}}

sleep 2
standings_endpoint="/${locale}/seasons/2022/REG/standings.json"
curl --location --request GET ${baseUrl}${standings_endpoint}${key_pararm} > $standings_file

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

tbl $standings_tbldef_file_east | nroff -Tascii > $standings_tbl_file_east
tbl $standings_tbldef_file_west | nroff -Tascii > $standings_tbl_file_west

sed -i.bak '/^[[:space:]]*$/d' $standings_tbl_file_east
sed -i.bak '/^[[:space:]]*$/d' $standings_tbl_file_west

paste -d'*' $standings_tbl_file_east $standings_tbl_file_west $scores_tbl_file_nroff > $nba_final
date >> $nba_final
cat $nba_final

exit
