#!/bin/bash

haxe test-php.hxml
cd out/test-php && php -S localhost:8000 index.php
