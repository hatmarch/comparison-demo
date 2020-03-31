#!/bin/bash
oc apply -f $DEMO_HOME/kube/operators/mysql/mysql-agent.yaml
oc adm policy add-scc-to-user anyuid -z mysql-agent 

oc create secret generic mysql-root-password --from-literal=password="petclinic"

oc apply -f $DEMO_HOME/kube/operators/mysql/mysql-cluster-instance.yaml
oc apply -f $DEMO_HOME/kube/operators/mysql/mysql-primary-service.yaml

# wait for all pods in the cluster to be ready (loop on this as pods are not)
# created all at once
oc wait --for=condition=ready pod -l v1alpha1.mysql.oracle.com/cluster=petclinic-mysql-cluster --timeout=5m
sleep 5
oc wait --for=condition=ready pod -l v1alpha1.mysql.oracle.com/cluster=petclinic-mysql-cluster --timeout=5m
sleep 5
oc wait --for=condition=ready pod -l v1alpha1.mysql.oracle.com/cluster=petclinic-mysql-cluster --timeout=5m

# create the database and user for our service to use
oc run mysql-client --image=mysql:5.7 --restart=Never --rm=true --attach=true --wait=true \
    -- mysql -h petclinic-mysql -uroot -ppetclinic -e "CREATE USER 'pc'@'%' IDENTIFIED BY 'petclinic'; \
      CREATE DATABASE petclinic; \
      GRANT ALL PRIVILEGES ON petclinic.* TO 'pc'@'%';"