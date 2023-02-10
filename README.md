tcl-mqtt
========

Small library to connect to a  
[MQTT](http://mqtt.org) broker. Very, very basic.
Publish only, Qos 0, retained, timeout 30s

Usage:
```
package require mqtt 1.0
set mqtt_id "1Wire"
set mqtt_conn [mqtt connect localhost 1883 $mqtt_id]
set topic "/1wire/temperatures"
set reading "22.5"
mqtt publish $mqtt_conn $topic $reading
mqtt disconnect $mqtt_conn
```
