#!/bin/bash


llpip=`host llp | awk '{print $4}'`
sudo ip address add $llpip/24 dev lo

