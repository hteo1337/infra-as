#!/bin/bash

function scaffold() {
cd ~
mkdir Installer
}

function downloadInstaller() {
if wget https://download.uipath.com/service-fabric/$version/installer-$version.zip -O installer.zip
then
  echo "Successfuly downloaded the installer"
else
  echo "Failed to download the installer. Error code: $?"
fi
}

function unzipInstaller() {
yum install unzip -y
unzip installer.zip -d Installer
cd Installer
chmod -R 755 .
}

function parseParams() {
while getopts a:b:c:d:e:f:g:h:i:j:k:l:m:n:o:p:r:s:t:u: flag "$@"; do
    case "${flag}" in
    a)
        fqdn=${OPTARG};;
    b)
        multinode=${OPTARG};;
    c)
        adminUserName=${OPTARG};;
    d)
        adminPassword=${OPTARG};;
    e)
        sqlFQDN=${OPTARG};;
    f)
        sqlAdminUserName=${OPTARG};;
    g)
        sqlAdminPassword=${OPTARG};;
    h)
        flagDocumentUnderstanding=${OPTARG};;
    i)
        flagInsights=${OPTARG};;
    j)
        flagTestManager=${OPTARG};;
    k)
        flagAutomationOps=${OPTARG};;
    l)
        flagAutomationHub=${OPTARG};;
    m)
        flagApps=${OPTARG};;
    n)
        flagActionCenter=${OPTARG};;
    o)
        flagTaskMining=${OPTARG};;
    p)
        flagOrchestratorAutomation=${OPTARG};;
    r)
        flagAICenter=${OPTARG};;
    s)
        rkeToken=${OPTARG};;
    t)
        haaEnabled=${OPTARG};;
    u)
        version=${OPTARG};;
    esac
done

echo "fqdn $fqdn"

}

function generateConfig() {
JSON_STRING=$( jq -n \
                  --arg fqdn "$fqdn" \
                  --arg mn "$multinode" \
                  --arg admnU "$adminUserName" \
                  --arg admnP "$adminPassword" \
                  --arg sqlfqdn "$sqlFQDN" \
                  --arg sqlAdmnU "$sqlAdminUserName" \
                  --arg sqlAdmnP "$sqlAdminPassword" \
                  --arg fdoc "$flagDocumentUnderstanding" \
                  --arg fins "$flagInsights" \
                  --arg ftm "$flagTestManager" \
                  --arg fauo "$flagAutomationOps" \
                  --arg fauh "$flagAutomationHub" \
                  --arg fapp "$flagApps" \
                  --arg facc "$flagActionCenter" \
                  --arg ftmi "$flagTaskMining" \
                  --arg forc "$flagOrchestratorAutomation" \
                  --arg faic "$flagAICenter" \
                  --arg rke "$rkeToken" \
                  --arg haa "$haaEnabled" \
                  '{"fqdn": $fqdn,"fixed_rke_address": "10.0.0.4","multinode": $mn,"admin_username": $admnU,"admin_password": $admnP,"ha": $haa,"gpu_support": "false","rke_token": $rke,"server_certificate": {  "ca_cert_file": "/tmp/rootCA.crt",  "tls_cert_file": "/tmp/server.crt",  "tls_key_file": "/tmp/server.key"},"identity_certificate": {  "token_signing_cert_file": "/tmp/identity.pfx",  "token_signing_cert_pass": ""},"sql": {  "server_url": $sqlfqdn,  "username": $sqlAdmnU,  "password": $sqlAdmnP,  "port": "1433",  "create_db": "true"},"sql_connection_string_template": "PLACEHOLDER","orchestrator": {  "testautomation": {    "enabled": $forc  },  "updateserver": {    "enabled": true  }},"aicenter": {    "enabled": $faic ,    "ai_helper": {      "sql_connection_str": "PLACEHOLDER"    },    "ai_pkgmanager": {      "sql_connection_str": "PLACEHOLDER"    },    "ai_deployer": {      "sql_connection_str": "PLACEHOLDER"    },    "ai_trainer": {      "sql_connection_str": "PLACEHOLDER"    },    "ai_appmanager": {      "sql_connection_str": "PLACEHOLDER"    }  },"documentunderstanding": {  "enabled": $fdoc,  "datamanager": {    "sql_connection_str": "PLACEHOLDER"  },  "handwriting": {    "enabled": false,    "max_cpu_per_pod": "PLACEHOLDER"  }},"insights": {  "enabled": $fins },"test_manager": {  "enabled": $ftm },"automation_ops": {  "enabled": $fauo },"automation_hub": {  "enabled": $fauh },"apps": {  "enabled": $fapp },"action_center": {  "enabled": $facc },"task_mining": {  "enabled": $ftmi }}')
echo "$JSON_STRING" > cluster_config.json

}

parseParams "$@"
scaffold
downloadInstaller
unzipInstaller
generateConfig
exit 0