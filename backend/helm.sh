#!/bin/bash
NEW_VERSION=""
CURRENT_VERSION=""
if ! kubectl get configmap blue-green-status -n expense > /dev/null 2>&1; then
    echo "First deployment detected! Creating ConfigMap and deploying Blue..."
    kubectl create configmap blue-green-status --from-literal=live-version="blue"
    NEW_VERSION="blue"
else
    CURRENT_VERSION=$(kubectl get configmap blue-green-status -o=jsonpath='{.data.live-version}')
    if [ "$CURRENT_VERSION" == "blue" ]; then
        NEW_VERSION="green"
    else
        NEW_VERSION="blue"
    fi
fi

helm upgrade --install backend . --set service.currentVersion=$NEW_VERSION
kubectl patch configmap blue-green-status -n expense --type merge -p '{"data":{"live-version":"'$NEW_VERSION'"}}'
