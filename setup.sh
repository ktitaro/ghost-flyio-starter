#!/bin/sh

base_apps_dir="./apps"
ghost_app_dir="$base_apps_dir/ghost"
mysql_app_dir="$base_apps_dir/mysql"
ghost_app_cfg="$ghost_app_dir/fly.toml"
mysql_app_cfg="$mysql_app_dir/fly.toml"
ghost_cfg_tmpl="./.tmp/ghost_cfg.tmpl"
mysql_cfg_tmpl="./.tmp/mysql_cfg.tmpl"
ghost_env_tmpl="./.tmp/ghost_env.tmpl"
mysql_env_tmpl="./.tmp/mysql_env.tmpl"
secrets_tmpl="./.tmp/secrets.tmpl"
secrets_file="./secrets.txt"

# Prompts the user for input
# + displays prompt message
# + provides default value
read_input() {
  msg=$1
  if [[ ! -z $2 ]]; then
    msg="$msg (default: \"$2\")"
  fi
  read -p "$msg: " data
  if [[ ! -z $2 ]]; then
    data=${data:-$2}
  fi
  echo "$data"
}

# Generates random password
# consisting of 16 letters.
gen_password() {
  src="/dev/random"
  echo "$(
    cat $src | \
    base64   | \
    head -c 16
  )"
}

# Writes MySQL generated
# passwords to the file.
dump_secrets() {
  data=$(cat "$secrets_tmpl")
  data=${data//"{{dbUser}}"/$1}
  data=${data//"{{dbName}}"/$2}
  data=${data//"{{dbUserPwd}}"/$3}
  data=${data//"{{dbRootPwd}}"/$4}
  echo "$data" > "$secrets_file"
}

# Setup fly.io config
# for the ghost app.
setup_ghost_cfg() {
  data=$(cat "$ghost_cfg_tmpl")
  data=${data//"{{name}}"/$1}
  data=${data//"{{region}}"/$2}
  echo "$data" > "$ghost_app_cfg"
}

# Setup fly.io config
# for the mysql app.
setup_mysql_cfg() {
  data=$(cat "$mysql_cfg_tmpl")
  data=${data//"{{name}}"/$1}
  data=${data//"{{region}}"/$2}
  echo "$data" > "$mysql_app_cfg"
}

# Setup env variables
# for the ghost app.
setup_ghost_env() {
  data=$(cat "$ghost_env_tmpl")
  data=${data//"{{name}}"/$1}
  data=${data//"{{dbUser}}"/$2}
  data=${data//"{{dbName}}"/$3}
  data=${data//"{{dbUserPwd}}"/$4}
  eval "$data"
}

# Setup env variables
# for the mysql app.
setup_mysql_env() {
  data=$(cat "$mysql_env_tmpl")
  data=${data//"{{name}}"/$1}
  data=${data//"{{dbUser}}"/$2}
  data=${data//"{{dbName}}"/$3}
  data=${data//"{{dbUserPwd}}"/$4}
  data=${data//"{{dbRootPwd}}"/$5}
  eval "$data"
}

main() {
  # Handles user input.
  name=$(read_input "Enter blog name" "my-blog")
  region=$(read_input "Enter region id", "lhr")
  dbUser=$(read_input "Enter MySQL user name", "ghost")
  dbName=$(read_input "Enter MySQL database name", "ghost")
  dbUserPwd=$(read_input "Enter MySQL user password", "$(gen_password)")
  dbRootPwd=$(read_input "Enter MySQL root password", "$(gen_password)")
  name=$(echo "$name" | tr "[:punct:]" "-") # name.com -> name-com
  
  # Comment this line if you already
  # logged-in and don't want to see
  # unnecessary prompts.
  fly auth login

  echo "Creating fly.io apps..."
  fly app create "$name-ghost" -o personal
  fly app create "$name-mysql" -o personal

  echo "Setting up folders..."
  rm -rf "$secrets_file"
  rm -rf "$base_apps_dir"
  mkdir -p "$ghost_app_dir"
  mkdir -p "$mysql_app_dir"
  setup_ghost_cfg "$name" "$region"
  setup_mysql_cfg "$name" "$region"
  dump_secrets \
    "$dbUser" \
    "$dbName" \
    "$dbUserPwd" \
    "$dbRootPwd"

  echo "Setting up env variables..."
  setup_ghost_env "$name" "$dbUser" "$dbName" "$dbUserPwd"
  setup_mysql_env "$name" "$dbUser" "$dbName" "$dbUserPwd" "$dbRootPwd"

  echo "Deploying to fly.io..."
  cd "$mysql_app_dir" && fly deploy && cd ../..
  cd "$ghost_app_dir" && fly deploy && cd ../..

  url="https://$name-ghost.fly.dev"
  echo "Done 🔥 Check it out: $url"
}

main