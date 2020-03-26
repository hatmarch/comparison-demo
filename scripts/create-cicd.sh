#!/bin/bash

set -e -u -o pipefail
declare -r SCRIPT_DIR=$(cd -P $(dirname $0) && pwd)
declare PRJ_PREFIX="petclinic"
declare COMMAND="help"
declare CREATE_DEV=false

valid_command() {
  local fn=$1; shift
  [[ $(type -t "$fn") == "function" ]]
}

info() {
    printf "\n# INFO: $@\n"
}

err() {
  printf "\n# ERROR: $1\n"
  exit 1
}

while (( "$#" )); do
  case "$1" in
    install|uninstall|start)
      COMMAND=$1
      shift
      ;;
    -p|--project-prefix)
      PRJ_PREFIX=$2
      shift 2
      ;;
    --dev)
      CREATE_DEV=$2
      shift 2
      ;;
    --)
      shift
      break
      ;;
    -*|--*)
      err "Error: Unsupported flag $1"
      ;;
    *) 
      break
  esac
done

declare -r dev_prj="$PRJ_PREFIX-dev"
declare -r stage_prj="$PRJ_PREFIX-stage"
declare -r cicd_prj="$PRJ_PREFIX-cicd"

command.help() {
  cat <<-EOF

  Usage:
      demo [command] [options]
  
  Example:
      demo install --project-prefix mydemo
  
  COMMANDS:
      install                        Sets up the demo and creates namespaces
      uninstall                      Deletes the demo namespaces
      start                          Starts the demo pipeline
      help                           Help about this command

  OPTIONS:
      -p|--project-prefix [string]   Prefix to be added to demo project names e.g. PREFIX-dev
EOF
}

command.install() {
  oc version >/dev/null 2>&1 || err "no oc binary found"

  if [[ -z "${DEMO_HOME:-}" ]]; then
    err '$DEMO_HOME not set'
  fi

  info "Creating namespaces $cicd_prj, $dev_prj, $stage_prj"
  oc get ns $cicd_prj 2>/dev/null  || { 
    oc new-project $cicd_prj 
  }
  # oc get ns $dev_prj 2>/dev/null  || { 
  #   oc new-project $dev_prj
  #}
  oc get ns $stage_prj 2>/dev/null  || { 
    oc new-project $stage_prj 
  }

  info "Configure service account permissions for pipeline"
  oc policy add-role-to-user edit system:serviceaccount:$cicd_prj:pipeline -n $dev_prj
  oc policy add-role-to-user edit system:serviceaccount:$cicd_prj:pipeline -n $stage_prj

  info "Deploying CI/CD infra to $cicd_prj namespace"
  oc apply -R -f $DEMO_HOME/kube/cd -n $cicd_prj
  GOGS_HOSTNAME=$(oc get route gogs -o template --template='{{.spec.host}}' -n $cicd_prj)

  info "Deploying pipeline and tasks to $cicd_prj namespace"
  oc apply -f $DEMO_HOME/kube/tekton/tasks -n $cicd_prj
  oc apply -f $DEMO_HOME/kube/config/maven-configmap.yaml -n $cicd_prj
  oc apply -f $DEMO_HOME/kube/tekton/pipelines/pipeline-pvc.yaml -n $cicd_prj

  # FIXME: Replace with template call
  # Also need to update to match git resources
  sed "s/demo-dev/$dev_prj/g" $DEMO_HOME/kube/tekton/pipelines/petclinic-dev-pipeline-tomcat.yaml | oc apply -f - -n $cicd_prj
  oc process -f $DEMO_HOME/kube/tekton/pipelines/petclinic-stage-pipeline-tomcat-template -p PROJECT_NAME=$cicd_prj -p DEVELOPMENT_PROJECT=$dev_prj | oc apply -f - -n $cicd_prj
  
  # Install pipeline resources
  sed "s/demo-dev/$dev_prj/g" $DEMO_HOME/kube/tekton/resources/app-image.yaml | oc apply -f - -n $cicd_prj
  
  # FIXME: Decide which repo we want to trigger/pull from
  # sed "s#https://github.com/spring-projects/spring-petclinic#http://$GOGS_HOSTNAME/gogs/spring-petclinic.git#g" $DEMO_HOME/kube/tekton/resources/app-git.yaml | oc apply -f - -n $cicd_prj
  oc apply -f $DEMO_HOME/kube/tekton/resources/app-git.yaml

  # Install pipeline triggers
  oc apply -f $DEMO_HOME/kube/tekton/triggers -n $cicd_prj

  # info "Deploying app to $dev_prj namespace"
  # oc import-image quay.io/siamaksade/spring-petclinic --confirm -n $dev_prj
  # oc apply -f app -n $dev_prj
  # oc set image deployment/spring-petclinic spring-petclinic=image-registry.openshift-image-registry.svc:5000/$dev_prj/spring-petclinic -n $dev_prj

  # info "Deploying app to $stage_prj namespace"
  # oc tag $dev_prj/spring-petclinic:latest $stage_prj/spring-petclinic:latest
  # oc apply -f app -n $stage_prj
  # oc set image deployment/spring-petclinic spring-petclinic=image-registry.openshift-image-registry.svc:5000/$stage_prj/spring-petclinic -n $stage_prj

  info "Initiatlizing git repository in Gogs and configuring webhooks"
  sed "s/@HOSTNAME/$GOGS_HOSTNAME/g" $DEMO_HOME/kube/config/gogs-configmap.yaml | oc create -f - -n $cicd_prj
  oc rollout status deployment/gogs -n $cicd_prj
  oc create -f $DEMO_HOME/kube/config/gogs-init-taskrun.yaml -n $cicd_prj

  cat <<-EOF

############################################################################
############################################################################

  CI/CD project is installed! Give it a few minutes to finish deployments and then:

  1) Go to spring-petclinic Git repository in Gogs:
     http://$GOGS_HOSTNAME/gogs/spring-petclinic.git
  
  2) Log into Gogs with username/password: gogs/gogs
      
  3) Edit a file in the repository and commit to trigger the pipeline

  4) Check the pipeline run logs in Dev Console or Tekton CLI:
     
    \$ tkn pipeline logs petclinic-deploy-dev -f -n $cicd_prj

############################################################################
############################################################################
EOF
}

command.start() {
  oc create -f runs/pipeline-deploy-dev-run.yaml -n $cicd_prj
}

command.uninstall() {
  oc delete project $dev_prj $stage_prj $cicd_prj
}

main() {
  local fn="command.$COMMAND"
  valid_command "$fn" || {
    err "invalid command '$COMMAND'"
  }

  cd $SCRIPT_DIR
  $fn
  return $?
}

main