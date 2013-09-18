#!/bin/bash


while true 
do
    mosquitto_pub -h test.mosquitto.org -t /rsm.ie/fits/detectors -f payload.txt 
    sleep 1 
done
