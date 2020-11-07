#!/bin/bash

cd /root/project
DIFF=false

print_update_log () {
    echo "Updating variables based on new changes for $1"
}

print_update_service () {
    echo "Updating services based on newly added variables for $1"
}

print_no_update () {
    echo "No changes in variable to update for $1"
}

#grab the names of parameter
get_parameter_name () {
  aws ssm describe-parameters --query Parameters |jq .[].Name|xargs echo| tr ' ' '\n' > /root/project/ssm_store
}

#download currently present parameter from parameter store
download_current_parameter () {
  aws --region us-east-1 ssm get-parameters --names "$1" --with-decryption --query Parameters | jq .[].Value |xargs echo |awk '{gsub(/\\n/,"\n")}1'|sed -e '/^$/d' > /root/project/"$1-current"
}

#update variables in parameter store based on recent push
update_parameter () {
  aws ssm put-parameter --name "$1" --value file://"$1" --type String --region us-east-1 --overwrite --tier Advanced
}

#Compoare current variables in parameter store and updated file in git for changes
diff_check () {
	diff "$1" "$1-current"
  if [ $? != 0 ]; then
    print_update_log "$1"
    update_parameter "$1"
    print_update_service "$1"   
    DIFF=true
  else
    print_no_update "$1"
    DIFF=false
  fi
}

#change directory to default
change_directory () {
  cd /root/project
}

#will do the necessary function call and execution
final_steps () {
  change_directory
  diff_check "$1"
  change_directory
}

#Grab the names of ssm parameter
get_parameter_name 

while read -r line; do
  echo "Download current variables from ssm store"
  download_current_parameter $line
  
	case "$line" in
		"service")
      final_steps "$line"
			;;
		*) echo "no change"
			;;
  esac
done < ~/project/ssm_store
