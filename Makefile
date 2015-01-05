#!/bin/bash

all: compile

compile:
	node ./node_modules/.bin/coffee --output lib --compile --bare src
