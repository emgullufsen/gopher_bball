#!/bin/bash

if [ $# -gt 0 ]
then
    echo "number of args is $# whic is less than 2"
else
    echo "not greater, ($#)."
fi

if [ $1 = "hey" ]
then
    echo "you wrote hey"
else
    echo "did not write that"
fi

echo $1