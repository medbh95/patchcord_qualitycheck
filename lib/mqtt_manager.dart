import 'package:mqtt_client/mqtt_client.dart';

import 'package:mqtt_client/mqtt_server_client.dart';

import 'package:flutter/material.dart';

class MQTTManager {
  MqttServerClient? _client;

  IconData connectionStatusIcon = Icons.warning;
  String connectionStatusText = 'Not Connected';
  final String _identifier;

  final String _host;

  final String _topic;
  String msg = "";
  MQTTManager({
    required String host,
    required String topic,
    required String identifier,
  })  : _identifier = identifier,
        _host = host,
        _topic = topic;

  void initializeMQTTClient() {
    _client = MqttServerClient(_host, _identifier);

    _client!.port = 1883;

    _client!.keepAlivePeriod = 20;

    _client!.onDisconnected = onDisconnected;

    _client!.secure = false;

    _client!.logging(on: true);

    _client!.onConnected = onConnected;

    _client!.onSubscribed = onSubscribed;

    final MqttConnectMessage connMess = MqttConnectMessage()
        .startClean() // Non persistent session for testing

        .withWillQos(MqttQos.atLeastOnce);

    print('Client connecting...');

    _client!.connectionMessage = connMess;
  }

  void connect() async {
    assert(_client != null);

    try {
      print('Starting to connect...');

      await _client!.connect();
    } on Exception catch (e) {
      print('Client exception - $e');

      disconnect();
    }
  }

  void disconnect() {
    print('Disconnected');

    _client!.disconnect();
  }

  void publish(String message) {
    final MqttClientPayloadBuilder builder = MqttClientPayloadBuilder();

    builder.addString(message);

    _client!.publishMessage(_topic, MqttQos.exactlyOnce, builder.payload!);
  }

  void onSubscribed(String topic) {
    print('Subscribed to topic $topic');
  }

  void onDisconnected() {
    print('Client disconnected');
  }

  void onConnected() {
    print('Connected to client');

    _client!.subscribe(_topic, MqttQos.atLeastOnce);

    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final MqttPublishMessage recMess = c![0].payload as MqttPublishMessage;

      final String pt =
          MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

      print('Topic is <${c[0].topic}>, payload is <-- $pt -->');
      msg = pt;
      print('');
    });

    print('Connection was successful');
  }
}
