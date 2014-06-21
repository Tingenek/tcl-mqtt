# Register the package
package provide mqtt 1.0
package require Tcl  8.5

# MQTT Utilities
# Small library of routines for mqtt comms.
# Everything here practises Safe HEX
# Mark Lawson 2012 for llama kind everywhere.
# BTW, some of this stuff only makes sense if you have the MQTT v3 spec handy.
#

namespace eval ::mqtt {
    # Export commands
    namespace export connect publish disconnect
    namespace ensemble create
    # Set up state
    variable stack
    variable state
}

#Connect to the broker and return a handle
proc ::mqtt::connect {{s localhost} {p 1883} {c "Ousterhout"}} {
variable state
set state waiting
#10sec timeout
set id [after 10000 set state timeout]
set sock [socket $s $p]
fconfigure $sock -blocking 0 -buffering none -encoding binary -translation binary
fileevent $sock readable {set state reading} 
set c [::mqtt::simpleconnect $c]
sendhex $sock $c
vwait state
set state [::mqtt::readhex $sock]
fileevent $sock readable ""
catch {after cancel $id}
#Check for CONNACK.Connected
if {$state == "20020000"} {
    return $sock
    } else {
    catch {close $sock}
    return -code 1 "Connect failed: $state"
    }
}

proc ::mqtt::publish {sock topic message} {
#just topic as utf8 - using qos 0
set publish [::mqtt::getutf8 $topic]
#payload plain - not utf8
append publish [::mqtt::ashex $message]
set publen [expr [string length $publish] / 2 ]
set pubhex "[format %02X [expr 3 << 4]][::mqtt::encode128 $publen]$publish"
sendhex $sock $pubhex
return 0
}

proc ::mqtt::disconnect {sock} {
#send DISCONNECT cmd
catch {::mqtt::sendhex $sock e000}
catch {close $sock}
}

#UTF8 encoder
#Simple len+hex
proc ::mqtt::getutf8 {s} {
set l [format %04x [string length $s]]
binary scan $s H* a
return "$l$a"
}

#Remaining length encoder
#Returns up to 4 hex bytes for a given length.
proc ::mqtt::encode128 {{in_num 0}} {
set n 0	
set result 0
#split into 128 blocks	
for {set x $in_num} {$x > 0} {set x [expr $x / 128]} {
	#get remainder, add 128 if not first, left shift 1 byte.
	incr result [expr (($x % 128) + ($x != $in_num?128:0)) * (256 ** $n )]
	incr n
}
return [format %02x $result]	
}

#Simple connection string
#Takes a connection Name
#No flags, no Will, Clean Start and a 30 sec timer.
proc ::mqtt::simpleconnect {conn_name} {
#variable header
#some fixed text as utf8
set connect [::mqtt::getutf8 "MQIsdp"]
#protocol version no
append connect [format %02x 3]
#connect flags - just clean start set
append connect [format %02x 2]
#keep alive timer - use 30 secs
append connect [format %04x 30]
#payload
#connection name 1 to 23 chars as utf8
append connect [::mqtt::getutf8 $conn_name]
#length of hex string /2
set connlen [expr [string length $connect] / 2 ]
set connect "[format %02x [expr 1 << 4]][::mqtt::encode128 $connlen]$connect"
return $connect
}

proc ::mqtt::sendhex {s h} {
puts -nonewline $s [binary format H* $h]
flush $s
}

proc ::mqtt::readhex {sock} {
	global state
    set hex_data ""
    set bin_data [read $sock]
    if {[eof $sock]} {
    	close $sock
    }    
    catch {binary scan $bin_data H* hex_data}        ;# Practice safe hex!
    set state $hex_data
 }
 
#Simple string2hex
proc ::mqtt::ashex {s} {
set hex ""
catch {binary scan $s H* hex}
return $hex
} 

