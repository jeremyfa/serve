#!/bin/bash

haxe test-nodejs.hxml
cd out/test-nodejs && node test-server.js
