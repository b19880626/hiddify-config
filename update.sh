#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

cd $( dirname -- "$0"; )

function get_commit_version(){
    COMMIT_URL=$(curl -s https://api.github.com/repos/hiddify/$1/git/refs/heads/main|jq -r .object.url)
    VERSION=$(curl -s $COMMIT_URL|jq -r .committer.date)
    echo ${VERSION:5:11}
}

function main(){
    rm -rf sniproxy
    rm -rf caddy
    ./hiddify-panel/backup.sh
    UPDATE=0
    if [[ "$1" == "" ]];then
        PACKAGE_MODE=$(cd hiddify-panel;python3 -m hiddifypanel all-configs|jq -r ".hconfigs.package_mode")
        FORCE=false
    else
        PACKAGE_MODE=$1
        FORCE=true
    fi
    
    if [[ "$PACKAGE_MODE" == "1develop" ]];then
        echo "you are in develop mode"
        LATEST=$(get_commit_version HiddifyPanel)
        INSTALL_DIR=$(pip show hiddifypanel |grep Location |awk -F": " '{ print $2 }')
        CURRENT=$(cat $INSTALL_DIR/hiddifypanel/VERSION)
        echo "DEVLEOP: hiddify panel version current=$CURRENT latest=$LATEST"
        if [[ FORCE == "true" || "$LATEST" != "$CURRENT" ]];then
            pip3 uninstall -y hiddifypanel
            pip3 install -U git+https://github.com/hiddify/HiddifyPanel
            echo $LATEST>$INSTALL_DIR/hiddifypanel/VERSION
            echo "__version__='$LATEST'">$INSTALL_DIR/hiddifypanel/VERSION.py
            UPDATE=1
        fi
    else 
        CURRENT=`pip3 freeze |grep hiddifypanel|awk -F"==" '{ print $2 }'`
        LATEST=`lastversion hiddifypanel --at pip`
        echo "hiddify panel version current=$CURRENT latest=$LATEST"
        if [[ FORCE == "true" || "$CURRENT" != "$LATEST" ]];then
            echo "panel is outdated! updating...."
            pip3 install -U hiddifypanel
            UPDATE=1
        fi
    fi

    
    
    CURRENT_CONFIG_VERSION=$(cat VERSION)
    if [[ "$PACKAGE_MODE" == "develop" ]];then
        LAST_CONFIG_VERSION=$(get_commit_version hiddify-config)
        echo "DEVELOP: Current Config Version=$CURRENT_CONFIG_VERSION -- Latest=$LAST_CONFIG_VERSION"
        if [[ FORCE == "true" || "$CURRENT_CONFIG_VERSION" != "$LAST_CONFIG_VERSION" ]];then
            wget -c https://github.com/hiddify/hiddify-config/archive/refs/heads/main.tar.gz
            rm  -rf nginx/ xray/
            tar xvzf main.tar.gz --strip-components=1
            rm main.tar.gz
            echo $LAST_CONFIG_VERSION > VERSION

            bash install.sh
            UPDATE=1
        fi
    else 
        LAST_CONFIG_VERSION=$(lastversion hiddify/hiddify-config)
        echo "Current Config Version=$CURRENT_CONFIG_VERSION -- Latest=$LAST_CONFIG_VERSION"
        if [[ FORCE == "true" || "$CURRENT_CONFIG_VERSION" != "$LAST_CONFIG_VERSION" ]];then
            echo "Config is outdated! updating..."
            wget -c $(lastversion hiddify/hiddify-config --source)
            rm  -rf nginx/ xray/
            tar xvzf hiddify-config-v$LAST_CONFIG_VERSION.tar.gz --strip-components=1
            rm hiddify-config-v$LAST_CONFIG_VERSION.tar.gz
            bash install.sh
            UPDATE=1
        fi
    fi
    if [[ $UPDATE == 0 ]];then
        echo "---------------------Finished!------------------------"
    fi
    if [[ "$CURRENT" != "$LATEST" ]];then
        systemctl restart hiddify-panel
    fi
}

mkdir -p log/system/
main $@|& tee log/system/update.log