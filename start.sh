#!/bin/bash

erl +K true +A30 -noshell -pa ebin -s spot_check -s init stop
 
