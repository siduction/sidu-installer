#! /bin/bash
python ../sidu-base/util/configurationbuilder.py -v --summary --drop-tables --prefix=sidu-base data/config.db ../sidu-base/config
python ../sidu-base/util/configurationbuilder.py -v --summary --prefix=sidu-installer data/config.db config

