#!/bin/bash

mkdir -p /opt/gpu-board
cat > /opt/gpu-board/start-server.sh << EOF
docker run --detach --runtime nvidia --pid host \
    --name gpu-board-server \
    --restart always \
    --volume /etc/passwd:/etc/passwd:ro \
    --publish 8000:8000 \
    huww98/gpu-board-server
EOF
chmod +x /opt/gpu-board/start-server.sh

if docker ps | grep -q "gpu-board-server"
then
    echo gpu-board-server Already deployed.
    echo Will update and restart
    docker pull huww98/gpu-board-server
    docker rm -f gpu-board-server
fi

/opt/gpu-board/start-server.sh
