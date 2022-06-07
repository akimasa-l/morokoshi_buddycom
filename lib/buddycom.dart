// import 'dart:ffi';
import 'dart:math';
import 'dart:typed_data';
import "dart:async";
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;
import "dart:async";
import "fastmdct.dart";

class BuddycomButton extends StatefulWidget {
  const BuddycomButton({
    Key? key,
    /*  required this.channel */
  }) : super(key: key);
  /* final IOWebSocketChannel channel; */
  @override
  State<BuddycomButton> createState() => _BuddycomButtonState();
}

/// だいたいここからのコピペ
/// https://zenn.dev/pressedkonbu/books/flutter-reverse-lookup-dictionary/viewer/010-audi-streamer
class WavePainter extends CustomPainter {
  WavePainter({
    required this.samples,
    required this.constraints,
  });

  Size constraints;
  Float32List samples;
  static const color = Colors.blue;

  final uIntMax = pow(2, 8);

  @override
  void paint(Canvas canvas, Size size) {
    // 色、太さ、塗り潰しの有無などを指定
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // 得られたデータをオフセットのリストに変換する
    // やっていることは決められた範囲で等間隔に点を並べているだけ
    final points = toPoints(samples).toList();

    // addPolygon で path をつくり drawPath でグラフを表現する
    final path = Path()..addPolygon(points, false);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(oldDelegate) => true;

  // 得られたデータを等間隔に並べていく
  Iterable<Offset> toPoints(Float32List samples) sync* {
    final length = samples.length;
    final height = constraints.height;
    final width = constraints.width;
    for (final sample in samples.asMap().entries) {
      final y = sample.value * height;
      final x = sample.key / length * width;
      yield Offset(x, y);
    }
  }
}

class _BuddycomButtonState extends State<BuddycomButton> {
  static const EventChannel _recordChannel =
      EventChannel("com.morokoshi.audio.recorder");
  static const MethodChannel _playChannel =
      MethodChannel("com.morokoshi.audio.player");
  static final url = Uri(scheme: "ws", host: "54.151.30.235", port: 8080);
  late StreamSubscription _streamSubscription;
  Float32List buffer = Float32List.fromList([.1, .2, .3, .4]);
  Float32List compressed = Float32List.fromList([.0, .0, .0]);
  Float32List expanded = Float32List.fromList([.0, .0, .0]);
  List<Float32List> playList = [];
  late final IOWebSocketChannel channel;
  bool isRecording = false;
  var ans = 0.0;
  @override
  void initState() {
    super.initState();
    channel = IOWebSocketChannel.connect(url);
    channel.stream.listen((event) {
      if (!isRecording) {
        final data = (event as Uint8List).buffer.asFloat32List();
        setState(() {
          buffer = data;
        });
        () async {
          await _playChannel.invokeMethod("play", {"byte": data});
        }();
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    channel.sink.close(status.goingAway);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        GestureDetector(
          child: const MorokoshiButton(),
          onLongPressStart: (details) {
            debugPrint("long press start");
            _streamSubscription =
                _recordChannel.receiveBroadcastStream().listen(
              (event) {
                // debugPrint("event: $event");
                // debugPrint(event.runtimeType.toString());
                setState(() {
                  buffer = event as Float32List;
                  playList.add(buffer);
                  // debugPrint("buffer length : ${buffer.length}");
                  // compressed = FastMDCT.mdct(
                  //     buffer.length >> 1,
                  //     Vector.fromList(
                  //         Float32List.fromList([...buffer]) /* コピーする */)).data;
                  // expanded = FastMDCT.imdct(
                  //     compressed.length,
                  //     Vector.fromList(
                  //         Float32List.fromList([...compressed]))).data;
                  // playList.add(expanded);
                  channel.sink.add(buffer.buffer.asUint8List());
                  isRecording = true;
                });
                // debugPrint("event: $event");
              },
            );
          },
          onLongPressEnd: (details) {
            debugPrint("long press end");
            _streamSubscription.cancel();
            isRecording = false;
          },
        ),
        ElevatedButton(
          onPressed: () async {
            await _playChannel.invokeMethod("ready");
            for (final play in playList) {
              await _playChannel.invokeMethod("play", {"byte": play});
            }
          },
          child: const Text("play"),
        ),
        /* LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return CustomPaint(
              painter: WavePainter(
                samples: buffer,
                constraints: constraints,
              ),
            );
          },
        ), */
        /* CustomPaint(
          painter: WavePainter(
            samples: buffer,
            constraints: const BoxConstraints(maxHeight: 200, maxWidth: 200),
          ),
          willChange : true,
          size:const Size(200,200)
        ) */
        // const WavePainter2Test(),
        // const WavePainter1Test(),
        /* LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return CustomPaint(
              size: Size(200, constraints.maxWidth),
              painter: WavePainter(
                samples: buffer,
                constraints: BoxConstraints(maxWidth:constraints.maxWidth,maxHeight:200),
              ),
            );
          },
        ), */
        CustomPaint(
          size: const Size(100, 100),
          painter: WavePainter(
            samples: buffer,
            constraints: const Size(100, 100),
          ),
        ),
        CustomPaint(
          size: const Size(100, 100),
          painter: WavePainter(
            samples: compressed /* .map((i)=>log(i.abs())).toList() */,
            constraints: const Size(100, 100),
          ),
        ),
        CustomPaint(
          size: const Size(100, 100),
          painter: WavePainter(
            samples: expanded,
            constraints: const Size(100, 100),
          ),
        ),
      ],
    );
  }
}

class WavePainter2 extends CustomPainter {
  WavePainter2({
    required this.samples,
    required this.color,
    required this.constraints,
  });

  BoxConstraints constraints;
  Float32List samples;
  Color color;

  final _absMax = 1;
  static const _hightOffset = 0.5;

  @override
  void paint(Canvas canvas, Size size) {
    // 色、太さ、塗り潰しの有無などを指定
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // 得られたデータをオフセットのリストに変換する
    // やっていることは決められた範囲で等間隔に点を並べているだけ
    final points = toPoints(samples);

    // addPolygon で path をつくり drawPath でグラフを表現する
    final path = Path()..addPolygon(points, false);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(oldPainting) => true;

  // 得られたデータを等間隔に並べていく
  List<Offset> toPoints(Float32List samples) {
    final points = <Offset>[];
    for (var i = 0; i < (samples.length / 2); i++) {
      points.add(
        Offset(
          i / (samples.length / 2) * constraints.maxWidth,
          project(samples[i], _absMax, constraints.maxHeight),
        ),
      );
    }
    return points;
  }

  double project(double value, int max, double height) {
    final waveHeight = (value / max) * height;
    return waveHeight + _hightOffset * height;
  }
}

class MorokoshiButton extends StatelessWidget {
  const MorokoshiButton({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      "デカ",
      style: Theme.of(context).textTheme.displayLarge,
    );
  }
}

class Buddycom extends StatelessWidget {
  const Buddycom({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const BuddycomButton();
  }
}
