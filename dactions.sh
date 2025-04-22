#!/bin/sh

startdc(){
docker start $1
}

stopdc(){
docker stop $1
}

restartdc(){
docker restart $1
}

list_running_docker_containers(){
echo "Listing all the docker services"
echo "------"
docker ps -a
}

select_docker_operation(){
list_running_docker_containers
echo "----"
echo ""
read -p "Please enter the operation: " docker_operation
read -p "Please enter the container name: " containerName

if [ $docker_operation = "start" ]
then
	echo "Starting the container $containerName"
	startdc $containerName
fi

if [ $docker_operation = "stop" ]   
then
	echo "Stopping the container $containerName"
	 stopdc $containerName
fi

if [ $docker_operation = "restart" ]
then
	echo "Restarting the container $containerName"
	restartdc $containerName
fi
}

select_docker_operation
echo "Task $docker_operation $containerName complete"

