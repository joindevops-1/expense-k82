#!/bin/bash
PREVIEW_VERSION=""
CURRENT_VERSION=""
FIRST_TIME=0
APP_VERSION=$1
if ! kubectl get configmap blue-green-status -n expense > /dev/null 2>&1; then
    echo "First deployment detected! Creating ConfigMap and deploying Blue..."
    kubectl create configmap blue-green-status  -n expense --from-literal=live-version="blue"
    PREVIEW_VERSION="blue"
    FIRST_TIME=1
    sed -i -e "s/BLUE_VERSION/$APP_VERSION/g" values.yaml
else
    CURRENT_VERSION=$(kubectl get configmap blue-green-status -n expense -o=jsonpath='{.data.live-version}')
    echo "Current Version: $CURRENT_VERSION"
    if [ "$CURRENT_VERSION" == "blue" ]; then
        PREVIEW_VERSION="green"
        sed -i -e "s/GREEN_VERSION/$APP_VERSION/g" values.yaml
    else
        #NEW_VERSION="blue"
        PREVIEW_VERSION="blue"
        sed -i -e "s/BLUE_VERSION/$APP_VERSION/g" values.yaml
    fi
fi
helm upgrade --install nginx . --set service.previewVersion=$PREVIEW_VERSION
helm status nginx
if [ $FIRST_TIME -ne 1 ]; then
    kubectl run test-healthcheck --rm -i --restart=Never --image=k8s.gcr.io/busybox -- /bin/sh -c "wget -qO- http://nginx-preview"
    if [ $? -ne 0 ]; then
        helm rollback nginx
        if [ $? -ne 0 ]; then
            echo "rollback success, but deployment failed"
            exit 1
        else
            echo "rollback failed and deployment failed"
            exit 1
        fi
    else
        echo "preview success"
        kubectl patch service nginx -p '{"spec":{"selector":{"version":"'$PREVIEW_VERSION'"}}}'
        kubectl patch configmap blue-green-status -n expense --type merge -p '{"data":{"live-version":"'$PREVIEW_VERSION'"}}'
        echo "Current running version: $PREVIEW_VERSION"
    fi
else
    echo "First deployment"
    helm status nginx
    if [ $? -ne 0 ]; then
        echo "first time deployment, can't rollback"
        exit 1
    else
        echo "Current running version: $PREVIEW_VERSION"
    fi
fi
