#!/bin/bash


while true 
do
    mosquitto_pub -h test.mosquitto.org -t /jack/says -f payload.txt 
    sleep 1 
done
