import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'mqtt_manager.dart';

class RaspberryMQTT extends StatefulWidget {
  const RaspberryMQTT({super.key});

  @override
  State<RaspberryMQTT> createState() => _RaspberryMQTTState();
}

class _RaspberryMQTTState extends State<RaspberryMQTT> {
  String myText = '';

  final mqttClient = MqttClient('broker.mqtt.com', '');
  MQTTClientManager mqttClientManager = MQTTClientManager();
  final String pubTopic = "mqtt/pimylifeup";
  final brokerAddressController = TextEditingController();

  IconData connectionStatusIcon = Icons.warning;
  String connectionStatusText = 'Not Connected';
  @override
  void initState() {
    setupMqttClient();
    setupUpdatesListener();
    super.initState();
  }

  Future<void> setupMqttClient() async {
    await mqttClientManager.connect();
    mqttClientManager.subscribe(pubTopic);
  }

  void setupUpdatesListener() {
    mqttClientManager
        .getMessagesStream()!
        .listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final recMess = c![0].payload as MqttPublishMessage;
      final pt =
          MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      print('MQTTClient::Message received on topic: <${c[0].topic}> is $pt\n');
    });
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
                    connectionStatusIcon = Icons.error;
                    connectionStatusText =
                        'Please enter the MQTT broker address.';
                  });
                  return;
                }

                mqttClient.disconnect();

                try {
                  await mqttClient.connect(brokerAddress, '');
                  mqttClient.subscribe('mqtt/pimylifeup', MqttQos.exactlyOnce);
                  setState(() {
                    connectionStatusIcon = Icons.check_circle;
                    connectionStatusText = 'Connected';
                  });
                  print('Connected');
                } catch (e) {
                  setState(() {
                    connectionStatusIcon = Icons.error;
                    connectionStatusText = 'Error: $e';
                  });
                  print('Error: $e');
                }
              },
            ),
            SizedBox(height: 16.0),
            Row(
              children: [
                IconButton(
                  icon: Icon(connectionStatusIcon),
                  onPressed: null,
                ),
                SizedBox(width: 8.0),
                Text(connectionStatusText),
              ],
            ),
            SizedBox(height: 16.0),
            Expanded(
              child: Center(
                child: Text(myText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
