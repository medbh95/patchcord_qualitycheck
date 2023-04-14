import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'mqtt_manager.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String myText = '';
  MQTTManager manager = MQTTManager(
    host: "",
    topic: "mqtt/patchcord",
    identifier: "flutter_patchcord",
  );
  final brokerAddressController = TextEditingController();
  void _configureAndConnect(String host) {
    manager = MQTTManager(
      host: host,
      topic: "mqtt/patchcord",
      identifier: "flutter_patchcord",
    );

    manager.initializeMQTTClient();

    manager.connect();
  }

  void _disconnect() {
    manager.disconnect();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(46, 133, 247, 1),
        centerTitle: true,
        title: Text(
          'PatchCord Quality Check',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 23,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: brokerAddressController,
              decoration: InputDecoration(
                labelText: 'MQTT Broker Address',
              ),
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              child: Text('Connect'),
              onPressed: () async {
                final brokerAddress = brokerAddressController.text;

                if (brokerAddress.isEmpty) {
                  setState(() {
                    manager.connectionStatusIcon = Icons.error;
                    manager.connectionStatusText =
                        'Please enter the MQTT broker address.';
                  });
                  return;
                }

                try {
                  _configureAndConnect(brokerAddress);
                  setState(() {
                    manager.connectionStatusIcon = Icons.check_circle;
                    manager.connectionStatusText = 'Connected';
                  });
                  print('connected');
                } catch (e) {
                  setState(() {
                    manager.connectionStatusIcon = Icons.error;
                    manager.connectionStatusText = 'Error: $e';
                  });
                  print('Error: $e');
                }
              },
            ),
            SizedBox(height: 16.0),
            Row(
              children: [
                IconButton(
                  icon: Icon(manager.connectionStatusIcon),
                  onPressed: null,
                ),
                SizedBox(width: 8.0),
                Text(manager.connectionStatusText),
              ],
            ),
            SizedBox(height: 16.0),
            Expanded(
              child: Center(
                child: Text(manager.msg),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void deactivate() {
    _disconnect();

    super.deactivate();
  }
}
