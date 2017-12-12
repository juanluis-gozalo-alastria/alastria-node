#!/bin/bash
set -u
set -e

MESSAGE="Usage: init CURRENT_HOST_IP | auto"
if ( [ $# -ne 1 ] ); then
    echo "$MESSAGE"
    exit
fi

CURRENT_HOST_IP="$1"

if ( [ "auto" == "$1" ]); then 
    echo "Autodiscovering public host IP ..."
    CURRENT_HOST_IP="$(dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null || curl -s --retry 2 icanhazip.com)"
    echo "Public host IP found: $CURRENT_HOST_IP"
fi

PWD="$(pwd)"
CONSTELLATION_NODES=$(cat ../data/constellation-nodes.json)
STATIC_NODES=$(cat ../data/static-nodes.json)

generate_conf() {
   #define parameters which are passed in.
   NODE_IP="$1"
   CONSTELLATION_PORT="$2"
   OTHER_NODES="$3"
   PWD="$4"

   #define the template.
   cat  << EOF
# Externally accessible URL for this node (this is what's advertised)
url = "http://$NODE_IP:$CONSTELLATION_PORT/"

# Port to listen on for the public API
port = $CONSTELLATION_PORT

# Socket file to use for the private API / IPC
socket = "$PWD/alastria/data/constellation/constellation.ipc"

# Initial (not necessarily complete) list of other nodes in the network.
# Constellation will automatically connect to other nodes not in this list
# that are advertised by the nodes below, thus these can be considered the
# "boot nodes."
othernodes = $OTHER_NODES

# The set of public keys this node will host
publickeys = ["$PWD/alastria/data/constellation/keystore/node.pub"]

# The corresponding set of private keys
privatekeys = ["$PWD/alastria/data/constellation/keystore/node.key"]

# Optional file containing the passwords to unlock the given privatekeys
# (one password per line -- add an empty line if one key isn't locked.)
passwords = "$PWD/alastria/data/passwords.txt"

# Where to store payloads and related information
storage = "$PWD/alastria/data/constellation/data"

# Verbosity level (each level includes all prior levels)
#   - 0: Only fatal errors
#   - 1: Warnings
#   - 2: Informational messages
#   - 3: Debug messages
verbosity = 2

EOF
}

echo "[*] Cleaning up temporary data directories."
rm -rf ~/alastria
mkdir -p ~/alastria/data/{keystore,geth,constellation}
mkdir -p ~/alastria/data/constellation/{data,keystore}
mkdir -p ~/alastria/logs

# Creamos el fichero de passwords con la contraseña de las cuentas
echo "Passw0rd" > ~/alastria/data/passwords.txt

echo "[*] Initializing quorum"
geth --datadir ~/alastria/data init ~/alastria-node/data/genesis.json
cd ~/alastria/data/geth
bootnode -genkey nodekey
ENODE_KEY=$(bootnode -nodekey nodekey -writeaddress)
echo "ENODE -> 'enode://${ENODE_KEY}@${CURRENT_HOST_IP}:21000?raftport=41000'"
cd ~
if [[ "$CURRENT_HOST_IP" == "52.56.69.220" ]]; then
    cp ~/alastria-node/data/static-nodes.json ~/alastria/data/static-nodes.json
    cp ~/alastria-node/data/static-nodes.json ~/alastria/data/permissioned-nodes.json
fi

echo "     Por favor, introduzca como contraseña 'Passw0rd'."
geth --datadir ~/alastria/data account new

echo "[*] Initializing Constellation node."
generate_conf "${CURRENT_HOST_IP}" "9000" "$CONSTELLATION_NODES" "${PWD}" > ~/alastria/data/constellation/constellation.conf
cd ~/alastria/data/constellation/keystore
cat ~/alastria/data/passwords.txt | constellation-node --generatekeys=node
echo "______"
cd ~

echo "[*] Initialization was completed successfully."
echo " "
echo "      Update DIRECTORY.md from alastria-node repository and send a Pull Request."
echo "      The network administrator will send a RAFT_ID file. It will be stored in '~/alastria/data/' directory."
echo " "

set +u
set +e
