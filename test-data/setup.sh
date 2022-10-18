

#######################################################################
# THIS FILE IS CURRENTLY NOT MAINTAINED
# PLEASE FOLLOW THE TUTORIAL ON HTTPS://TUTORIALS.KEPTN.SH TO USE THIS
#######################################################################



# prerequisite: have keptn installed with --use-case=continuous-delivery flag
# 1. install Keptn https://keptn.sh/docs/quickstart/#helm
# 2. install Keptn CLI - https://keptn.sh/docs/quickstart/#keptn-cli
# 3. annotate namespace to be managed by keptn `kubectl annotate namespace keptn keptn.sh/managed-by=keptn`
# 4. label the namespace to be managed by keptn `kubectl label namespace keptn  keptn.sh/managed-by=keptn`
# 5. connect the Keptn CLI to the cluster `keptn auth`


#####################################################################
# make sure you are executing those commands in test-data folder!!!
#####################################################################

# 6. LITMUS Demo Setup Pre-Req

## install litmus operator & chaos CRDs 
kubectl apply -f litmus/litmus-operator-v2.13.0.yaml

# wait for operator to start
sleep 10

## create litmus-chaos namespace
kubectl create namespace litmus-chaos
## pull the chaos experiment CR (static) 
kubectl apply -f litmus/pod-delete-ChaosExperiment-CR.yaml 
## pull the chaos experiment RBAC (static) 
kubectl apply -f litmus/pod-delete-rbac.yaml 

# 7. Add Prometheus and Prometheus-SLI-Service
kubectl create namespace monitoring
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/prometheus --namespace monitoring

PROMETHEUS_NS=<PROMETHEUS_NS>
PROMETHEUS_ENDPOINT=<PROMETHEUS_ENDPOINT>
ALERT_MANAGER_NS=<ALERT_MANAGER_NS>
KEPTN_NAMESPACE="keptn"
helm upgrade -n ${KEPTN_NAMESPACE} prometheus-service \
  https://github.com/keptn-contrib/prometheus-service/releases/download/<VERSION>/prometheus-service-<VERSION>.tgz \
  --reuse-values \
  --set prometheus.namespace=${PROMETHEUS_NS} \
  --set prometheus.endpoint=${PROMETHEUS_ENDPOINT} \
  --set prometheus.namespace_am=${ALERT_MANAGER_NS}

# 8. Install this service (litmus-service)
kubectl apply -f ../deploy/service.yaml

# 9. Setup project and service in Keptn

## CREATE PROJECT
GIT_USER=gitusername
GIT_TOKEN=gittoken
GIT_REMOTE_URL=remoteurl
keptn create project litmus --shipyard=./shipyard.yaml --git-user=$GIT_USER --git-token=$GIT_TOKEN --git-remote-url=$GIT_REMOTE_URL

## Create SERVICE
keptn create service helloservice --project=litmus

## ADD HELLO SERVICE
# To add only helm directly inside the tar file, tar command should be run inside the helloservice directory
# otherwise it will add the complete path(i.e, /helloservice/helm) inside the tar
cd helloservice && tar cfvz ./helm.tgz ./helm
# return back to the test-data folder
cd ..
# adding helloservice helm tar file
keptn add-resource --project=litmus --service=helloservice --all-stages --resource=./helloservice/helm.tgz --resourceUri=helm/helloservice.tgz

## ADD JMETER TESTS & CONFIG
keptn add-resource --project=litmus --stage=chaos --service=helloservice --resource=./jmeter/load.jmx --resourceUri=jmeter/load.jmx
keptn add-resource --project=litmus --stage=chaos --service=helloservice --resource=./jmeter/jmeter.conf.yaml --resourceUri=jmeter/jmeter.conf.yaml

## ADD QUALITY GATE
keptn add-resource --project=litmus --stage=chaos --service=helloservice --resource=./prometheus/sli.yaml --resourceUri=prometheus/sli.yaml
keptn add-resource --project=litmus --stage=chaos --service=helloservice --resource=helloservice/slo.yaml --resourceUri=slo.yaml

## ADD LITMUS EXPERIMENT
keptn add-resource --project=litmus --stage=chaos --service=helloservice --resource=./litmus/experiment.yaml --resourceUri=litmus/experiment.yaml

# 9. Configure Prometheus for this project
keptn configure monitoring prometheus --project=litmus --service=helloservice

## Install blackbox exporter and change configuration of prometheus
kubectl apply -f ./prometheus/blackbox-exporter.yaml
kubectl apply -f ./prometheus/prometheus-server-conf-cm.yaml -n monitoring

## Restart prometheus
kubectl delete pod -l component=server -n monitoring

# 10. Trigger the deployment, tests, and evaluation of our demo application
keptn trigger delivery --project=litmus --service=helloservice --image=jetzlstorfer/hello-server:v0.1.1

# 11. Second deployment event: Scale hello-service (see deploy-event.json)
keptn send event -f helloservice/deploy-event.json
