#!/bin/sh

RED='\033[0;31m'
NC='\033[0m' # No Color
BLUE='\033[0;34m'
GREEN='\033[0;32m'

#Define all constants
MYSQL_START_CONST='sudo /usr/local/mysql-5.6.25-osx10.8-x86_64/support-files/mysql.server start'
ZK_LOCATION='/Users/hare.kumar/apps/zookeeper-3.4.6'
ZK_START='sudo ./bin/zkServer.sh start'
KAFKA_LOCATION='/Users/hare.kumar/apps/kafka_2.10-0.8.2.0'
KAFKA_START='./bin/kafka-server-start.sh -daemon config/server.properties'
WORKING_DIRECTORY_TOMCAT='/Users/hare.kumar/Documents/workspace/shopo-tomcat'
TOMCAT_SERVER_DIRECTORY='/Users/hare.kumar/opt'
EJABBERD_LOCATION='/Applications/ejabberd-15.04'

echo "${RED}****** SETTING UP YOUR WORKSPACE. SIT BACK AND RELAX | I WILL DO THE REST *****${NC}"
echo

fetchAndBuild() 
{

    echo "$1 --> $2 --> $3"

    cd "$(pwd)/$1"
    
    ## If user provides current branch 
    if [ ! -z "$3" ];
    then
        echo "running git fetch --all"
        git fetch --all
        echo "checking out to branch $3"
        git checkout $3
        git pull origin $3
        ret=$?
        if [[ "$ret" != 0 ]]; then
            echo "Checking out to recently modified branch"
            RECENTLY_MODIFIED_BRANCH=$(git for-each-ref --count=1 --sort=-committerdate refs/heads/ --format='%(refname:short)')
            git checkout $RECENTLY_MODIFIED_BRANCH
        fi
    else
        echo "Third parameter missing. Hence proceeding with default current branch."
        GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
        echo "${RED}######## Pulling from git branch $GIT_BRANCH ######${NC}"
        git pull origin $GIT_BRANCH
    fi

    echo "${BLUE}running mvn clean $2 ${NC}"
    mvn clean $2
    if [ "$?" -ne 0 ]; then
        echo "Maven clean $2 unsuccessful"
        exit 1
    fi
    cd ..
}


echo "Checking mysql stauts & starting it up if not already running"
MYSQL_PROCESS_COUNT=$(pgrep mysql | wc -l);
if [$MYSQL_PROCESS_COUNT -eq 0 ] ; then
    $MYSQL_START_CONST
else
    echo "Mysql is already running! Moving on"
fi

echo "2. Starting zookeeper & kafka server"
cd $ZK_LOCATION
$ZK_START

cd "$KAFKA_LOCATION"
$KAFKA_START
echo "kafka & zookeeper started successfully"

echo "3. Starting ejabberd server"
cd $EJABBERD_LOCATION
./bin/ejabberdctl start

echo "3. Updating git repositories code base "
cd "$WORKING_DIRECTORY_TOMCAT"
echo "Updating & building client first"

GIT_BRANCH_OF_CHOICE=$1
echo "GIT BRANCH OF YOUR CHOICE $GIT_BRANCH_OF_CHOICE"

for directory in *lient/;
do
    fetchAndBuild $directory install $GIT_BRANCH_OF_CHOICE
done
echo "Yay! ALL clients fetched & installed succesfully"

echo "Starting to build sub systems now"
for directory in */;
do
    if [[ $directory == *"Client"* ]]
    then
        echo "Skipping git pull & mvn clean package for $directory"
    else
        fetchAndBuild $directory package $GIT_BRANCH_OF_CHOICE
    fi
done

echo "Client & Subsystems built successfully."
echo 

echo "Starting tomcat server"

read -p "Do you wish to see logs file for starting tomcat server?(Y|N) Logs will be visible for 20 seconds only." answer

cd $TOMCAT_SERVER_DIRECTORY
for d in tomcat-*/;
do
    echo $d
    cd $d
    ./bin/catalina.sh start

    if [ "$answer" == "Y" ]
    then
        tail -f logs/catalina.out &
        tailpid=$!
        sleep 20
        kill $tailpid
    fi
    cd ..
done
echo "${GREEN}**************** END OF SCRIPT *****************${NC}"
