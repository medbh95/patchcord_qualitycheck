class Strings {
  static const String appTitle = 'PatchCord Quality Check';
  static const String connectedMsg = "Connected";
  static const String promptTitle =
      'Enter your Raspberry Pi IP Address and connect';
  static const String adressEmptyMsg = 'Please enter your Raspberry Pi Address';
  static const String ipIncorrectMsg = 'Invalid IP address format';
  static const String inputLabel = 'MQTT Broker Address';
  static const String inputHint = 'Enter the MQTT broker address';
  static const String connectText = 'Connect';
  static const String disconnectText = 'Disconnect';
  static const String statusDiconnectedText = 'Disconnected';
  static const String statusConnectedText = 'Connected';
  static const String continueText = 'Continue';
  static const String retrytext = 'Retry';
  static const String canceltext = 'Cancel';
  static String resultMsg(String message) => 'PatchCord Quality is : $message';
  static const String detectQualityText = 'Detect Quality';

  static const String predictTfliteMsg =
      "Prediction Using TensorFlow Lite Model";
  static const String predictRPImsg = "Prediction Using Rapsberry PI H5 Model";
  static const String predictResultmsg = "Prediction Results";
  static const String predictDonemsg = "Prediction done";
  static const String uploadImageText = 'Upload Image';
  static const String pickGalleryText = 'Pick From Gallery';
}
