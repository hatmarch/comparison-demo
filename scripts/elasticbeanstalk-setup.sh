#!/bin/bash

PROJECT_PATH=$1

if [ -z $PROJECT_PATH ]; then
    PROJECT_PATH=$DEMO_HOME/spring-framework-petclinic
fi

cd $PROJECT_PATH

# NOTE: the eb CLI does not respect the $AWS_PROFILE environment variable like the aws cli does
eb init eb-helloworld -r ap-southeast-2 -p Node.js --profile $AWS_PROFILE

eb create