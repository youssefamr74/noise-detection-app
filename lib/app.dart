import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoder/geocoder.dart';
import 'package:record_mp3/record_mp3.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info/device_info.dart';
import 'package:firebase_database/firebase_database.dart';
class NoiseApp extends StatefulWidget {
  @override
  _NoiseAppState createState() => _NoiseAppState();
}

class _NoiseAppState extends State<NoiseApp> {
  bool _isRecording = false;
  StreamSubscription<NoiseReading> _noiseSubscription;
  NoiseMeter _noiseMeter;
  double maxDB;
  double meanDB;
  List<_ChartData> chartData = <_ChartData>[];
  ChartSeriesController _chartSeriesController;
  int previousMillis;
  var locationMessage = "";
  var position;
  String recordFilePath;
  var date;
  var lat;
  var long;
  var sec;
  Timer _countDown;
  var _recordeddB;
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  var IOSInfo;
  var androidInfo;
  Duration _duration = new Duration(seconds: 60);
  TooltipBehavior _tooltipBehavior;
  void getCurrentLocation() async{
    position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
     lat = position.latitude;
     long = position.longitude;
    setState(() {
      locationMessage = "Latitude : $lat , Longitude : $long";
    });
  }

  @override
  void initState() {
    super.initState();
    _tooltipBehavior = TooltipBehavior(enable: true);
    _noiseMeter = NoiseMeter(onError);
  }


  void _startRec () async{
    recordFilePath = await getFilePath();
    RecordMp3.instance.start(recordFilePath, (type) {
      setState(() {});
    });
     Timer(Duration(seconds: 10), () async{
       RecordMp3.instance.stop();
       if(_recordeddB != null && _recordeddB > 80) {
         _upload(recordFilePath);
       }
    });
  }
  void onData(NoiseReading noiseReading) {
    this.setState(() {
      if (!this._isRecording) this._isRecording = true;
    });
    maxDB = noiseReading.maxDecibel;
    meanDB = noiseReading.meanDecibel;
    chartData.add(
      _ChartData(
        maxDB,
        meanDB,
        ((DateTime.now().millisecondsSinceEpoch - previousMillis) / 1000)
            .toDouble(),
      ),
    );
  }
 void onError(PlatformException e) {
    print(e.toString());
    _isRecording = false;
  }
  void start() async {
    previousMillis = DateTime
        .now()
        .millisecondsSinceEpoch;
    try {
      getCurrentLocation();
        _noiseSubscription = _noiseMeter.noiseStream.listen(onData);
      final coordinates = new Coordinates(lat, long);
      var addresses = await Geocoder.local.findAddressesFromCoordinates(
          coordinates);
      var first = addresses.first;
      var name = "${first.addressLine}";
      /*if(Platform.isAndroid) {
        androidInfo = await deviceInfo.androidInfo;
      }*/
     /* if(Platform.isIOS) {
        IOSInfo = await deviceInfo.iosInfo;
      }*/
      try {
        if (Platform.isAndroid) {
          androidInfo = await deviceInfo.androidInfo;
        }
        /*if (Platform.isIOS) {
          IOSInfo = await deviceInfo.iosInfo;
        }*/
      } on PlatformException {
        androidInfo =  "Unknown";
        };
  var android = androidInfo.model;
  //var IOS = IOSInfo.model;
      Future.delayed(Duration.zero, () async {
        _startRec();
        print("started recording");
          sec = DateTime.now().second;
          date = DateTime.now().toString();
          if(meanDB != null)
          _recordeddB = meanDB;
         /* await databaseRef.push().set({
            'DB': _recordeddB,
            'Location coordinates': '$lat , $long',
            'Location Address': name,
            'Date': date,
            'Running on': android
          });*/
          await FirebaseFirestore.instance.collection("extra-data").add({
            'DB': _recordeddB != null ? _recordeddB.toString() : 0,
            'Location coordinates': '$lat , $long',
            'Location Address': name,
            'Date': date,
            'Running on': android
          });
      });
     _countDown = Timer.periodic(_duration, (timer) async {
          if (this._isRecording == true) {
            _startRec();
          date = DateTime.now().toString();
            if(meanDB != null)
              _recordeddB = meanDB;
       /* await databaseRef.push().set({
            'DB': _recordeddB,
            'Location coordinates': '$lat , $long',
            'Location Address': name,
            'Date': date,
            'Running on' : android
          });*/
          await FirebaseFirestore.instance.collection("extra-data").add({
            'DB': _recordeddB != null ? _recordeddB.toString() : 0,
            'Location coordinates': '$lat , $long',
            'Location Address': name,
            'Date': date,
            'Running on':  android
          });

        }
          else {
            timer.cancel();
          }
      });

    } catch (e) {
      print(e);
    }
  }
  void restartTimer()async {
    if(_countDown !=null){
      _countDown.cancel();
    }
  }
  void _upload (var x)async{
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();
     await FirebaseStorage.instance.ref().child('$lat,$long-${date}-recorded.mp3').putFile(File(x));
  }
  void stop() async {
    try {
      if (_noiseSubscription != null) {
        _noiseSubscription.cancel();
        _noiseSubscription = null;
      }
      restartTimer();
      this.setState(() => this._isRecording = false);
    } catch (e) {
      print('stopRecorder error: $e');
    }
    previousMillis = 0;
    chartData.clear();
  }

  @override
  Widget build(BuildContext context) {
    bool _isDark = Theme.of(context).brightness == Brightness.dark;
    if (chartData.length >= 25) {
      chartData.removeAt(0);
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _isDark ? Colors.black54 : Colors.blueGrey,
        title: Text('Noise Detector'),
        actions: [

          IconButton(
            tooltip: 'Copy value to clipboard',
            icon: Icon(Icons.copy),
            onPressed: maxDB != null
                ? () {
              Clipboard.setData(
                ClipboardData(
                    text:
                    'It\'s about ${maxDB.toStringAsFixed(1)}dB loudness with location $locationMessage'),
              ).then((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(milliseconds: 2500),
                    content: Row(
                      children: [
                        Icon(
                          Icons.check,
                          size: 14,
                          color: _isDark ? Colors.black : Colors.blue,
                        ),
                        SizedBox(width: 10),
                        Text('Copied')
                      ],
                    ),
                  ),
                );
              });
            }
                : null,
          )
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        label: Text(_isRecording ? 'Stop' : 'Start') ,
        onPressed:  _isRecording ? stop : start  ,
        icon: !_isRecording ? Icon(Icons.audiotrack) : Icon(Icons.stop_circle),
        backgroundColor: _isDark? Colors.white : Colors.blueAccent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.all( 30.0),
              child: Center(
                child: Text(
                  maxDB != null ?  maxDB.toStringAsFixed(0) + ' dB' : 'Press start',
                  style : GoogleFonts.markaziText(
                    textStyle : TextStyle(color : _isDark? Colors.white: Colors.blueAccent, fontSize: 70, fontWeight: FontWeight.bold),
                ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only( left : 30.0 , top: 30.0 , bottom: 15.0),
                child : Center (
                child : Container (
                child: new LinearPercentIndicator(
                  width: 300.0,
                  lineHeight: 25.0,
                  percent:maxDB != null ? maxDB <= 120? (maxDB/120) : 1.0 : 0,
                  //center: Text(
                    //maxDB != null ?  maxDB.toStringAsFixed(0) : "0",
                    //style: new TextStyle(fontSize: 20.0),
                  //),
                  trailing: Icon( maxDB == null ?  FontAwesome5.smile :
                      maxDB <= 60? FontAwesome5.smile : maxDB <=85 ? FontAwesome5.meh : FontAwesome5.frown
                      , size: 25,
                    color : _isDark ? Colors.white : Colors.blueGrey,
                  ),
                  linearStrokeCap: LinearStrokeCap.round,
                  backgroundColor: _isDark ?Colors.grey : Colors.white,
                  progressColor: maxDB == null? Colors.grey : (maxDB <= 60? Colors.greenAccent :(
                  maxDB <= 85 ?  Colors.amber : Colors.red))
                  ,
                ),
              ),
                ),
            ),
            Text(
              meanDB != null
                  ? 'Mean: ${meanDB.toStringAsFixed(2)}'
                  : 'Awaiting data',
              style: GoogleFonts.poppins(
                textStyle : TextStyle( color : _isDark? Colors.white : Colors.blueGrey,fontWeight: FontWeight.w300, fontSize: 14),
            ),
            ),
            Padding(
              padding: EdgeInsets.only(top : 0.0 , bottom: 15.00),
             child : Center(
                child : Container(
              child: SfCartesianChart(
                tooltipBehavior: _tooltipBehavior,
                series: <LineSeries<_ChartData, double>>[
                  LineSeries<_ChartData, double>(
                      onRendererCreated: (ChartSeriesController controller) {
                        _chartSeriesController = controller;
                      },
                      dataSource: chartData,
                      xAxisName: 'Time',
                      yAxisName: 'dB',
                      name: 'dB values over time',
                      xValueMapper: (_ChartData value, _) =>  value.frames,
                      yValueMapper: (_ChartData value, _) => value.maxDB,
                      animationDuration: 0),

                ],
              ),
            ),
              ),
            ),
            RichText(
              text: TextSpan(
                children: [
                  WidgetSpan(
                    child: Icon(Icons.bar_chart, size: 20 , color : _isDark ? Colors.white : Colors.blueGrey) ,
                  ),
                  TextSpan(
                    text: meanDB != null
                        ? 'dB over time'
                        : '',
                    style: TextStyle( color : _isDark? Colors.white : Colors.blueGrey ,fontWeight: FontWeight.w300, fontSize: 14),
                  ),
                ],
              ),

            ),

            SizedBox(
              height: 40,
            ),

          ],
        ),

      ),
    );
  }
}

class _ChartData {
  final double maxDB;
  final double meanDB;
  final double frames;

  _ChartData(this.maxDB, this.meanDB, this.frames);
}
Future<String> getFilePath() async {
  int i =0;
  Directory storageDirectory = await getApplicationDocumentsDirectory();
  String sdPath = storageDirectory.path + "/record";
  var d = Directory(sdPath);
  if (!d.existsSync()) {
    d.createSync(recursive: true);
  }

  return sdPath + "/test_${i++}.mp3";
}