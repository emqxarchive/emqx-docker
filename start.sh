#!/bin/sh
# Emqttd start script
echo 'Emqttd docker image for Device++'
echo 'Vowstar Co.,Ltd. <support@vowstar.com>'
echo 'This script is under MIT license'

SELF_HOST=$(hostname)
SELF_IP=$(cat /etc/hosts | grep ${SELF_HOST} | awk '{print $1}')

sed -i -e "s/^-name\s*.*@.*/-name emqttd@${SELF_IP}/g" /opt/emqttd/etc/vm.args

/opt/emqttd/bin/emqttd start

WAIT_TIME=0
# wait and ensure emqttd status is running
while [ x$(/opt/emqttd/bin/emqttd_ctl status |grep 'is running'|awk '{print $1}') = x ]
do
    sleep 1
    echo '['$(date -u +"%Y-%m-%dT%H:%M:%SZ")']:waiting emqttd'
    WAIT_TIME=`expr ${WAIT_TIME} + 1`
    if [ ${WAIT_TIME} -gt 5 ]
    then
        echo '['$(date -u +"%Y-%m-%dT%H:%M:%SZ")']:timeout error'
        exit 1
    fi
done

echo '['$(date -u +"%Y-%m-%dT%H:%M:%SZ")']:emqttd start'

if [ x$EMQTTD_REMOTE_HOST != x ]
then
    REMOTE_HOST=$EMQTTD_REMOTE_HOST
    echo 'use remote host:'${REMOTE_HOST}
fi

if [ x$1 != x ]
then
    REMOTE_HOST=$1
    echo 'use remote host:'${REMOTE_HOST}
fi

echo 'emqttd@'${SELF_IP}

if [ x$REMOTE_HOST != x ]
then
    REMOTE_IP=$(cat /etc/hosts | grep ${REMOTE_HOST} | awk '{print $1}')
    if [ x$REMOTE_IP = x ]
    then
        REMOTE_IP=$REMOTE_HOST
        echo 'local network not have remote host:'${REMOTE_HOST}
    fi
    echo '['$(date -u +"%Y-%m-%dT%H:%M:%SZ")']:join emqttd@'${REMOTE_IP}
    /opt/emqttd/bin/emqttd_ctl cluster join 'emqttd@'${REMOTE_IP}
else
    if [ x$REMOTE_IP != x ] && [ $REMOTE_IP != $SELF_IP ]
    then
        echo '['$(date -u +"%Y-%m-%dT%H:%M:%SZ")']:join emqttd@'${REMOTE_IP}
        /opt/emqttd/bin/emqttd_ctl cluster join 'emqttd@'${REMOTE_IP}
    fi
fi

IDLE_TIME=0
while [ x$(/opt/emqttd/bin/emqttd_ctl status |grep 'is running'|awk '{print $1}') != x ]
do  
    IDLE_TIME=`expr ${IDLE_TIME} + 1`
    echo '['$(date -u +"%Y-%m-%dT%H:%M:%SZ")']:emqttd running'
    DOCKER_IP_LIST=$(cat /etc/hosts |grep -v -E 'localhost|ip6-localnet|ip6-mcastprefix|ip6-allnodes|ip6-allrouters'|awk '{print $1}')
    CLUSTER_IP_LIST=$(/opt/emqttd/bin/emqttd_ctl cluster status|grep -E -oh '((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])')
    for TARGET_IP in $DOCKER_IP_LIST
    do
        if [ x$(echo $CLUSTER_IP_LIST|grep -oh $TARGET_IP) = x ]
        then
            REMOTE_IP=${TARGET_IP}
            echo '['$(date -u +"%Y-%m-%dT%H:%M:%SZ")']:link server '${REMOTE_IP} 
            echo '['$(date -u +"%Y-%m-%dT%H:%M:%SZ")']:join emqttd@'${REMOTE_IP}
            /opt/emqttd/bin/emqttd_ctl cluster join 'emqttd@'${REMOTE_IP}
        fi
    done
    CLUSTER_IP_COUNT=$(echo ${CLUSTER_IP_LIST} | grep -E -oh '((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])' | wc -l)       
    if [ ${IDLE_TIME} -lt 100 ]                                                                                                                                    
    then                                                                                                                                                                
        echo '['$(date -u +"%Y-%m-%dT%H:%M:%SZ")']:discover emqtt service'  
        echo ${CLUSTER_IP_LIST} | socat - udp-datagram:255.255.255.255:32491,broadcast                                                                                                 
    fi
    sleep 2                                                                                                                                                                  
    sleep $((RANDOM%${CLUSTER_IP_COUNT}))
    DOCKER_IP_LIST=$(echo $(timeout -t 9 socat - udp-listen:32491,reuseaddr) | grep -E -oh '((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])')
    DOCKER_IP_COUNT=$(echo ${DOCKER_IP_LIST} | grep -E -oh '((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])' | wc -l)  
    if [ ${CLUSTER_IP_COUNT} -le ${DOCKER_IP_COUNT} ]   
    then
        for TARGET_IP in $DOCKER_IP_LIST
        do
            if [ x$(echo $CLUSTER_IP_LIST|grep -oh $TARGET_IP) = x ]
            then
                REMOTE_IP=${TARGET_IP}
                echo '['$(date -u +"%Y-%m-%dT%H:%M:%SZ")']:find server '${REMOTE_IP} 
                echo '['$(date -u +"%Y-%m-%dT%H:%M:%SZ")']:join emqttd@'${REMOTE_IP}
                /opt/emqttd/bin/emqttd_ctl cluster join 'emqttd@'${REMOTE_IP}
                IDLE_TIME=0
            fi
        done
    fi
done

tail $(ls /opt/emqttd/log/*)

echo '['$(date -u +"%Y-%m-%dT%H:%M:%SZ")']:emqttd stop'