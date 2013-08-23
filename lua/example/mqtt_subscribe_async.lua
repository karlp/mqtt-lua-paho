#!/usr/bin/lua
--
-- mqtt_subscribe.lua
-- ~~~~~~~~~~~~~~~~~~
-- Version: 0.2 2012-06-01
-- ------------------------------------------------------------------------- --
-- Copyright (c) 2011-2012 Geekscape Pty. Ltd.
-- All rights reserved. This program and the accompanying materials
-- are made available under the terms of the Eclipse Public License v1.0
-- which accompanies this distribution, and is available at
-- http://www.eclipse.org/legal/epl-v10.html
--
-- Contributors:
--    Andy Gelme - Initial implementation
-- -------------------------------------------------------------------------- --
--
-- Description
-- ~~~~~~~~~~~
-- Subscribe to an MQTT topic and display any received messages.
-- Uses the async api to avoid having to call :handler manually all the time
-- and maintains the connection automatically
--
-- References
-- ~~~~~~~~~~
-- Lapp Framework: Lua command line parsing
--   http://lua-users.org/wiki/LappFramework
--
-- ToDo
-- ~~~~
-- None, yet.
-- ------------------------------------------------------------------------- --

function callback(
  topic,    -- string
  message)  -- string

  print("Topic: " .. topic .. ", message: '" .. message .. "'")
end

-- ------------------------------------------------------------------------- --

function is_openwrt()
  return(os.getenv("USER") == "root")  -- Assume logged in as "root" on OpenWRT
end

-- ------------------------------------------------------------------------- --

print("[mqtt_subscribe v0.2 2012-06-01]")

--if (not is_openwrt()) then require("luarocks.require") end
local lapp = require("pl.lapp")

local args = lapp [[
  Subscribe to a specified MQTT topic
  -d,--debug                                Verbose console logging
  -H,--host          (default localhost)    MQTT server hostname
  -i,--id            (default mqtt_sub)     MQTT client identifier
  -k,--keepalive     (default 60)           Send MQTT PING period (seconds)
  -p,--port          (default 1883)         MQTT server port number
  -t,--topic         (string)               Subscription topic
  -w,--will_message  (default .)            Last will and testament message
  -w,--will_qos      (default 0)            Last will and testament QOS
  -w,--will_retain   (default 0)            Last will and testament retention
  -w,--will_topic    (default .)            Last will and testament topic
]]

local MQTT = require("mqtt_library")

if (args.debug) then MQTT.Utility.set_debug(true) end

if (args.keepalive) then MQTT.client.KEEP_ALIVE_TIME = args.keepalive end

local mqtt_client = MQTT.client.create(args.host, args.port, callback)


function do_connect()
    local err
    if (args.will_message == "."  or  args.will_topic == ".") then
        err = mqtt_client:connect(args.id)
    else
        err = mqtt_client:connect(
            args.id, args.will_topic, args.will_qos,
            args.will_retain, args.will_message
        )
    end
    if not err then 
        print("do connect got first: err=", err)
        err = mqtt_client:subscribe({args.topic})
    end
    print("do connect final: err=", err)
    -- two nils here means everything was fine!
    return err
end

do_connect()

function stay_connected()
    local connected = true
    while (true) do
        ok, result = pcall(function()
            local handler_result = mqtt_client:handler()
            print("handler returned: ", tostring(handler_result))
            return handler_result
        end)
        print(string.format("handler pcall gave us result=%s, ok=%s", tostring(result), tostring(ok)))
        coroutine.yield()
        if not ok then connected = false end
        if result then connected = false end
        while (not connected) do
            print("we got an err", err)
            ok, result = pcall(function()
                return do_connect()
            end)
            print(string.format("do_connect pcall returned: ok=%s, result=%s", tostring(ok), tostring(result)))
            if not ok then connected = false end
            if result then connected = false end
            coroutine.yield()
        end
    end
end

local error_message = nil

local co = coroutine.create(stay_connected)
while (true) do
    xx = coroutine.resume(co)
    socket.sleep(0.5)
    print(string.format("co.status() = %s", coroutine.status(co)))
end 

if (error_message == nil) then
  mqtt_client:unsubscribe({args.topic})
  mqtt_client:destroy()
else
  print(error_message)
end

-- ------------------------------------------------------------------------- --
