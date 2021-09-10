#!/bin/bash
set -e

if [[ ! $FLASH_SIZE ]]
then
    FLASH_SIZE=1M64
fi

if [[ ! -e "default_settings.h" ]]
then
    if [[ $(uname) == 'Darwin' ]]
    then
        printf "Name: "
        read -r name
        printf "Wifi SSID: "
        read -r wifi_ssid
        printf "Wifi password: "
        read -r wifi_password
        printf "MQTT server: "
        read -r mqtt_server
        printf "MQTT topic: "
        read -r mqtt_topic

        {
            echo "#define DEFAULT_SETTINGS"
            echo "#define NAME \"$name\""
            echo "#define WIFI_SSID \"$wifi_ssid\""
            echo "#define WIFI_PASS \"$wifi_password\""
            echo "#define MQTT_SERVER \"$mqtt_server\""
            echo "#define MQTT_TOPIC \"$mqtt_topic\""
        } > default_settings.h
        
    else
        echo "" > default_settings.h
    fi
fi

VERSION=$(git log --pretty=format:%h -n 1)
echo "#define VERSION \"$VERSION\"" > version.h

ARDUINO_IDE_VERSION=1.6.9
BUILD_DIR="build"

if [[ $(uname) == 'Darwin' ]]
then
    PLATFORM='macosx'
    FILE_EXT='zip'
    ARDUINO_DIR='Arduino.app/Contents/Java'
else
    PLATFORM='linux64'
    FILE_EXT='tar.xz'
    ARDUINO_DIR="arduino-$ARDUINO_IDE_VERSION"
fi

if [[ ! -e "$BUILD_DIR" ]]
then
    mkdir $BUILD_DIR
fi
cd $BUILD_DIR

if [[ ! -e "$ARDUINO_DIR" ]]
then
    ARDUINO_FILE=arduino-${ARDUINO_IDE_VERSION}-$PLATFORM.$FILE_EXT
    wget -O $ARDUINO_FILE http://arduino.cc/download.php?f=/$ARDUINO_FILE

    if [ ${FILE_EXT} == 'zip' ]
    then
        unzip $ARDUINO_FILE
    else
        tar xf $ARDUINO_FILE
    fi

    rm -f $ARDUINO_FILE
fi

if [[ ! -e "esp8266" ]]
then
    git clone https://github.com/esp8266/Arduino.git
    cd Arduino
    git checkout tags/2.4.2
    cd ..
    mv Arduino esp8266
    cd esp8266/tools
    python get.py
    cd ../../
fi

if [[ ! -e "makeEspArduino" ]]
then
    git clone https://github.com/plerup/makeEspArduino.git
fi

ESP_ROOT=$(pwd)/esp8266
export SINGLE_THREAD=1

if [[ ! -e "pubsubclient" ]]
then
git clone https://github.com/Imroy/pubsubclient
cp pubsubclient/src/* makeEspArduino/
fi

cd makeEspArduino

export SKETCH=mqtt-h801.ino
export UPLOAD_PORT=/dev/cu.usbserial-A92HD3JZ
export LIBS="$ESP_ROOT/libraries/ESP8266WiFi/ $ESP_ROOT/libraries/ESP8266WebServer/ $ESP_ROOT/libraries/ESP8266HTTPClient/ $ESP_ROOT/libraries/ESP8266httpUpdate/ ../pubsubclient/src/"
export FLASH_DEF=$FLASH_SIZE

cp ../../*.ino ../../*.h ../../*.cpp .

if [[ $(uname) == 'Darwin' ]]
then
    make -f makeEspArduino.mk upload
    screen $UPLOAD_PORT 115200
else
    make -f makeEspArduino.mk all
fi


cd ../../
if [[ ! -e "dist" ]]
then
    mkdir dist
fi
cp /tmp/mkESP/mqtt-h801_generic/mqtt-h801.bin dist/MQTT-H801.bin
