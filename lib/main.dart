import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sdp_transform/sdp_transform.dart';
import 'package:get/get.dart' hide navigator;
import 'package:socket_io_client/socket_io_client.dart' as IO;

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _localVideoRenderer = RTCVideoRenderer();
  final _remoteVideoRenderer = RTCVideoRenderer();
  final sdpController = TextEditingController();
  final svUrl = 'http://192.168.1.39'; //192.168.1.121
  late IO.Socket socket;
  bool _isAnswered = false;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  final Map<String, dynamic> offerSdpConstraints = {
    "mandatory": {
      "OfferToReceiveAudio": false,
      "OfferToReceiveVideo": true,
    },
    "optional": [],
  };

  initRenderer() async {
    await _localVideoRenderer.initialize();
    await _remoteVideoRenderer.initialize();
  }

  _getUserMedia() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'facingMode': 'user',
      }
    };

    MediaStream stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

    _localVideoRenderer.srcObject = stream;
    return stream;
  }

  _createPeerConnecion() async {
    Map<String, dynamic> configuration = {
      'iceServers': [
        {
          'urls': [
            'stun:stun1.l.google.com:19302',
            'stun:stun2.l.google.com:19302'
          ]
        }
      ]
    };

    _localStream = await _getUserMedia();

    RTCPeerConnection pc =
    await createPeerConnection(configuration, offerSdpConstraints);

    pc.addStream(_localStream!);

    pc.onIceCandidate = (e) {
      if (e.candidate != null) {
        socket.emit('candidate', e.toMap());
        print('Candidate Emit ${e.sdpMLineIndex}');
      }
    };
    pc.onIceConnectionState = (e) {
      print('onIceConnectionState $e');
    };


    pc.onAddStream = (stream) {
       print('addStream:  ${stream.id}');
       print('Tracks : ${stream.getTracks()}');
      _remoteVideoRenderer.srcObject = stream;
      //_remoteVideoRenderer.srcObject!.addTrack(stream.getTracks()[0],addToNative: false);
      setState(() {

      });
      print('Tracks : ${stream.getTracks()}');
    };

    return pc;
  }

  void _createOffer() async {
    RTCSessionDescription description =
    await _peerConnection!.createOffer({'offerToReceiveVideo': 1,'OfferToReceiveAudio':0});
    var session = parse(description.sdp.toString());
    print(json.encode(session));
    socket.emit('offer', session);
    //socketListener();
    _peerConnection!.setLocalDescription(description);
  }

  void _createAnswer() async {
    RTCSessionDescription description = await _peerConnection!.createAnswer({'offerToReceiveVideo': 1,'OfferToReceiveAudio':0});
    var session = parse(description.sdp.toString());
    print(json.encode(session));
    log(json.encode(session));
    _peerConnection!.setLocalDescription(description);
    //socketListener();
    socket.emit('answer', session);
    print('Answer Created');
  }

  void _setRemoteDescription(Map<String,dynamic> data, bool offerType) async {
    if(!offerType) {
      _isAnswered = true;
    }
    String sdp = write(data, null);
    print(offerType ? 'Remote description Offer':'Remote description Answer');
    RTCSessionDescription description = RTCSessionDescription(sdp, offerType ? 'offer' : 'answer');
    print(description.toMap());

    await _peerConnection!.setRemoteDescription(description);
    _peerConnection!.onAddStream = (stream) {
    print('addStream:  ${stream.id}');
    _remoteVideoRenderer.srcObject = stream;
    };
    //socketListener();
  }

  void _addCandidate(Map<String,dynamic> data) async {
    // if(!_isCandidateAdded) {
      print('_addCandidate Adding Candidate');
      dynamic session = JsonConvert(candidate: data['candidate'], sdpMid:data['sdpMid'], sdpMLineIndex : data['sdpMLineIndex']).toJson();

      print('_addCandidate Session: $session');
      dynamic candidate = RTCIceCandidate(
          session['candidate'], session['sdpMid'], session['sdpMLineIndex']);
      await _peerConnection!.addCandidate(candidate);
      print('Candidate added $candidate');
    //}
  }

  void _addCandidateManually() async {
    print('_addCandidateManually Adding Candidate');
    String jsonString = sdpController.text;
    Map<String,dynamic> session = await jsonDecode(jsonString);
    print('Session _addCandidateManually $session');
    //print(data);
    //print('_addCandidateManually Candidate added ${session["candidate"] ${session[""]}');
    dynamic candidate = RTCIceCandidate(
        session['candidate'], session['sdpMid'], session['sdpMLineIndex']);
    await _peerConnection!.addCandidate(candidate);

  }

  @override
  void initState() {
    socket = IO.io('$svUrl:3478', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    socket.connect();
    initRenderer();
    _createPeerConnecion().then((pc) {
      _peerConnection = pc;

    });
    socketListener();
    // _getUserMedia();
    super.initState();
  }

  @override
  void dispose() async {
    await _localVideoRenderer.dispose();
    sdpController.dispose();
    super.dispose();
  }

  SizedBox videoRenderers() => SizedBox(
        height: 210,
        child: Row(children: [
          Flexible(
            child: Container(
              key: const Key('local'),
              margin: const EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
              decoration: const BoxDecoration(color: Colors.black),
              child: RTCVideoView(_localVideoRenderer),
            ),
          ),
          Flexible(
            child: Container(
              key: const Key('remote'),
              margin: const EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
              decoration: const BoxDecoration(color: Colors.black),
              child: RTCVideoView(_remoteVideoRenderer),
            ),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          centerTitle: false,
          actions: [
            ElevatedButton(
              onPressed: _createOffer,
              child: const Text("Offer"),
              style: ElevatedButton.styleFrom(primary: Colors.purple),
            ),
            const SizedBox(
              height: 10,
            ),
            ElevatedButton(
              onPressed: _createAnswer,
              child: const Text("Answer"),
              style: ElevatedButton.styleFrom(primary: Colors.green),
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              videoRenderers(),
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: MediaQuery
                          .of(context)
                          .size
                          .width * 0.3,
                      child: TextField(
                        controller: sdpController,
                        keyboardType: TextInputType.multiline,
                        maxLines: 4,
                        maxLength: TextField.noMaxLength,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(
                        height: 10,
                      ),
                      ElevatedButton(
                        onPressed: _addCandidateManually,
                        child: const Text("Add candidate manually"),
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                    ],
                  )
                ],
              ),
            ],
          ),
        ));
  }

  void socketListener() {
    socket.on('offer-received', (data) {
      print('got offer \n $data');
      _setRemoteDescription(data, true);
    });

    socket.on('answer-received', (data) {
      print('got answer \n $data');
      _setRemoteDescription(data, false);
    });

      socket.on('candidate-sent', (data) {
        print('got Candidate \n $data');
        print('Is offer Answered :$_isAnswered');
        //if(_isAnswered && !_isCandidateAdded) {
          if(_isAnswered) {
            _addCandidate(data);
          }
        //}
        });
  }
}

class JsonConvert {
   String? candidate;
   String? sdpMid;
   int? sdpMLineIndex;

  JsonConvert({this.candidate, this.sdpMid ,this.sdpMLineIndex});

  JsonConvert.fromJson(Map<String, dynamic> json)
      : candidate = json['candidate'],
       sdpMid = json['sdpMid'],
        sdpMLineIndex = json['sdpMlineIndex'];

  Map<String, dynamic> toJson() {
    return {
      'candidate': candidate,
      'sdpMid': sdpMid,
      'sdpMLineIndex':sdpMLineIndex
    };
  }
}
