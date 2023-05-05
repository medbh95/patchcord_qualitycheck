import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:better_file_md5_plugin/better_file_md5_plugin.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite/tflite.dart';
import 'dart:convert';
import 'dart:async';
import 'package:convert/convert.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class PatchCordQualityCheck extends StatefulWidget {
  @override
  _PatchCordQualityCheckState createState() => _PatchCordQualityCheckState();
}

class _PatchCordQualityCheckState extends State<PatchCordQualityCheck> {
  int _currentStep = 0;
  late MqttServerClient client;
  bool connected = false;
  String status = 'Disconnected';
  String message = '';
  int? _selectedValue;
  bool _isUpToDate = false;
  final picker = ImagePicker();
  File? _imageFile;
  bool imageUploaded = false;
  bool showResult = false;
  bool checkingUpdates = false;
  bool shouldDownload = false;
  bool downloading = false;
  TextEditingController addressController = TextEditingController();
  double _progress = 0.0;
  String _fileName = '';
  var modelChecksum = "";
  bool connecting = false;
  late List _output;
  bool uploading = false;
  bool predicting = false;
  final _formKey = GlobalKey<FormState>();
  String _ipAddress = '';
// Regular expression to validate IP address
  RegExp ipRegExp = RegExp(
      r'^([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])$');
  Future<void> requestStoragePermission() async {
    final permissionStatus = await Permission.storage.request();
    if (permissionStatus != PermissionStatus.granted) {
      throw Exception('Storage permission not granted');
    }
  }

  @override
  void initState() {
    super.initState();
    check();
    requestStoragePermission();
    _loadLastValue();
    //loadTfliteModel();
  }

  loadTfliteModel() async {
    final loadResult = await loadModel();
    if (loadResult) {
      print("Model loaded successfully");
    } else {
      print("Failed to load model after downloading");
    }
  }

  check() async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String modelPath = '${appDocDir.path}/model.tflite';

    if (File(modelPath).existsSync()) {
      print('Model file exists in the app document directory.$modelPath');
    } else {
      print(
          'Model file does not exist in the app document directory.$modelPath');
    }
  }

  _loadLastValue() async {
    final prefs = await SharedPreferences.getInstance();
    final lastValue = prefs.getString('lastValue') ?? '';
    addressController.text = lastValue;
    _ipAddress = lastValue;
  }

  void _saveValue(String value) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('lastValue', value);
  }

  @override
  void dispose() {
    super.dispose();
    Tflite.close();
  }

  classifyImage() async {
    if (_imageFile != null) {
      setState(() {
        predicting = true;
        showResult = false;
      });
      var output = await Tflite.runModelOnImage(
        path: _imageFile!.path,
        numResults: 5,
        threshold: 0.5,
        imageMean: 127.5,
        imageStd: 127.5,
      );
      setState(() {
        _output = output!;
        predicting = false;
        showResult = true;
        message = _output[0]['label'];
      });
    }
  }

  Future<bool> loadModel() async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String modelPath = '${appDocDir.path}/model.tflite';

    if (File(modelPath).existsSync()) {
      print('Model file exists in the app document directory.$modelPath');
      try {
        await Tflite.loadModel(
          model: "assets/model.tflite",
          labels: 'assets/labels.txt',
        );
        return true;
      } catch (e) {
        print('Error loading model: $e');
        return false;
      }
    } else {
      print(
          'Model file does not exist in the app document directory.$modelPath');
      return false;
    }
  }

  _pickImageCamera() async {
    var image = await picker.pickImage(source: ImageSource.camera);
    if (image == null) return null;

    setState(() {
      _imageFile = File(image.path);
    });
    // classifyImage(_image);
  }

  Future<void> _pickImageGallery() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _checkFiles() async {
    final appDirectory = await getApplicationDocumentsDirectory();
    final savePath = appDirectory.path + '/model.tflite';
    final file = File(savePath);
    final md5 = await BetterFileMd5.md5(file.path);

    if (!await file.exists()) {
      print("exist");
      setState(() {
        shouldDownload = true;
      });
    } else if (md5 != null) {
      print("not exist");
      var hexMd5 = hex.encode(base64Decode(md5));
      print("_checkFiles");
      print(hexMd5);
      return hexMd5;
    }
    return shouldDownload ? null : '';
  }

  Future<String?> getModelHash() async {
    final String url = 'http://$_ipAddress:8000/check_files';
    final dio = Dio();

    try {
      final response = await dio.get(url);
      if (response.statusCode == 200) {
        final data = response.data;
        final modelHash = data['model_hash'];
        print("getModelHash");
        print(modelHash);
        return modelHash;
      }
    } catch (e) {
      print('Error retrieving model hash: $e');
    }

    return null;
  }

  Future<bool> _downloadFile() async {
    Dio dio = Dio();
    setState(() {
      downloading = true;
    });
    final appDirectory = await getApplicationDocumentsDirectory();
    final savePath = appDirectory.path + '/model.tflite';
    final url = 'http://$_ipAddress:8000/download_model';
    final response = await dio.download(
      url,
      savePath,
      onReceiveProgress: (received, total) {
        if (total != -1) {
          setState(() {
            _progress = (received / total);
          });
        }
      },
    );
    if (response.statusCode == 200) {
      setState(() {
        _fileName = 'model.tflite';
        downloading = false;
        shouldDownload = false;
        _isUpToDate = true;
      });
      final loadResult = await loadModel();
      if (loadResult) {
        print("Model loaded successfully");
      } else {
        print("Failed to load model after downloading");
      }
      print("file downloaded successfully");
      return true; // file downloaded successfully
    } else {
      print("file download failed");

      return false; // file download failed
    }
  }

  Future<void> checkAndDownloadFile() async {
    final localHash = await _checkFiles();
    final apiHash = await getModelHash();
    print(localHash);
    print(apiHash);
    if (localHash != null && apiHash != null) {
      if (localHash != apiHash) {
        print("model deprecated downloading ...");
        setState(() {
          shouldDownload = true;
        });
      } else {
        print("model up to date");
        setState(() {
          _isUpToDate = true;
        });
        final loadResult = await loadModel();
        if (loadResult) {
          print("Model loaded successfully");
        } else {
          print("Failed to load model after downloading");
        }
      }
    }
  }

  void showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: Colors.white),
        ),
        duration: Duration(milliseconds: 1000),
        backgroundColor: color,
      ),
    );
  }

  void connect() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        connecting = true;
      });
      String broker = addressController.text;
      client = MqttServerClient(broker, 'flutter_client');
      client.onConnected = onConnected;
      client.onDisconnected = onDisconnected;
      client.onSubscribed = onSubscribed;
      client.onUnsubscribed = onUnsubscribed;
      client.onSubscribeFail = onSubscribeFail;
      client.logging(on: true);
      final connMessage = MqttConnectMessage()
          .authenticateAs('pi', '0000')
          .withClientIdentifier('flutter_client')
          .keepAliveFor(60)
          .startClean()
          .withWillTopic('willtopic')
          .withWillMessage('My will message')
          .withWillRetain()
          .withWillQos(MqttQos.atLeastOnce);
      client.connectionMessage = connMessage;
      try {
        await client.connect();
        setState(() {
          connecting = false;
        });
      } catch (e) {
        print('Exception: $e');
        client.disconnect();
        showSnackBar(context, "Disconnected", Colors.red);
        setState(() {
          connecting = false;
        });
      }
    }
  }

  void onConnected() {
    print('Connected');
    showSnackBar(context, "Connected", Colors.green);

    setState(() {
      connecting = false;
      connected = true;
      status = 'Connected';
    });
    client.subscribe('topic', MqttQos.atMostOnce);
    client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final recMess = c![0].payload as MqttPublishMessage;
      final pt =
          MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      print('Received message: topic is ${c[0].topic}, payload is $pt');
      setState(() {
        showResult = true;
        message = pt;
      });
    });
  }

  void onDisconnected() {
    print('Disconnected');
    showSnackBar(context, "Disconnected", Colors.red);
    setState(() {
      connecting = false;
      connected = false;
      showResult = false;
      status = 'Disconnected';
      message = "";
      _imageFile = null;
      imageUploaded = false;
      _currentStep = 0;
      predicting = false;
      _isUpToDate = false;
      shouldDownload = false;
      downloading = false;
    });
  }

  void onSubscribed(String topic) {
    print('Subscribed to $topic');
  }

  void onUnsubscribed(String? topic) {
    print('Unsubscribed from $topic');
  }

  void onSubscribeFail(String topic) {
    print('Failed to subscribe to $topic');
  }

  void disconnect() {
    client.disconnect();
  }

  void showMessage(String topic, String payload) {
    print('Message received on $topic: $payload');
    setState(() {
      message = payload;
    });
  }

  Future<void> _uploadImage() async {
    if (_imageFile == null) {
      return;
    }

    try {
      setState(() {
        uploading = true;
      });
      final dio = Dio();
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(_imageFile!.path),
      });
      final response = await dio.post(
        'http://$_ipAddress:8000/upload',
        data: formData,
      );

      if (response.statusCode == 200) {
        print('Image uploaded successfully');
        showSnackBar(context, "Image uploaded successfully", Colors.green);
        setState(() {
          imageUploaded = true;
          uploading = false;
        });
      } else {
        setState(() {
          uploading = false;
        });
        print('Failed to upload image');
        showSnackBar(context, "Failed to upload image", Colors.red);
      }
    } catch (e) {
      setState(() {
        uploading = false;
      });
      print('Error uploading image: $e');
      showSnackBar(context, "'Error uploading image: $e'", Colors.red);
    }
  }

  Future<void> _runScript() async {
    try {
      setState(() {
        predicting = true;
        showResult = false;
      });
      final dio = Dio();
      final response = await dio.post(
        'http://$_ipAddress:8000/run-script',
      );

      if (response.statusCode == 200) {
        print('Script executed successfully');
        showSnackBar(context, "Prediction Complete", Colors.green);
        setState(() {
          predicting = false;
        });
      } else {
        print('Failed to execute script');
        showSnackBar(context, "Failed to execute script", Colors.red);
        setState(() {
          predicting = false;
        });
      }
    } catch (e) {
      print('Error executing script: $e');
      showSnackBar(context, "'Error executing script: $e'", Colors.red);
      setState(() {
        predicting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60.0),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20.0),
            topRight: Radius.circular(20.0),
            bottomLeft: Radius.circular(20.0),
            bottomRight: Radius.circular(20.0),
          ),
          child: AppBar(
            backgroundColor: Colors.cyan,
            title: Text('PatchCord Quality Check'),
            centerTitle: true,
            elevation: 0.0,
          ),
        ),
      ),
      body: Container(
        child: Column(
          children: [
            Expanded(
              child: Theme(
                data: ThemeData(
                  colorScheme: ColorScheme.light(
                    primary: Colors.green, // change the primary color
                    onPrimary: Colors.white, // change the text color on primary
                  ),
                ),
                child: Stepper(
                  type: StepperType.vertical,
                  physics: ScrollPhysics(),
                  currentStep: _currentStep,
                  onStepContinue: continued,
                  onStepCancel: cancel,
                  controlsBuilder:
                      (BuildContext context, ControlsDetails controlsDetails) {
                    return Container();
                  },
                  steps: <Step>[
                    Step(
                      title: Text(_currentStep >= 1
                          ? "Connected"
                          : 'Enter your Raspberry Pi IP Address and connect'),
                      content: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Form(
                            key: _formKey,
                            child: Column(
                              children: <Widget>[
                                TextFormField(
                                  onChanged: (value) {
                                    _ipAddress = value.trim();
                                    print(_ipAddress);
                                    _saveValue(_ipAddress);
                                  },
                                  validator: (value) {
                                    if (!connected &&
                                        (value == null || value.isEmpty)) {
                                      return 'Please enter your Raspberry Pi Address';
                                    } else if (!connected &&
                                        !ipRegExp.hasMatch(value!)) {
                                      return 'Invalid IP address format';
                                    }
                                    return null;
                                  },
                                  controller: addressController,
                                  decoration: InputDecoration(
                                    labelText: 'MQTT Broker Address',
                                    hintText: 'Enter the MQTT broker address',
                                  ),
                                ),
                                SizedBox(height: 10.0),
                                Container(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          connected ? Colors.red : Colors.green,
                                      elevation: 5,
                                    ),
                                    onPressed: connected ? disconnect : connect,
                                    child: Text(
                                        connected ? 'Disconnect' : 'Connect'),
                                  ),
                                ),
                                SizedBox(height: 10.0),
                              ],
                            ),
                          ),
                          connecting
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      color: Colors.cyan,
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Icon(
                                      connected
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      color:
                                          connected ? Colors.green : Colors.red,
                                    ),
                                    SizedBox(width: 10.0),
                                    Text(status),
                                  ],
                                ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      connected ? Colors.cyan : Colors.grey,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  elevation: 5, //  / set the text color
                                ),
                                onPressed: connected ? continued : () {},
                                child: Text('Continue'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      isActive: _currentStep >= 0,
                      state: _currentStep >= 1
                          ? StepState.complete
                          : StepState.disabled,
                    ),
                    Step(
                      title: Text(_currentStep >= 2
                          ? _selectedValue == 1
                              ? "TensorFlow Lite"
                              : "Raspberry Pi H5"
                          : 'Prediction Method'),
                      content: Column(
                        children: [
                          Text(
                              ' Chose how you would like to predict cable quality ?'),
                          RadioListTile<int>(
                            title: Text(' Tensor Flow Lite Model'),
                            value: 1,
                            groupValue: _selectedValue,
                            onChanged: (int? value) {
                              setState(() {
                                _selectedValue = value;
                              });
                            },
                          ),
                          RadioListTile<int>(
                            title: Text('Raspberry Pi H5 Model'),
                            value: 2,
                            groupValue: _selectedValue,
                            onChanged: (int? value) {
                              setState(() {
                                _selectedValue = value;
                              });
                            },
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _selectedValue != null
                                      ? Colors.cyan
                                      : Colors.grey,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  elevation: 5, //  / set the text color
                                ),
                                onPressed:
                                    _selectedValue != null ? continued : () {},
                                child: Text('Continue'),
                              ),
                              SizedBox(
                                width: 20,
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.cyan,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  elevation: 5, //  / set the text color
                                ),
                                onPressed: cancel,
                                child: Text('Cancel'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      isActive: _currentStep >= 1,
                      state: _currentStep >= 2
                          ? StepState.complete
                          : StepState.disabled,
                    ),
                    Step(
                      title: new Text(_selectedValue == 1
                          ? _currentStep >= 3
                              ? "Model Up to Date"
                              : "Check And Download Model"
                          : _currentStep >= 3
                              ? "Image Selected"
                              : "Select Image From Gallery"),
                      content: _selectedValue == 1
                          ? Column(
                              children: <Widget>[
                                if (shouldDownload && !downloading)
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.cancel,
                                          color: Colors.red,
                                        ),
                                        SizedBox(width: 10.0),
                                        Text(
                                            "Model is Deprecated or Not Found"),
                                      ],
                                    ),
                                  ),
                                _isUpToDate
                                    ? Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              color: Colors.green,
                                            ),
                                            SizedBox(width: 10.0),
                                            Text("Model is Up To Date"),
                                          ],
                                        ),
                                      )
                                    : Column(children: [
                                        if (_progress > 0)
                                          Column(
                                            children: [
                                              LinearProgressIndicator(
                                                value: _progress,
                                                color: Colors.cyan,
                                              ),
                                              SizedBox(
                                                height: 20,
                                              ),
                                              Text(
                                                  'Downloading $_fileName: ${(_progress * 100).toStringAsFixed(0)}%'),
                                              SizedBox(
                                                height: 20,
                                              ),
                                            ],
                                          ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    shouldDownload ||
                                                            downloading
                                                        ? Colors.grey
                                                        : Colors.cyan,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                elevation:
                                                    5, //  / set the text color
                                              ),
                                              onPressed:
                                                  shouldDownload || downloading
                                                      ? () {}
                                                      : checkAndDownloadFile,
                                              child: Row(
                                                children: [
                                                  Icon(Icons.refresh),
                                                  Text('Check For Update'),
                                                ],
                                              ),
                                            ),
                                            SizedBox(
                                              width: 10,
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: downloading
                                                    ? Colors.grey
                                                    : shouldDownload
                                                        ? Colors.cyan
                                                        : Colors.grey,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                elevation:
                                                    5, //  / set the text color
                                              ),
                                              onPressed: downloading
                                                  ? () {}
                                                  : shouldDownload
                                                      ? _downloadFile
                                                      : () {},
                                              child: Row(
                                                children: [
                                                  Icon(Icons.download),
                                                  Text('Download'),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ]),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _isUpToDate
                                            ? Colors.cyan
                                            : Colors.grey,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        elevation: 5, //  / set the text color
                                      ),
                                      onPressed:
                                          _isUpToDate ? continued : () {},
                                      child: Text('Continue'),
                                    ),
                                    SizedBox(
                                      width: 20,
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: downloading
                                            ? Colors.grey
                                            : Colors.cyan,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        elevation: 5, //  / set the text color
                                      ),
                                      onPressed: downloading ? () {} : cancel,
                                      child: Text('Cancel'),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                if (_imageFile != null) ...[
                                  ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Image.file(
                                        _imageFile!,
                                        fit: BoxFit.fill,
                                        width: 200,
                                        height: 200,
                                      )),
                                  SizedBox(height: 10),
                                ],
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.cyan,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          elevation: 5, //  / set the text color
                                        ),
                                        onPressed: _pickImageGallery,
                                        child: Text('Select From Gallery'),
                                      ),
                                    ]),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _imageFile != null
                                            ? Colors.cyan
                                            : Colors.grey,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        elevation: 5, //  / set the text color
                                      ),
                                      onPressed: _imageFile != null
                                          ? continued
                                          : () {},
                                      child: Text('Continue'),
                                    ),
                                    SizedBox(
                                      width: 20,
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: downloading
                                            ? Colors.grey
                                            : Colors.cyan,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        elevation: 5, //  / set the text color
                                      ),
                                      onPressed: downloading ? () {} : cancel,
                                      child: Text('Cancel'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                      isActive: _currentStep >= 2,
                      state: _currentStep >= 3
                          ? StepState.complete
                          : StepState.disabled,
                    ),
                    Step(
                      title: new Text(_selectedValue == 1
                          ? _currentStep >= 4
                              ? "Image Selected"
                              : "Select Image From Gallery"
                          : _currentStep >= 4
                              ? "Image Uploaded"
                              : "Upload Image"),
                      content: _selectedValue == 1
                          ? Column(
                              children: [
                                if (_imageFile != null) ...[
                                  ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Image.file(
                                        _imageFile!,
                                        fit: BoxFit.fill,
                                        width: 200,
                                        height: 200,
                                      )),
                                  SizedBox(height: 10),
                                ],
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.cyan,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          elevation: 5, //  / set the text color
                                        ),
                                        onPressed: _pickImageGallery,
                                        child: Text('Select From Gallery'),
                                      ),
                                    ]),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _imageFile != null
                                            ? Colors.cyan
                                            : Colors.grey,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        elevation: 5, //  / set the text color
                                      ),
                                      onPressed: _imageFile != null
                                          ? continued
                                          : () {},
                                      child: Text('Continue'),
                                    ),
                                    SizedBox(
                                      width: 20,
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: downloading
                                            ? Colors.grey
                                            : Colors.cyan,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        elevation: 5, //  / set the text color
                                      ),
                                      onPressed: downloading ? () {} : cancel,
                                      child: Text('Cancel'),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Column(
                              children: <Widget>[
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: uploading
                                              ? Colors.grey
                                              : Colors.cyan,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          elevation: 5, //  / set the text color
                                        ),
                                        onPressed:
                                            uploading ? () {} : _uploadImage,
                                        child: Row(
                                          children: [
                                            Icon(Icons.upload),
                                            Text('Upload Image'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: !imageUploaded
                                            ? Colors.grey
                                            : Colors.cyan,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        elevation: 5, //  / set the text color
                                      ),
                                      onPressed:
                                          !imageUploaded ? () {} : continued,
                                      child: Text('Continue'),
                                    ),
                                    SizedBox(
                                      width: 20,
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.cyan,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        elevation: 5, //  / set the text color
                                      ),
                                      onPressed: cancel,
                                      child: Text('Cancel'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                      isActive: _currentStep >= 3,
                      state: _currentStep >= 4
                          ? StepState.complete
                          : StepState.disabled,
                    ),
                    Step(
                      title: new Text(_selectedValue == 1
                          ? showResult
                              ? "Prediction done"
                              : "Prediction Results"
                          : _currentStep >= 4
                              ? "Prediction done"
                              : "Prediction Results"),
                      content: Column(
                        children: <Widget>[
                          Text(_selectedValue == 1
                              ? "Prediction Using TensorFlow Lite Model"
                              : "Prediction Using Rapsberry PI H5 Model"),
                          SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      predicting ? Colors.grey : Colors.cyan,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  elevation: 5, //  / set the text color
                                ),
                                onPressed: predicting
                                    ? () {}
                                    : _selectedValue == 1
                                        ? () async {
                                            await classifyImage();
                                          }
                                        : _runScript,
                                child: Row(
                                  children: [
                                    Icon(Icons.search),
                                    Text('Detect Quality'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20.0),
                          predicting
                              ? CircularProgressIndicator(
                                  color: Colors.cyan,
                                )
                              : Container(),
                          showResult
                              ? Text(
                                  "Cable Quality is : $message",
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 27),
                                )
                              : Container(),
                          SizedBox(height: 20.0),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  predicting ? Colors.grey : Colors.cyan,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 5, //  / set the text color
                            ),
                            onPressed: predicting
                                ? () {}
                                : () {
                                    cancel();

                                    setState(() {
                                      showResult = false;
                                      message = "";
                                    });
                                  },
                            child: Text('Cancel'),
                          ),
                        ],
                      ),
                      isActive: _currentStep >= 4,
                      state: _currentStep >= 5
                          ? StepState.complete
                          : StepState.disabled,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  continued() {
    _currentStep < 5 ? setState(() => _currentStep += 1) : null;
  }

  cancel() {
    _currentStep > 0 ? setState(() => _currentStep -= 1) : null;
  }
}
