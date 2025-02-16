export CORE_PEER_TLS_ENABLED=true
export ORDERER_CA=${PWD}/artifacts/channel/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export PEER0_ORG1_CA=${PWD}/artifacts/channel/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export PEER0_ORG2_CA=${PWD}/artifacts/channel/crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export PEER0_ORG3_CA=${PWD}/artifacts/channel/crypto-config/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
export FABRIC_CFG_PATH=${PWD}/artifacts/channel/config/

export CHANNEL_NAME=mychannel

setGlobalsForPeer0Org1(){
    export CORE_PEER_LOCALMSPID="Org1MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG1_CA
    export CORE_PEER_MSPCONFIGPATH=${PWD}/artifacts/channel/crypto-config/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=localhost:7051
}

setGlobalsForPeer0Org2(){
    export CORE_PEER_LOCALMSPID="Org2MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG2_CA
    export CORE_PEER_MSPCONFIGPATH=${PWD}/artifacts/channel/crypto-config/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
    export CORE_PEER_ADDRESS=localhost:9051
    
}

setGlobalsForPeer0Org3(){
    export CORE_PEER_LOCALMSPID="Org3MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG3_CA
    export CORE_PEER_MSPCONFIGPATH=${PWD}/artifacts/channel/crypto-config/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
    export CORE_PEER_ADDRESS=localhost:11051
    
}

createChannel(){
    # First ensure channel-artifacts exists with correct permissions
    sudo rm -rf ./channel-artifacts
    mkdir -p ./channel-artifacts
    sudo chown -R $USER:$USER ./channel-artifacts
    sudo chmod -R 755 ./channel-artifacts
    
    setGlobalsForPeer0Org1
    
    # Add a longer delay to ensure orderer is fully ready
    echo "Waiting for orderer to start...."
    sleep 15
    
    # Add retry logic for channel creation
    MAX_RETRY=5
    DELAY=10
    COUNTER=1
    
    while [ $COUNTER -le $MAX_RETRY ]; do
        echo "Attempting to create channel (attempt $COUNTER of $MAX_RETRY)"
        
        peer channel create -o localhost:7050 -c $CHANNEL_NAME \
        --ordererTLSHostnameOverride orderer.example.com \
        -f ./artifacts/channel/mychannel.tx \
        --outputBlock ./channel-artifacts/${CHANNEL_NAME}.block \
        --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA
        
        if [ $? -eq 0 ]; then
            echo "Channel created successfully"
            break
        fi
        
        COUNTER=$((COUNTER + 1))
        echo "Channel creation failed. Waiting $DELAY seconds before retry"
        sleep $DELAY
    done
    
    if [ $COUNTER -gt $MAX_RETRY ]; then
        echo "Channel creation failed after $MAX_RETRY attempts"
        exit 1
    fi
    
    # Ensure the created block file has correct permissions
    sudo chown -R $USER:$USER ./channel-artifacts/${CHANNEL_NAME}.block
    sudo chmod 755 ./channel-artifacts/${CHANNEL_NAME}.block
}

removeOldCrypto(){
    rm -rf ./api-1.4/crypto/*
    rm -rf ./api-1.4/fabric-client-kv-org1/*
    rm -rf ./api-2.0/org1-wallet/*
    rm -rf ./api-2.0/org2-wallet/*
}


joinChannel(){
    setGlobalsForPeer0Org1
    peer channel join -b ./channel-artifacts/$CHANNEL_NAME.block
    
    
    setGlobalsForPeer0Org2
    peer channel join -b ./channel-artifacts/$CHANNEL_NAME.block
    
    setGlobalsForPeer0Org3
    peer channel join -b ./channel-artifacts/$CHANNEL_NAME.block
    
}

updateAnchorPeers(){
    setGlobalsForPeer0Org1
    peer channel update -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com -c $CHANNEL_NAME -f ./artifacts/channel/${CORE_PEER_LOCALMSPID}anchors.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA
    
    setGlobalsForPeer0Org2
    peer channel update -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com -c $CHANNEL_NAME -f ./artifacts/channel/${CORE_PEER_LOCALMSPID}anchors.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA

    setGlobalsForPeer0Org3
    peer channel update -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com -c $CHANNEL_NAME -f ./artifacts/channel/${CORE_PEER_LOCALMSPID}anchors.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA
    
}

removeOldCrypto

createChannel
joinChannel
updateAnchorPeers