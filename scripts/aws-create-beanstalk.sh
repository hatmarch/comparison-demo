#!/bin/bash

set -e -u -o pipefail

declare PROJECT_NAME="PetClinic"

while (( "$#" )); do
  case "$1" in
    -n|--name)
        PROJECT_NAME=$2
        shift 2
        ;;
    -*|--*)
        echo "Error: Unsupported flag $1"
        ;;
    *)
    break
  esac
done

# assumes eb init --profile $AWS_PROFILE has already been run

cd $DEMO_HOME/spring-framework-petclinic/target/ROOT

# Per here the config file needs to be in the .elasticbeanstalk/saved_configs directory.  
# See: https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/eb3-create.html

# config file needs to be in a very specific location and named as per here:
# https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/environment-configuration-methods-during.html#configuration-options-during-ebcli-savedconfig
CONFIG_DIR=$DEMO_HOME/spring-framework-petclinic/.elasticbeanstalk/saved_configs/
mkdir -p $CONFIG_DIR
cp $DEMO_HOME/aws/elasticbeanstalk/petclinic-dev.cfg.yml $CONFIG_DIR/

# create the dev environment
eb create ${PROJECT_NAME}-dev --debug --cfg $DEMO_HOME/aws/elasticbeanstalk/petclinic-dev.cfg.yml -c PetClinic-dev \
    --cfg petclinic-dev --elb-type application 

# create the staging environment
eb clone ${PROJECT_NAME}-dev -n ${PROJECT_NAME}-stage